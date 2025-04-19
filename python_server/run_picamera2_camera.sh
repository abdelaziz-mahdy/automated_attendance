#!/bin/bash
cd "$(dirname "$0")"

# Log file setup
LOG_FILE="$HOME/camera_server.log"

# Start with timestamp and identification
echo "=========================================" >> "$LOG_FILE"
echo "$(date) - Starting PiCamera2 server" >> "$LOG_FILE"
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

# List connected cameras using libcamera-still if available
if command -v libcamera-still &> /dev/null; then
    echo "Connected cameras:" >> "$LOG_FILE"
    libcamera-still --list-cameras >> "$LOG_FILE" 2>&1 || echo "Failed to list cameras" >> "$LOG_FILE"
fi

# Check if picamera2 is installed on the system
if python3 -c "import picamera2" 2>/dev/null; then
    echo "PiCamera2 is available on the system" >> "$LOG_FILE"
    
    # Check picamera2 version
    PICAMERA2_VERSION=$(python3 -c "import picamera2; print(picamera2.__version__)" 2>/dev/null || echo "Unknown")
    echo "PiCamera2 version: $PICAMERA2_VERSION" >> "$LOG_FILE"
else
    echo "WARNING: PiCamera2 is not installed system-wide." >> "$LOG_FILE"
    echo "Checking if libcamera packages are installed..." >> "$LOG_FILE"
    dpkg -l | grep -E "libcamera|picamera2" >> "$LOG_FILE" 2>&1 || echo "No libcamera packages found" >> "$LOG_FILE"
    
    echo "Attempting to install PiCamera2 system packages..." >> "$LOG_FILE"
    sudo apt update && sudo apt install -y python3-picamera2 python3-libcamera >> "$LOG_FILE" 2>&1 || {
        echo "CRITICAL ERROR: Failed to install PiCamera2 packages. Exiting." >> "$LOG_FILE"
        exit 1
    }
fi

# Activate virtual environment if it exists
if [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment at .venv" >> "$LOG_FILE"
    source .venv/bin/activate
    
    # Verify Python and pip in the venv
    echo "Python version: $(.venv/bin/python --version 2>&1)" >> "$LOG_FILE"
    echo "Pip version: $(.venv/bin/pip --version 2>&1)" >> "$LOG_FILE"
    
    # Check for PiCamera2 in venv (for API access, system package still needed)
    if .venv/bin/python -c "import picamera2" 2>/dev/null; then
        echo "PiCamera2 is accessible in virtual environment" >> "$LOG_FILE"
    else
        echo "WARNING: PiCamera2 not accessible in virtual environment" >> "$LOG_FILE"
        echo "Creating a venv with system site packages..." >> "$LOG_FILE"
        rm -rf .venv
        python3 -m venv --system-site-packages .venv
        source .venv/bin/activate
    fi
else
    echo "Virtual environment missing or corrupted. Recreating..." >> "$LOG_FILE"
    rm -rf .venv
    
    echo "Creating virtual environment with system site packages..." >> "$LOG_FILE"
    python3 -m venv --system-site-packages .venv
    source .venv/bin/activate
    echo "Installing requirements..." >> "$LOG_FILE"
    pip install -r requirements-picamera.txt --extra-index-url https://www.piwheels.org/simple >> "$LOG_FILE" 2>&1 || {
        echo "WARNING: Failed to install requirements with pip." >> "$LOG_FILE"
        echo "Installing minimal requirements..." >> "$LOG_FILE"
        pip install fastapi uvicorn >> "$LOG_FILE" 2>&1 || {
            echo "CRITICAL ERROR: Failed to install minimal requirements. Exiting." >> "$LOG_FILE"
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
if pgrep -f "python main.py --camera picamera2" > /dev/null; then
    echo "WARNING: Camera server already running. Killing existing process..." >> "$LOG_FILE"
    pkill -f "python main.py --camera picamera2" || echo "Failed to kill existing process" >> "$LOG_FILE"
    sleep 2
fi

# Start the server with both stdout and stderr going to log
echo "Starting server: python main.py --camera picamera2" >> "$LOG_FILE"
python main.py --camera picamera2 >> "$LOG_FILE" 2>&1

# This code only runs if the server exits
EXIT_CODE=$?
echo "$(date) - Server exited with code $EXIT_CODE" >> "$LOG_FILE"

# Try to restart if it crashed
if [ $EXIT_CODE -ne 0 ]; then
    echo "Server crashed, waiting 10 seconds before restarting..." >> "$LOG_FILE"
    sleep 10
    echo "$(date) - Restarting server..." >> "$LOG_FILE"
    python main.py --camera picamera2 >> "$LOG_FILE" 2>&1
fi
