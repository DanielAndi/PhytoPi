#!/usr/bin/env python3
"""MJPEG stream server with USB camera auto-detect. Recovers on disconnect/reconnect."""
import glob
import os
import subprocess
import logging
import socketserver
from http import server
from threading import Condition

# Configuration
PORT = 8000
WIDTH = 640
HEIGHT = 480
FRAMERATE = 24
RECONNECT_DELAY = 5

# HTML Page for direct browser viewing
PAGE = """\
<html>
<head>
<title>PhytoPi Camera</title>
</head>
<body>
<center><h1>PhytoPi Live Stream</h1></center>
<center><img src="stream.mjpg" width="{}" height="{}"></center>
</body>
</html>
""".format(WIDTH, HEIGHT)

class StreamingOutput(object):
    def __init__(self):
        self.frame = None
        self.condition = Condition()

    def set_frame(self, frame):
        with self.condition:
            self.frame = frame
            self.condition.notify_all()

class StreamingHandler(server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(301)
            self.send_header('Location', '/index.html')
            self.end_headers()
        elif self.path == '/index.html':
            content = PAGE.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        elif self.path.startswith('/stream.mjpg'):
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Age', 0)
            self.send_header('Cache-Control', 'no-cache, private')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=FRAME')
            self.end_headers()
            try:
                while True:
                    with output.condition:
                        output.condition.wait()
                        frame = output.frame
                    
                    if frame is None:
                        continue

                    self.wfile.write(b'--FRAME\r\n')
                    self.send_header('Content-Type', 'image/jpeg')
                    self.send_header('Content-Length', len(frame))
                    self.end_headers()
                    self.wfile.write(frame)
                    self.wfile.write(b'\r\n')
            except Exception as e:
                logging.warning(
                    'Removed streaming client %s: %s',
                    self.client_address, str(e))
        else:
            self.send_error(404)
            self.end_headers()

class StreamingServer(socketserver.ThreadingMixIn, server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

output = StreamingOutput()

def find_usb_camera():
    """Auto-detect first USB camera from /dev/video* (prefer video0)."""
    devices = sorted(glob.glob("/dev/video*"))
    if not devices:
        return "/dev/video0"
    # Prefer video0; otherwise first available
    for d in devices:
        if "video0" in d:
            return d
    return devices[0]

def get_camera_command():
    # Check for rpicam-vid (Bookworm) or libcamera-vid (Bullseye) - Pi camera
    cmd = None
    if subprocess.call("command -v rpicam-vid", shell=True, stdout=subprocess.DEVNULL) == 0:
        cmd = ["rpicam-vid", "-t", "0", "--width", str(WIDTH), "--height", str(HEIGHT), "--framerate", str(FRAMERATE), "--codec", "mjpeg", "--nopreview", "-o", "-"]
    elif subprocess.call("command -v libcamera-vid", shell=True, stdout=subprocess.DEVNULL) == 0:
        cmd = ["libcamera-vid", "-t", "0", "--width", str(WIDTH), "--height", str(HEIGHT), "--framerate", str(FRAMERATE), "--codec", "mjpeg", "--nopreview", "-o", "-"]
    else:
        # USB camera via ffmpeg - auto-detect device
        dev = find_usb_camera()
        logging.info(f"Using USB camera: {dev}")
        cmd = ["ffmpeg", "-f", "video4linux2", "-i", dev, "-f", "mjpeg", "-framerate", str(FRAMERATE), "-video_size", f"{WIDTH}x{HEIGHT}", "-"]
    
    return cmd

def run_capture_loop(camera_proc, output):
    """Read MJPEG frames from camera process. Returns when process dies."""
    import time
    stream = camera_proc.stdout
    data = b''
    frame_count = 0
    last_log = time.time()
    while True:
        if camera_proc.poll() is not None:
            logging.error("Camera process exited unexpectedly.")
            return
        chunk = stream.read(4096)
        if not chunk:
            return
        data += chunk
        while True:
            start = data.find(b'\xff\xd8')
            if start == -1:
                if len(data) > 2:
                    data = data[-2:]
                break
            end = data.find(b'\xff\xd9', start)
            if end == -1:
                data = data[start:]
                break
            jpg = data[start:end+2]
            data = data[end+2:]
            output.set_frame(jpg)
            frame_count += 1
            if time.time() - last_log > 5:
                logging.info(f"Captured {frame_count} frames so far...")
                last_log = time.time()


if __name__ == '__main__':
    import threading
    import time

    logging.basicConfig(level=logging.INFO)

    cmd = get_camera_command()
    if not cmd:
        logging.error("No compatible camera tool found.")
        exit(1)

    logging.info(f"Starting camera with command: {' '.join(cmd)}")

    camera_proc = None
    capture_done = threading.Event()

    def capture_with_restart():
        nonlocal camera_proc
        while not capture_done.is_set():
            camera_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)

            def log_stderr():
                for line in camera_proc.stderr:
                    logging.error(f"Camera: {line.decode('utf-8', errors='replace').strip()}")

            threading.Thread(target=log_stderr, daemon=True).start()
            run_capture_loop(camera_proc, output)
            if camera_proc:
                camera_proc.terminate()
                camera_proc = None
            if not capture_done.is_set():
                logging.warning(f"Camera stopped. Reconnecting in {RECONNECT_DELAY}s...")
                time.sleep(RECONNECT_DELAY)

    t_capture = threading.Thread(target=capture_with_restart, daemon=True)
    t_capture.start()

    try:
        address = ('', PORT)
        server = StreamingServer(address, StreamingHandler)
        logging.info(f"Streaming at http://<IP>:{PORT}/stream.mjpg")
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        capture_done.set()
        if camera_proc:
            camera_proc.terminate()

