#!/bin/bash
cd "$(dirname "$0")"

# Load environment variables if they exist
if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile"
fi

# Check if we're on a Raspberry Pi
if [ ! -f "/proc/device-tree/model" ] || ! grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    echo "Error: This script is intended for Raspberry Pi only." >> "$HOME/camera_server.log"
    exit 1
fi

# Activate virtual environment if it exists
if [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
else
    echo "Virtual environment missing or corrupted. Recreating..."
    rm -rf .venv
    
    # Check if uv is installed
    if ! command -v uv &> /dev/null; then
        echo "uv not found, installing it..."
        pip3 install uv || { echo "Failed to install uv. Exiting."; exit 1; }
    fi
    
    echo "Creating virtual environment with uv..."
    uv venv .venv
    source .venv/bin/activate
    uv pip install -r requirements-picamera.txt --extra-index-url https://www.piwheels.org/simple
fi

# Ensure camera module is enabled
if ! grep -q "^start_x=1" /boot/config.txt && ! grep -q "^camera_auto_detect=1" /boot/config.txt; then
    echo "$(date) - Warning: Camera module might not be enabled in /boot/config.txt" >> "$HOME/camera_server.log"
fi

# Get current IP for logging
IP_ADDRESS=$(hostname -I | awk '{print $1}')
LOG_FILE="$HOME/camera_server.log"

# Rotate log if it's getting large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# Start the server
echo "$(date) - Starting PiCamera server on $IP_ADDRESS" >> "$LOG_FILE"
python main.py --camera picamera >> "$LOG_FILE" 2>&1
