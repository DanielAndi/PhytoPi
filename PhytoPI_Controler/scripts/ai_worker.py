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
import re
import sys
import time
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
# Vision inference via Ollama (moondream:1.8b)
# Moondream is a compact VLM (~2.2-2.8 GB) optimised for OCR/VQA on
# resource-constrained hardware.  2 K context window — keep prompts short.
# Install: curl -fsSL https://ollama.com/install.sh | sh
#          ollama pull moondream:1.8b   # or moondream:latest
#          pip install ollama Pillow
# ---------------------------------------------------------------------------
try:
    import ollama as _ollama
    from PIL import Image
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False
    print("Warning: ollama not installed. Using placeholder results.", file=sys.stderr)
    print("  Install: pip install ollama && ollama pull moondream:1.8b", file=sys.stderr)

OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "moondream:1.8b")


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
# Real inference with Moondream — multi-query VQA pattern
# Moondream is a VQA model; one focused question per field is far more
# reliable than asking it to fill a multi-field JSON template in one shot.
# ---------------------------------------------------------------------------

# Matches "1. tip text", "2) tip text", etc. for parsing the tips response.
_TIP_RE = re.compile(r'^\s*\d+[\.\)]\s*(.+)', re.MULTILINE)


def _query(image_bytes: bytes, question: str) -> str:
    """Send the image with a single focused question; return the model's answer."""
    response = _ollama.chat(
        model=OLLAMA_MODEL,
        messages=[{"role": "user", "content": question, "images": [image_bytes]}],
    )
    return response["message"]["content"].strip()


def _run_ollama(image_bytes: bytes, sensor_context: str = "") -> dict:
    sensors = sensor_context if sensor_context else "No sensor data available."

    def q(label: str, question: str) -> str:
        print(f"  -> Querying: {label}")
        try:
            return _query(image_bytes, question)
        except Exception as e:
            print(f"     Query error ({label}): {e}", file=sys.stderr)
            return ""

    species = q(
        "species",
        "What species of plant is in this image? "
        "Reply with only the plant name (common name and scientific name if known).",
    )

    health_raw = q(
        "health_status",
        "Is this plant healthy or showing signs of disease or stress? "
        "Reply with only the word 'healthy' or 'needs_attention'.",
    )
    plant_state = (
        "needs_attention" if "needs_attention" in health_raw.lower() else "healthy"
    )

    leaf_color = q(
        "leaf_color",
        "What are the primary and secondary leaf colors of this plant?",
    )

    leaf_area = q(
        "leaf_area",
        "How dense is the leaf coverage of this plant? "
        "Reply with only one word: sparse, moderate, or dense.",
    )

    leaf_condition = q(
        "leaf_condition",
        "Describe the condition of the leaves: include texture, shape, "
        "any spots, curling, or necrosis.",
    )

    growth_stage = q(
        "growth_stage",
        "What growth stage is this plant in? "
        "Reply with only one word: seedling, vegetative, flowering, fruiting, or mature.",
    )

    disease_signs = q(
        "disease_signs",
        "Are there any visible diseases, pests, or discoloration on this plant? "
        "Describe them briefly, or reply 'None' if there are none.",
    )

    soil_obs = q(
        "soil_observation",
        "What can you observe about the soil moisture or roots in this image? "
        "Reply 'Not visible' if the soil is not visible.",
    )

    env_assessment = q(
        "environment_assessment",
        f"The plant's grow-environment sensor readings are:\n{sensors}\n\n"
        "In one sentence, explain how these conditions support or stress this plant.",
    )

    diagnostic = q(
        "diagnostic",
        f"The plant's grow-environment sensor readings are:\n{sensors}\n\n"
        "In two sentences, summarise this plant's overall health based on what you "
        "see in the image and the sensor data.",
    )

    tips_raw = q(
        "tips",
        f"The plant's grow-environment sensor readings are:\n{sensors}\n\n"
        "Give three specific, actionable care tips for this plant based on what you "
        "see in the image and the sensor data. "
        "Format your answer as a numbered list:\n1. ...\n2. ...\n3. ...",
    )
    tips = _TIP_RE.findall(tips_raw)
    if not tips and tips_raw:
        tips = [tips_raw]
    tips = [t.strip() for t in tips[:3] if t.strip()]
    if not tips:
        tips = [
            "Monitor plant regularly.",
            "Ensure adequate water and light.",
            "Check soil moisture weekly.",
        ]

    return {
        "observations": [leaf_condition] if leaf_condition else [],
        "plant_state": plant_state,
        "diagnostic": diagnostic,
        "tips": tips,
        "analysis": {
            "species": species or "Unknown",
            "leaf_color": leaf_color,
            "leaf_area": leaf_area,
            "leaf_condition": leaf_condition,
            "growth_stage": growth_stage,
            "health_status": plant_state,
            "disease_signs": disease_signs or "None visible",
            "soil_observation": soil_obs or "Not visible",
            "environment_assessment": env_assessment,
        },
    }


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


# ---------------------------------------------------------------------------
# Stub fallbacks
# ---------------------------------------------------------------------------
def _stub_result(_image_bytes) -> dict:
    return {
        "observations": ["Plant visible", "Leaves present"],
        "plant_state": "healthy",
        "diagnostic": "Plant appears healthy based on image analysis. (stub — run: ollama pull moondream:1.8b)",
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
