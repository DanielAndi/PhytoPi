#!/usr/bin/env python3
"""
PhytoPi AI Worker - runs on home PC / server
Polls ai_capture_jobs for pending jobs, runs Moondream vision inference,
writes diagnostic + tips back to ai_capture_jobs and ml_inferences.

Usage:
    python3 scripts/ai_worker.py

Environment (set in .env file next to this script, or export before running):
    SUPABASE_URL               - your Supabase project URL
    SUPABASE_SERVICE_ROLE_KEY  - service role key (bypasses RLS)
    SUPABASE_ANON_KEY          - fallback if service role not set

Models (installed via pip):
    pip install moondream pillow requests supabase
"""
import os
import sys
import time
import json
from pathlib import Path
from datetime import datetime, timezone

PROCESSING_TIMEOUT_SECONDS = int(os.environ.get("AI_JOB_PROCESSING_TIMEOUT_SECONDS", "300"))
# Jobs older than this are abandoned (failed) rather than re-queued.
# Set to 0 to re-queue all stale jobs regardless of age.
MAX_RECOVERY_AGE_SECONDS = int(os.environ.get("AI_JOB_MAX_RECOVERY_AGE_SECONDS", str(2 * 3600)))

# ---------------------------------------------------------------------------
# Load .env from the same directory as this script (or the working directory)
# ---------------------------------------------------------------------------
def _load_dotenv():
    candidates = [
        Path(__file__).parent.parent / ".env",   # PhytoPI_Controler/.env
        Path(__file__).parent / ".env",            # scripts/.env
        Path(".env"),                              # cwd/.env
    ]
    for path in candidates:
        if path.exists():
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key, _, val = line.partition("=")
                    val = val.strip().strip('"').strip("'")
                    os.environ.setdefault(key.strip(), val)
            print(f"Loaded env from {path}", file=sys.stderr)
            return
    print("Warning: no .env file found; relying on exported environment variables.", file=sys.stderr)

_load_dotenv()

# ---------------------------------------------------------------------------
# Supabase client
# ---------------------------------------------------------------------------
try:
    from supabase import create_client
except ImportError:
    print("pip install supabase", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Vision inference via Ollama (llava-phi3)
# Ollama uses llama.cpp - works on old CPUs (Sandy Bridge, no AVX2 required)
# Install: curl -fsSL https://ollama.com/install.sh | sh
#          ollama pull llava-phi3
#          pip install ollama Pillow
# ---------------------------------------------------------------------------
try:
    import ollama as _ollama
    from PIL import Image
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False
    print("Warning: ollama not installed. Using placeholder results.", file=sys.stderr)
    print("  Install: pip install ollama && ollama pull llava-phi3", file=sys.stderr)

OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llava-phi3")


def _parse_iso_ts(value):
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Image fetching
# ---------------------------------------------------------------------------
def _fetch_image_bytes(supabase, storage_path: str):
    """Download image bytes from Supabase Storage."""
    try:
        return supabase.storage.from_("device-images").download(storage_path)
    except Exception as e:
        print(f"Could not fetch image from storage ({storage_path}): {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Real inference with Moondream
# ---------------------------------------------------------------------------
def _build_prompt(sensor_context: str) -> str:
    sensor_section = (
        f"\n\nCurrent sensor readings from the grow environment:\n{sensor_context}\n"
        "Use these readings alongside the visual evidence to improve accuracy."
        if sensor_context else ""
    )
    return (
        "You are an expert botanist and plant health specialist."
        f"{sensor_section}\n\n"
        "Carefully examine the plant in this image and respond ONLY with a valid JSON object "
        "— no markdown fences, no explanation, just the raw JSON.\n\n"
        "Use exactly this structure:\n"
        "{\n"
        '  "species": "<most likely common name and/or scientific name, or Unknown>",\n'
        '  "leaf_color": "<primary and secondary leaf colours>",\n'
        '  "leaf_area": "<sparse / moderate / dense>",\n'
        '  "leaf_condition": "<texture, shape, curling, spots, necrosis>",\n'
        '  "growth_stage": "<seedling / vegetative / flowering / fruiting / mature / dormant>",\n'
        '  "health_status": "<healthy or needs_attention>",\n'
        '  "disease_signs": "<visible disease, pests, discoloration, wilting — or None visible>",\n'
        '  "soil_observation": "<visible soil moisture or root issues — or Not visible>",\n'
        '  "environment_assessment": "<1 sentence on whether sensor readings support or conflict with visual health>",\n'
        '  "diagnostic": "<2-3 sentence overall plant health summary integrating visual and sensor data>",\n'
        '  "tips": ["<tip 1>", "<tip 2>", "<tip 3>"]\n'
        "}"
    )


def _fetch_sensor_readings(supabase, device_id: str) -> str:
    """
    Fetch the latest reading for each sensor type attached to this device.
    Returns a formatted string for injection into the prompt, or empty string on failure.
    """
    try:
        # Get all sensors for this device with their type keys and units
        sensors = supabase.table("sensors").select(
            "id, label, sensor_types(key, name, unit)"
        ).eq("device_id", device_id).execute().data

        if not sensors:
            return ""

        lines = []
        for sensor in sensors:
            sensor_id = sensor["id"]
            st = sensor.get("sensor_types") or {}
            key = st.get("key", "unknown")
            name = st.get("name", key)
            unit = st.get("unit", "")
            label = sensor.get("label") or name

            # Get latest reading for this sensor
            reading = supabase.table("readings").select("value, ts").eq(
                "sensor_id", sensor_id
            ).order("ts", desc=True).limit(1).execute().data

            if reading:
                val = reading[0]["value"]
                ts = reading[0]["ts"][:16].replace("T", " ")  # trim to minutes
                lines.append(f"  - {label} ({key}): {val} {unit}  [at {ts}]")

        return "\n".join(lines) if lines else ""
    except Exception as e:
        print(f"Warning: could not fetch sensor readings: {e}", file=sys.stderr)
        return ""


def _run_ollama(image_bytes: bytes, sensor_context: str = "") -> dict:
    prompt = _build_prompt(sensor_context)
    try:
        response = _ollama.chat(
            model=OLLAMA_MODEL,
            messages=[{
                "role": "user",
                "content": prompt,
                "images": [image_bytes],
            }]
        )
        text = response["message"]["content"].strip()
    except Exception as e:
        print(f"Ollama inference error: {e}", file=sys.stderr)
        return _stub_result(None)

    # Strip markdown fences if model ignores instructions
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        # Fallback: extract what we can from plain text
        print(f"Warning: model did not return valid JSON, using raw text.", file=sys.stderr)
        data = {"diagnostic": text[:500], "health_status": "healthy"}

    plant_state = "needs_attention" if data.get("health_status", "").lower() == "needs_attention" else "healthy"
    tips = data.get("tips", [])
    if not isinstance(tips, list) or not tips:
        tips = ["Monitor plant regularly.", "Ensure adequate water and light.", "Check soil moisture weekly."]

    return {
        "observations": [data.get("leaf_condition", "")],
        "plant_state": plant_state,
        "diagnostic": data.get("diagnostic", ""),
        "tips": tips,
        # Rich analysis fields stored in result for the UI
        "analysis": {
            "species": data.get("species", "Unknown"),
            "leaf_color": data.get("leaf_color", ""),
            "leaf_area": data.get("leaf_area", ""),
            "leaf_condition": data.get("leaf_condition", ""),
            "growth_stage": data.get("growth_stage", ""),
            "health_status": plant_state,
            "disease_signs": data.get("disease_signs", "None visible"),
            "soil_observation": data.get("soil_observation", "Not visible"),
        },
    }


# ---------------------------------------------------------------------------
# Stub fallbacks
# ---------------------------------------------------------------------------
def _stub_result(_image_bytes) -> dict:
    return {
        "observations": ["Plant visible", "Leaves present"],
        "plant_state": "healthy",
        "diagnostic": "Plant appears healthy based on image analysis. (stub - install moondream for real results)",
        "tips": [
            "Continue current watering schedule.",
            "Ensure adequate light exposure.",
            "Monitor for pests weekly.",
        ],
    }


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
def main():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if not url or not key:
        print("Error: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env or environment.", file=sys.stderr)
        sys.exit(1)

    model_version = f"ollama/{OLLAMA_MODEL}" if HAS_OLLAMA else "stub"
    print(f"AI Worker starting. Model: {model_version}")
    print(f"Polling for pending jobs every 10s ...")

    supabase = create_client(url, key)
    current_job_id = None

    while True:
        try:
            rows = supabase.table("ai_capture_jobs").select("*").eq("status", "pending").limit(1).execute()
            if not rows.data:
                # Recover stale jobs that got stuck in processing due crash/network issues.
                processing_rows = supabase.table("ai_capture_jobs").select("*").eq(
                    "status", "processing"
                ).order("created_at", desc=False).limit(1).execute()
                if processing_rows.data:
                    processing_job = processing_rows.data[0]
                    created_at = _parse_iso_ts(processing_job.get("created_at"))
                    if created_at:
                        age_seconds = (datetime.now(timezone.utc) - created_at).total_seconds()
                        if age_seconds > PROCESSING_TIMEOUT_SECONDS:
                            stale_id = processing_job["id"]
                            # If the job is too old to be worth retrying, mark it failed.
                            if MAX_RECOVERY_AGE_SECONDS > 0 and age_seconds > MAX_RECOVERY_AGE_SECONDS:
                                print(
                                    f"[{datetime.now().strftime('%H:%M:%S')}] "
                                    f"Abandoning old stale job {stale_id} "
                                    f"(age {int(age_seconds / 3600):.1f}h > limit {MAX_RECOVERY_AGE_SECONDS // 3600}h)"
                                )
                                supabase.table("ai_capture_jobs").update({"status": "failed"}).eq(
                                    "id", stale_id
                                ).execute()
                            else:
                                print(
                                    f"[{datetime.now().strftime('%H:%M:%S')}] "
                                    f"Re-queuing stale processing job {stale_id} "
                                    f"(age {int(age_seconds)}s)"
                                )
                                supabase.table("ai_capture_jobs").update({"status": "pending"}).eq(
                                    "id", stale_id
                                ).execute()
                            time.sleep(1)
                            continue
                time.sleep(10)
                continue

            job = rows.data[0]
            job_id = job["id"]
            current_job_id = job_id
            device_id = job["device_id"]
            image_storage_path = job.get("image_url")

            print(f"[{datetime.now().strftime('%H:%M:%S')}] Processing job {job_id} (image: {image_storage_path})")
            supabase.table("ai_capture_jobs").update({"status": "processing"}).eq("id", job_id).execute()

            image_bytes = _fetch_image_bytes(supabase, image_storage_path) if image_storage_path else None
            sensor_context = _fetch_sensor_readings(supabase, device_id)
            if sensor_context:
                print(f"  -> Sensor context:\n{sensor_context}")

            if HAS_OLLAMA and image_bytes:
                result = _run_ollama(image_bytes, sensor_context)
            else:
                result = _stub_result(image_bytes)

            vision_result = {
                "observations": result["observations"],
                "plant_state": result["plant_state"],
            }
            llm_result = {
                "diagnostic": result["diagnostic"],
                "tips": result["tips"],
                "analysis": result.get("analysis", {}),
            }

            supabase.table("ai_capture_jobs").update({
                "status": "completed",
                "vision_result": vision_result,
                "llm_result": llm_result,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", job_id).execute()

            supabase.table("ml_inferences").insert({
                "device_id": device_id,
                "result": {
                    "vision": vision_result,
                    "llm": llm_result,
                    "sensor_snapshot": sensor_context,
                },
                "diagnostic": result["diagnostic"],
                "tips": result["tips"],
                "image_url": image_storage_path,
                "model_version": model_version[:100],
                "job_id": job_id,
            }).execute()

            print(f"  -> Done. State: {result['plant_state']} | {result['diagnostic'][:80]}...")
            current_job_id = None

        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            if current_job_id:
                try:
                    supabase.table("ai_capture_jobs").update({"status": "failed"}).eq("id", current_job_id).execute()
                except Exception:
                    pass
            current_job_id = None
            time.sleep(30)


if __name__ == "__main__":
    main()
