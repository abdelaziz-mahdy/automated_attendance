#!/bin/bash
cd "$(dirname "$0")"

# Log file setup
LOG_FILE="$HOME/camera_server.log"

# Start with timestamp and identification
echo "=========================================" >> "$LOG_FILE"
echo "$(date) - Starting PiCamera server" >> "$LOG_FILE"
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

# Check if we're on a Raspberry Pi
if [ ! -f "/proc/device-tree/model" ] || ! grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    echo "ERROR: This script is intended for Raspberry Pi only." >> "$LOG_FILE"
    echo "Device model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Not a Raspberry Pi')" >> "$LOG_FILE"
    exit 1
fi

# Check if user is in video group (required for camera access)
if ! groups | grep -q "video"; then
    echo "WARNING: Current user is not in the video group. This may cause permission issues." >> "$LOG_FILE"
    echo "Current user groups: $(groups)" >> "$LOG_FILE"
    echo "Run 'sudo usermod -a -G video $USER' and reboot to fix this." >> "$LOG_FILE"
fi

# Check if the camera module is enabled
if ! grep -q "^start_x=1\|^camera_auto_detect=1" /boot/config.txt; then
    echo "WARNING: Camera module might not be enabled in /boot/config.txt" >> "$LOG_FILE"
    echo "Current camera settings in /boot/config.txt:" >> "$LOG_FILE"
    grep -E "camera|start_x" /boot/config.txt >> "$LOG_FILE" 2>&1 || echo "No camera settings found" >> "$LOG_FILE"
fi

# Check if picamera is installed on the system
if python3 -c "import picamera" 2>/dev/null; then
    echo "PiCamera is available on the system" >> "$LOG_FILE"
else
    echo "WARNING: PiCamera is not installed system-wide. Will check virtual environment." >> "$LOG_FILE"
fi

# Activate virtual environment if it exists
if [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment at .venv" >> "$LOG_FILE"
    source .venv/bin/activate
    
    # Verify Python and pip in the venv
    echo "Python version: $(.venv/bin/python --version 2>&1)" >> "$LOG_FILE"
    echo "Pip version: $(.venv/bin/pip --version 2>&1)" >> "$LOG_FILE"
    
    # Check for PiCamera in venv
    if .venv/bin/python -c "import picamera" 2>/dev/null; then
        echo "PiCamera is available in virtual environment" >> "$LOG_FILE"
    else
        echo "WARNING: PiCamera not found in virtual environment" >> "$LOG_FILE"
        echo "Attempting to install PiCamera..." >> "$LOG_FILE"
        .venv/bin/pip install "picamera[array]" >> "$LOG_FILE" 2>&1
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
    
    echo "Creating virtual environment with system site packages..." >> "$LOG_FILE"
    python3 -m venv --system-site-packages .venv
    source .venv/bin/activate
    echo "Installing requirements..." >> "$LOG_FILE"
    uv pip install -r requirements-picamera.txt --extra-index-url https://www.piwheels.org/simple >> "$LOG_FILE" 2>&1 || {
        echo "ERROR: Failed to install requirements. Trying direct pip..." >> "$LOG_FILE"
        .venv/bin/pip install -r requirements-picamera.txt >> "$LOG_FILE" 2>&1 || {
            echo "CRITICAL ERROR: Failed to install requirements. Exiting." >> "$LOG_FILE"
            exit 1
        }
    }
    echo "Setup complete." >> "$LOG_FILE"
fi

# Get current IP for logging
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Server IP Address: $IP_ADDRESS" >> "$LOG_FILE"

# Rotate log if it's getting large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
    echo "Rotating log file (exceeds 10MB)" >> "$LOG_FILE"
    mv "$LOG_FILE" "${LOG_FILE}.old"
    echo "$(date) - Log rotated, starting new log" > "$LOG_FILE"
fi

# Check if the server is already running
if pgrep -f "python main.py --camera picamera" > /dev/null; then
    echo "WARNING: Camera server already running. Killing existing process..." >> "$LOG_FILE"
    pkill -f "python main.py --camera picamera" || echo "Failed to kill existing process" >> "$LOG_FILE"
    sleep 2
fi

# Start the server with both stdout and stderr going to log
echo "Starting server: python main.py --camera picamera" >> "$LOG_FILE"
python main.py --camera picamera >> "$LOG_FILE" 2>&1

# This code only runs if the server exits
EXIT_CODE=$?
echo "$(date) - Server exited with code $EXIT_CODE" >> "$LOG_FILE"

# Try to restart if it crashed
if [ $EXIT_CODE -ne 0 ]; then
    echo "Server crashed, waiting 10 seconds before restarting..." >> "$LOG_FILE"
    sleep 10
    echo "$(date) - Restarting server..." >> "$LOG_FILE"
    python main.py --camera picamera >> "$LOG_FILE" 2>&1
fi
