#!/usr/bin/env python3
import io
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
        self.buffer = io.BytesIO()
        self.condition = Condition()

    def write(self, buf):
        if buf.startswith(b'\xff\xd8'):
            # New frame, copy the existing buffer's content and notify all
            self.buffer.truncate()
            with self.condition:
                self.frame = self.buffer.getvalue()
                self.condition.notify_all()
            self.buffer.seek(0)
        return self.buffer.write(buf)

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
        elif self.path == '/stream.mjpg':
            self.send_response(200)
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

def get_camera_command():
    # Check for rpicam-vid (Bookworm) or libcamera-vid (Bullseye)
    # We use --codec mjpeg to get MJPEG stream to stdout
    cmd = None
    if subprocess.call("command -v rpicam-vid", shell=True, stdout=subprocess.DEVNULL) == 0:
        cmd = ["rpicam-vid", "-t", "0", "--width", str(WIDTH), "--height", str(HEIGHT), "--framerate", str(FRAMERATE), "--codec", "mjpeg", "-o", "-"]
    elif subprocess.call("command -v libcamera-vid", shell=True, stdout=subprocess.DEVNULL) == 0:
        cmd = ["libcamera-vid", "-t", "0", "--width", str(WIDTH), "--height", str(HEIGHT), "--framerate", str(FRAMERATE), "--codec", "mjpeg", "-o", "-"]
    elif subprocess.call("command -v raspivid", shell=True, stdout=subprocess.DEVNULL) == 0:
        # Raspivid produces H264, not MJPEG natively in a way easy to pipe frame-by-frame without raspimjpeg
        # So we might fail back or try to use raspistill in burst mode?
        # Or ffmpeg?
        # For legacy, let's assume ffmpeg is available if raspivid is.
        logging.warning("Legacy raspivid found. Trying ffmpeg wrapper...")
        cmd = ["ffmpeg", "-f", "video4linux2", "-i", "/dev/video0", "-f", "mjpeg", "-framerate", str(FRAMERATE), "-video_size", f"{WIDTH}x{HEIGHT}", "-"]
    
    return cmd

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    
    cmd = get_camera_command()
    if not cmd:
        logging.error("No compatible camera tool found.")
        exit(1)
        
    logging.info(f"Starting camera with command: {' '.join(cmd)}")
    
    try:
        # Start camera process
        camera_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        
        # Start a thread to read from camera stdout and write to StreamingOutput
        # Actually, we can just do it in a loop here if we use threading for the server.
        import threading
        
        def capture_loop():
            # This is a simplified MJPEG parser. 
            # rpicam-vid outputting MJPEG simply dumps JPEGs one after another.
            # We need to find the JPEG boundaries (FF D8 ... FF D9).
            # However, rpicam-vid output might just be a stream.
            # A safer way is to read chunks and look for start/end markers.
            
            stream = camera_proc.stdout
            # We'll read into the output object. 
            # But StreamingOutput expects clean frames?
            # Actually StreamingOutput in the example (based on picamera) expects write calls.
            # But here we have a stream.
            
            # Simple buffer strategy
            # JPEG start: 0xFF 0xD8
            # JPEG end: 0xFF 0xD9
            
            data = b''
            while True:
                # Read small chunks
                chunk = stream.read(4096)
                if not chunk:
                    break
                data += chunk
                
                a = data.find(b'\xff\xd8')
                b = data.find(b'\xff\xd9')
                
                if a != -1 and b != -1:
                    jpg = data[a:b+2]
                    data = data[b+2:]
                    output.write(jpg)
        
        t = threading.Thread(target=capture_loop)
        t.daemon = True
        t.start()
        
        address = ('', PORT)
        server = StreamingServer(address, StreamingHandler)
        logging.info(f"Streaming at http://<IP>:{PORT}/stream.mjpg")
        server.serve_forever()
        
    except KeyboardInterrupt:
        pass
    finally:
        camera_proc.terminate()

