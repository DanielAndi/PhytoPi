#!/usr/bin/env python3
"""
PhytoPi AI Worker - runs on home PC
Polls ai_capture_jobs for pending, runs vision + LLM, writes results.
Requires: Moondream, Qwen2.5 (or similar), supabase, transformers.
Usage: ai_worker.py
Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (or anon for testing)
"""
import os
import sys
import time
import json
from datetime import datetime, timezone

try:
    from supabase import create_client
except ImportError:
    print("pip install supabase", file=sys.stderr)
    sys.exit(1)

# Optional: vision + LLM - install if available
try:
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer
    HAS_VISION = True
except ImportError:
    HAS_VISION = False
    print("Warning: transformers/torch not installed. Will use placeholder results.", file=sys.stderr)


def process_image_stub(path_or_url: str) -> dict:
    """Placeholder when models not installed. Replace with Moondream inference."""
    return {
        "observations": ["Plant visible", "Leaves present"],
        "plant_state": "healthy",
    }


def run_llm_stub(vision_result: dict) -> dict:
    """Placeholder when LLM not installed. Replace with Qwen2.5 inference."""
    return {
        "diagnostic": "Plant appears healthy based on image analysis.",
        "tips": [
            "Continue current watering schedule.",
            "Ensure adequate light exposure.",
        ],
    }


def main():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        sys.exit(1)

    supabase = create_client(url, key)

    current_job_id = None
    while True:
        try:
            rows = supabase.table("ai_capture_jobs").select("*").eq("status", "pending").limit(1).execute()
            if not rows.data or len(rows.data) == 0:
                time.sleep(10)
                continue

            job = rows.data[0]
            job_id = job["id"]
            current_job_id = job_id
            device_id = job["device_id"]
            image_url = job.get("image_url")

            supabase.table("ai_capture_jobs").update({"status": "processing"}).eq("id", job_id).execute()

            vision_result = process_image_stub(image_url or "")
            llm_result = run_llm_stub(vision_result)

            supabase.table("ai_capture_jobs").update({
                "status": "completed",
                "vision_result": vision_result,
                "llm_result": llm_result,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", job_id).execute()

            supabase.table("ml_inferences").insert({
                "device_id": device_id,
                "result": {"vision": vision_result, "llm": llm_result},
                "diagnostic": llm_result.get("diagnostic", ""),
                "tips": llm_result.get("tips", []),
                "image_url": image_url,
                "model_version": "stub",
                "job_id": job_id,
            }).execute()

            print(f"Processed job {job_id}")
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
