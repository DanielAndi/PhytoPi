#!/usr/bin/env python3
"""
PhytoPi AI Image Capture Script
Captures a still image, uploads to Supabase Storage, and creates ai_capture_jobs row.
Run from Pi controller when capture_image command is received.
Usage: capture_and_upload.py <device_id> [supabase_url] [anon_key]
Environment: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_DEVICE_ID
"""
import os
import sys
import time
import subprocess
from pathlib import Path

try:
    from supabase import create_client, Client
except ImportError:
    print("Install: pip install supabase", file=sys.stderr)
    sys.exit(1)

def main():
    device_id = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DEVICE_ID")
    url = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("SUPABASE_URL")
    key = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("SUPABASE_ANON_KEY")

    if not device_id or not url or not key:
        print("Usage: capture_and_upload.py <device_id> [url] [key]", file=sys.stderr)
        print("Or set SUPABASE_DEVICE_ID, SUPABASE_URL, SUPABASE_ANON_KEY", file=sys.stderr)
        sys.exit(1)

    ts = int(time.time())
    out_path = Path(f"/tmp/phytopi_capture_{ts}.jpg")

    # Capture with libcamera-still (Raspberry Pi)
    try:
        subprocess.run(
            ["libcamera-still", "-o", str(out_path), "-t", "1000", "-n"],
            check=True,
            capture_output=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Capture failed: {e}", file=sys.stderr)
        sys.exit(2)

    if not out_path.exists():
        print("Capture file not created", file=sys.stderr)
        sys.exit(3)

    try:
        supabase: Client = create_client(url, key)
        storage_path = f"{device_id}/{ts}.jpg"

        with open(out_path, "rb") as f:
            supabase.storage.from_("device-images").upload(
                storage_path,
                f.read(),
                file_options={"content-type": "image/jpeg"},
            )

        supabase.table("ai_capture_jobs").insert({
            "device_id": device_id,
            "image_url": storage_path,
            "status": "pending",
        }).execute()

        print(f"Uploaded {storage_path}, job created")
    except Exception as e:
        print(f"Upload failed: {e}", file=sys.stderr)
        sys.exit(4)
    finally:
        out_path.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
