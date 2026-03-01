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
import io
import requests
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
# Moondream2 via HuggingFace Transformers (local CPU/GPU inference)
# Install: pip install "transformers>=4.51.1" "torch>=2.7.0" "accelerate>=1.10.0" "Pillow>=11.0.0"
# CPU-only torch (smaller download): pip install torch --index-url https://download.pytorch.org/whl/cpu
# ---------------------------------------------------------------------------
try:
    import torch
    from transformers import AutoModelForCausalLM
    from PIL import Image
    _model = None  # loaded lazily on first use

    def _get_model():
        global _model
        if _model is None:
            print("Loading Moondream2 from HuggingFace (first run downloads ~2 GB, please wait)...", file=sys.stderr)
            # Use float32 on CPU; bfloat16 only works well on CUDA/MPS
            dtype = torch.bfloat16 if torch.cuda.is_available() else torch.float32
            device = "cuda" if torch.cuda.is_available() else "cpu"
            _model = AutoModelForCausalLM.from_pretrained(
                "vikhyatk/moondream2",
                revision="2024-08-26",
                trust_remote_code=True,
                dtype=dtype,
                device_map=device,
            )
            print(f"Moondream2 loaded on {device}.", file=sys.stderr)
        return _model

    HAS_MOONDREAM = True
except ImportError:
    HAS_MOONDREAM = False
    print("Warning: transformers/torch not installed. Using placeholder results.", file=sys.stderr)
    print("  Install: pip install 'transformers>=4.51.1' 'torch>=2.7.0' 'accelerate>=1.10.0' Pillow", file=sys.stderr)


# ---------------------------------------------------------------------------
# Image fetching
# ---------------------------------------------------------------------------
def _fetch_image(supabase, storage_path: str):
    """Download image from Supabase Storage into a PIL Image object."""
    try:
        response = supabase.storage.from_("device-images").download(storage_path)
        return Image.open(io.BytesIO(response))
    except Exception as e:
        print(f"Could not fetch image from storage ({storage_path}): {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Real inference with Moondream
# ---------------------------------------------------------------------------
VISION_QUESTIONS = [
    "Describe the overall health and appearance of the plant in this image.",
    "Are there any visible signs of disease, pests, discoloration, or wilting?",
    "What is the current growth stage of the plant?",
]

def _run_moondream(image) -> dict:
    model = _get_model()
    # Encode once and reuse for all queries (much faster)
    encoded = model.encode_image(image)

    observations = []
    for q in VISION_QUESTIONS:
        try:
            answer = model.query(encoded, q)["answer"]
            observations.append(answer.strip())
        except Exception as e:
            observations.append(f"(query failed: {e})")

    # Derive a simple plant_state from the observations text
    combined = " ".join(observations).lower()
    if any(w in combined for w in ("disease", "pest", "wilt", "yellow", "brown", "rot", "damage", "dead")):
        plant_state = "needs_attention"
    else:
        plant_state = "healthy"

    # Ask for tips directly
    try:
        tips_raw = model.query(
            encoded,
            "Based on what you see, give 3 short care tips for this plant. Return each tip on a new line starting with '-'."
        )["answer"]
        tips = [t.lstrip("- ").strip() for t in tips_raw.strip().splitlines() if t.strip()]
        if not tips:
            tips = ["Monitor plant regularly.", "Ensure adequate water and light."]
    except Exception:
        tips = ["Monitor plant regularly.", "Ensure adequate water and light."]

    # Ask for a one-paragraph diagnostic summary
    try:
        diagnostic = model.query(
            encoded,
            "Write a 2-3 sentence plant health diagnostic based on what you observe in the image."
        )["answer"].strip()
    except Exception:
        diagnostic = observations[0] if observations else "Plant observed."

    return {
        "observations": observations,
        "plant_state": plant_state,
        "diagnostic": diagnostic,
        "tips": tips,
    }


# ---------------------------------------------------------------------------
# Stub fallbacks
# ---------------------------------------------------------------------------
def _stub_result(_image) -> dict:
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

    model_version = "moondream-2b-int8" if HAS_MOONDREAM else "stub"
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

            image = _fetch_image(supabase, image_storage_path) if image_storage_path else None

            if HAS_MOONDREAM and image:
                result = _run_moondream(image)
            else:
                result = _stub_result(image)

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
                "model_version": model_version,
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
