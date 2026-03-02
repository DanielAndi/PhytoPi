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
# Real inference with Moondream
# ---------------------------------------------------------------------------
def _build_prompt(sensor_context: str) -> str:
    # Sensor readings are kept as individual lines so the model can reason
    # about each value separately when writing environment_assessment.
    sensor_section = ""
    if sensor_context:
        lines = [l.strip() for l in sensor_context.splitlines() if l.strip()]
        sensor_section = (
            "\n\nCurrent grow-environment sensor readings:\n"
            + "\n".join(f"  {l}" for l in lines)
        )

    return (
        "You are a plant health expert. Carefully examine the plant in this image."
        f"{sensor_section}\n\n"
        "ALL fields are REQUIRED — replace every placeholder with a real observation.\n"
        "Reply ONLY with raw JSON (no markdown fences, no extra text):\n"
        '{\n'
        '  "species": "<common name and scientific name, or Unknown>",\n'
        '  "health_status": "<healthy or needs_attention>",\n'
        '  "leaf_color": "<primary and secondary leaf colours>",\n'
        '  "leaf_area": "<sparse or moderate or dense>",\n'
        '  "leaf_condition": "<texture, shape, spots, curling, or necrosis>",\n'
        '  "growth_stage": "<seedling or vegetative or flowering or fruiting or mature>",\n'
        '  "disease_signs": "<visible disease, pests, discoloration — or None>",\n'
        '  "soil_observation": "<visible moisture level or root issues — or Not visible>",\n'
        '  "environment_assessment": "<1 sentence: how the sensor readings support or stress this plant>",\n'
        '  "diagnostic": "<2 sentence health summary integrating visual and sensor evidence>",\n'
        '  "tips": ["<specific actionable tip 1>", "<specific actionable tip 2>", "<specific actionable tip 3>"]\n'
        '}'
    )


# Matches unfilled template placeholders the model may echo back verbatim, e.g. "<tip1>".
_PLACEHOLDER_RE = re.compile(r'^\s*<[^>]+>\s*$')


def _is_placeholder(v) -> bool:
    return bool(_PLACEHOLDER_RE.match(str(v).strip()))


def _clean_str(v, fallback: str = "") -> str:
    """Return a clean string, turning lists into comma-joined text and
    discarding placeholder text or numeric confidence scores the model may emit."""
    if v is None:
        return fallback
    # Moondream sometimes returns floats (confidence scores) for text fields.
    if isinstance(v, (int, float)):
        return fallback
    if isinstance(v, list):
        parts = [str(i).strip() for i in v if i and not isinstance(i, (int, float)) and not _is_placeholder(str(i))]
        return ", ".join(parts) if parts else fallback
    s = str(v).strip()
    return fallback if not s or _is_placeholder(s) else s


def _extract_json(text: str) -> dict:
    """Robustly extract the first JSON object from model output.

    Handles common Moondream quirks:
    - Preamble / postamble prose around the JSON block
    - Markdown fences (```json ... ```)
    - The object wrapped in an array
    - Truncated or otherwise invalid JSON
    """
    # Strip markdown fences first
    if "```" in text:
        parts = text.split("```")
        for part in parts:
            if part.startswith("json"):
                part = part[4:]
            part = part.strip()
            if part.startswith("{"):
                text = part
                break

    # Try the whole string as-is
    try:
        result = json.loads(text)
        if isinstance(result, dict):
            return result
        if isinstance(result, list):
            return next((i for i in result if isinstance(i, dict)), {})
    except json.JSONDecodeError:
        pass

    # Find the outermost {...} block and try that
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        try:
            result = json.loads(text[start : end + 1])
            if isinstance(result, dict):
                return result
            if isinstance(result, list):
                return next((i for i in result if isinstance(i, dict)), {})
        except json.JSONDecodeError:
            pass

    # Last resort: surface the raw text as a diagnostic string
    print("Warning: could not extract JSON from model output; using raw text.", file=sys.stderr)
    return {"diagnostic": text[:500], "health_status": "healthy"}


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

    data = _extract_json(text)

    raw_status = data.get("health_status", "")
    plant_state = (
        "needs_attention"
        if isinstance(raw_status, str) and raw_status.lower() == "needs_attention"
        else "healthy"
    )

    # Strip placeholder items the model may have echoed back verbatim.
    raw_tips = data.get("tips", [])
    if isinstance(raw_tips, list):
        tips = [t for t in raw_tips if isinstance(t, str) and t.strip() and not _is_placeholder(t)]
    else:
        tips = []
    if not tips:
        tips = ["Monitor plant regularly.", "Ensure adequate water and light.", "Check soil moisture weekly."]

    diagnostic = _clean_str(data.get("diagnostic"), "")
    leaf_condition = _clean_str(data.get("leaf_condition"), "")
    env_assessment = _clean_str(data.get("environment_assessment"), "")

    return {
        "observations": [leaf_condition] if leaf_condition else [],
        "plant_state": plant_state,
        "diagnostic": diagnostic,
        "tips": tips,
        # Rich analysis fields stored in result for the UI
        "analysis": {
            "species": _clean_str(data.get("species"), "Unknown"),
            "leaf_color": _clean_str(data.get("leaf_color"), ""),
            "leaf_area": _clean_str(data.get("leaf_area"), ""),
            "leaf_condition": leaf_condition,
            "growth_stage": _clean_str(data.get("growth_stage"), ""),
            "health_status": plant_state,
            "disease_signs": _clean_str(data.get("disease_signs"), "None visible"),
            "soil_observation": _clean_str(data.get("soil_observation"), "Not visible"),
            "environment_assessment": env_assessment,
        },
    }


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
