#!/bin/bash
cd "$(dirname "$0")"

# Log file setup
LOG_FILE="$HOME/camera_server.log"

# Start with timestamp and identification
echo "=========================================" >> "$LOG_FILE"
echo "$(date) - Starting OpenCV camera server" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check if we're running as the correct user
echo "Running as user: $(whoami)" >> "$LOG_FILE"

# Load environment variables if they exist
if [ -f "$HOME/.profile" ]; then
    echo "Loading environment from $HOME/.profile" >> "$LOG_FILE"
    source "$HOME/.profile"
else
    echo "No .profile found in $HOME" >> "$LOG_FILE"
fi

# Check for camera devices
if [ -e /dev/video0 ]; then
    echo "Found camera device at /dev/video0" >> "$LOG_FILE"
    ls -l /dev/video* >> "$LOG_FILE" 2>&1
else
    echo "WARNING: No camera device found at /dev/video0" >> "$LOG_FILE"
    echo "Available devices in /dev:" >> "$LOG_FILE"
    ls -l /dev/v* >> "$LOG_FILE" 2>&1 || echo "No video devices found" >> "$LOG_FILE"
fi

# Activate virtual environment if it exists
if [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment at .venv" >> "$LOG_FILE"
    source .venv/bin/activate
    
    # Verify Python and pip in the venv
    echo "Python version: $(.venv/bin/python --version 2>&1)" >> "$LOG_FILE"
    echo "Pip version: $(.venv/bin/pip --version 2>&1)" >> "$LOG_FILE"
    
    # Check for OpenCV
    if .venv/bin/pip list | grep -q "opencv-python"; then
        echo "OpenCV is installed in virtual environment" >> "$LOG_FILE"
    else
        echo "ERROR: OpenCV not found in virtual environment" >> "$LOG_FILE"
    fi
else
    echo "Virtual environment missing or corrupted. Recreating..." >> "$LOG_FILE"
    rm -rf .venv
    
    # Check if uv is installed
    if ! command -v uv &> /dev/null; then
        echo "uv not found, installing it..." >> "$LOG_FILE"
        pip3 install uv || { 
            echo "Failed to install uv. Trying with pip directly..." >> "$LOG_FILE"
            python3 -m pip install uv || {
                echo "CRITICAL ERROR: Failed to install uv. Exiting." >> "$LOG_FILE"
                exit 1
            }
        }
    fi
    
    echo "Creating virtual environment with uv..." >> "$LOG_FILE"
    uv venv .venv
    source .venv/bin/activate
    echo "Installing requirements..." >> "$LOG_FILE"
    uv pip install -r requirements-opencv.txt >> "$LOG_FILE" 2>&1 || {
        echo "ERROR: Failed to install requirements." >> "$LOG_FILE"
        exit 1
    }
    echo "Setup complete." >> "$LOG_FILE"
fi

# Get current IP for logging
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Server IP Address: $IP_ADDRESS" >> "$LOG_FILE"

# Rotate log if it's getting large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE") -gt 10485760 ]; then
    echo "Rotating log file (exceeds 10MB)" >> "$LOG_FILE"
    mv "$LOG_FILE" "${LOG_FILE}.old"
    echo "$(date) - Log rotated, starting new log" > "$LOG_FILE"
fi

# Check if the server is already running
if pgrep -f "python main.py --camera opencv" > /dev/null; then
    echo "WARNING: Camera server already running. Killing existing process..." >> "$LOG_FILE"
    pkill -f "python main.py --camera opencv" || echo "Failed to kill existing process" >> "$LOG_FILE"
    sleep 2
fi

# Start the server with both stdout and stderr going to log
echo "Starting server: python main.py --camera opencv" >> "$LOG_FILE"
python main.py --camera opencv >> "$LOG_FILE" 2>&1

# This code only runs if the server exits
EXIT_CODE=$?
echo "$(date) - Server exited with code $EXIT_CODE" >> "$LOG_FILE"

# Try to restart if it crashed
if [ $EXIT_CODE -ne 0 ]; then
    echo "Server crashed, waiting 10 seconds before restarting..." >> "$LOG_FILE"
    sleep 10
    echo "$(date) - Restarting server..." >> "$LOG_FILE"
    python main.py --camera opencv >> "$LOG_FILE" 2>&1
fi
