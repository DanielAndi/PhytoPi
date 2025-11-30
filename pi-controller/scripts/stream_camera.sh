#!/bin/bash
# Stream camera video to TCP port 8888
# Supports both libcamera (Bullseye/Bookworm) and legacy raspivid (Buster)

PORT=8888

# Check for libcamera-vid (modern OS)
if command -v libcamera-vid &> /dev/null; then
    echo "Found libcamera-vid. Starting stream on port $PORT..."
    echo "To view on your computer, use VLC Media Player:"
    echo "  Media -> Open Network Stream -> tcp/h264://<PI_IP>:$PORT"
    echo "  (Replace <PI_IP> with your Raspberry Pi's IP address)"
    
    # -t 0: Run forever
    # --inline: Insert SPS/PPS headers (needed for streaming)
    # --listen: Listen for incoming connection
    # --width 1280 --height 720: Standard HD resolution
    libcamera-vid -t 0 --inline --listen --width 1280 --height 720 -o tcp://0.0.0.0:$PORT

# Check for raspivid (legacy OS)
elif command -v raspivid &> /dev/null; then
    echo "Found raspivid. Starting stream on port $PORT..."
    echo "To view on your computer, use VLC Media Player:"
    echo "  Media -> Open Network Stream -> tcp/h264://<PI_IP>:$PORT"
    
    # -t 0: Run forever
    # -l: Listen on TCP
    # -w 1280 -h 720: HD resolution
    raspivid -t 0 -l -w 1280 -h 720 -o tcp://0.0.0.0:$PORT

else
    echo "Error: No compatible camera streaming tool found."
    echo "Please ensure you have 'libcamera-apps' installed or legacy camera support enabled."
    exit 1
fi

