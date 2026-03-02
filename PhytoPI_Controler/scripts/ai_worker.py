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
from pathlib import Path
from datetime import datetime, timezone

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
def _run_ollama(image_bytes: bytes) -> dict:
    prompt = (
        "You are a plant health expert. Analyze the plant in this image.\n"
        "Respond in exactly this format:\n"
        "STATUS: healthy OR needs_attention\n"
        "OBSERVATION: <one sentence describing the plant's appearance>\n"
        "DIAGNOSTIC: <2 sentences on plant health>\n"
        "TIPS:\n- <tip 1>\n- <tip 2>\n- <tip 3>\n"
    )
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

    # Parse the structured response
    lines = text.splitlines()
    plant_state = "healthy"
    observation = ""
    diagnostic = ""
    tips = []
    in_tips = False

    for line in lines:
        line = line.strip()
        if line.upper().startswith("STATUS:"):
            plant_state = "needs_attention" if "needs_attention" in line.lower() else "healthy"
        elif line.upper().startswith("OBSERVATION:"):
            observation = line.split(":", 1)[1].strip()
        elif line.upper().startswith("DIAGNOSTIC:"):
            diagnostic = line.split(":", 1)[1].strip()
        elif line.upper().startswith("TIPS:"):
            in_tips = True
        elif in_tips and line.startswith("-"):
            tips.append(line.lstrip("- ").strip())

    if not observation:
        observation = text[:200]
    if not diagnostic:
        diagnostic = observation
    if not tips:
        tips = ["Monitor plant regularly.", "Ensure adequate water and light.", "Check soil moisture weekly."]

    return {
        "observations": [observation],
        "plant_state": plant_state,
        "diagnostic": diagnostic,
        "tips": tips,
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

            if HAS_OLLAMA and image_bytes:
                result = _run_ollama(image_bytes)
            else:
                result = _stub_result(image_bytes)

            vision_result = {
                "observations": result["observations"],
                "plant_state": result["plant_state"],
            }
            llm_result = {
                "diagnostic": result["diagnostic"],
                "tips": result["tips"],
            }

            supabase.table("ai_capture_jobs").update({
                "status": "completed",
                "vision_result": vision_result,
                "llm_result": llm_result,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", job_id).execute()

            supabase.table("ml_inferences").insert({
                "device_id": device_id,
                "result": {"vision": vision_result, "llm": llm_result},
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
