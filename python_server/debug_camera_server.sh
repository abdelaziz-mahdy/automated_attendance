#!/bin/bash

# Exit on error
set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get installation directory, defaulting to current directory if not specified
INSTALL_DIR="${1:-$HOME/camera_server}"
LOG_FILE="$HOME/camera_server.log"

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}Camera Server Diagnostic Tool${NC}"
echo -e "${BLUE}===================================${NC}"

echo -e "\n${BLUE}[1/7] Checking if server is running...${NC}"
if pgrep -f "python main.py --camera" > /dev/null; then
    echo -e "${GREEN}✓ Server process is running${NC}"
    ps aux | grep "python main.py --camera" | grep -v grep
else
    echo -e "${RED}✗ Server process is not running${NC}"
    echo "  To start the server manually, run: $INSTALL_DIR/run_camera_server.sh"
fi

echo -e "\n${BLUE}[2/7] Checking server port...${NC}"
if command -v netstat > /dev/null; then
    if netstat -tuln | grep ":12345 " > /dev/null; then
        echo -e "${GREEN}✓ Server port 12345 is open and listening${NC}"
    else
        echo -e "${RED}✗ Server port 12345 is not open${NC}"
        echo "  This indicates the server is not running or failed to start"
    fi
elif command -v ss > /dev/null; then
    if ss -tuln | grep ":12345 " > /dev/null; then
        echo -e "${GREEN}✓ Server port 12345 is open and listening${NC}"
    else
        echo -e "${RED}✗ Server port 12345 is not open${NC}"
        echo "  This indicates the server is not running or failed to start"
    fi
else
    echo -e "${YELLOW}? Cannot check port status - neither netstat nor ss are available${NC}"
fi

echo -e "\n${BLUE}[3/7] Checking virtual environment...${NC}"
if [ -d "$INSTALL_DIR/.venv" ] && [ -f "$INSTALL_DIR/.venv/bin/activate" ]; then
    echo -e "${GREEN}✓ Virtual environment exists${NC}"
    
    # Check Python and pip in virtual environment
    if [ -f "$INSTALL_DIR/.venv/bin/python" ]; then
        echo -e "${GREEN}✓ Python executable exists in virtual environment${NC}"
        PYTHON_VERSION=$("$INSTALL_DIR/.venv/bin/python" --version 2>&1)
        echo "  $PYTHON_VERSION"
    else
        echo -e "${RED}✗ Python executable missing from virtual environment${NC}"
    fi
    
    if [ -f "$INSTALL_DIR/.venv/bin/pip" ]; then
        echo -e "${GREEN}✓ Pip exists in virtual environment${NC}"
    else
        echo -e "${RED}✗ Pip missing from virtual environment${NC}"
    fi
else
    echo -e "${RED}✗ Virtual environment missing or incomplete${NC}"
    echo "  Run setup_and_run.sh to recreate the virtual environment"
fi

echo -e "\n${BLUE}[4/7] Checking camera type...${NC}"
if [ -h "$INSTALL_DIR/run_camera_server.sh" ]; then
    CAMERA_SCRIPT=$(readlink "$INSTALL_DIR/run_camera_server.sh")
    echo "  Camera script: $CAMERA_SCRIPT"
    
    if [[ $CAMERA_SCRIPT == *"opencv"* ]]; then
        echo -e "${GREEN}✓ Using OpenCV camera${NC}"
        # Check if OpenCV is installed in the virtual environment
        if [ -d "$INSTALL_DIR/.venv" ] && "$INSTALL_DIR/.venv/bin/pip" list | grep -q "opencv-python"; then
            echo -e "${GREEN}✓ OpenCV is installed in virtual environment${NC}"
        else
            echo -e "${RED}✗ OpenCV not installed in virtual environment${NC}"
        fi
    elif [[ $CAMERA_SCRIPT == *"picamera2"* ]]; then
        echo -e "${GREEN}✓ Using PiCamera2${NC}"
        # Check if picamera2 is available
        if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
            if command -v python3 -c "import picamera2" &> /dev/null || dpkg -l | grep -q python3-picamera2; then
                echo -e "${GREEN}✓ PiCamera2 is available on the system${NC}"
            else
                echo -e "${RED}✗ PiCamera2 is not installed${NC}"
                echo "  Install with: sudo apt install -y python3-picamera2 python3-libcamera"
            fi
        else
            echo -e "${RED}✗ Not running on a Raspberry Pi${NC}"
        fi
    elif [[ $CAMERA_SCRIPT == *"picamera"* ]]; then
        echo -e "${GREEN}✓ Using PiCamera (legacy)${NC}"
        # Check if picamera is available
        if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
            if command -v python3 -c "import picamera" &> /dev/null || dpkg -l | grep -q python3-picamera; then
                echo -e "${GREEN}✓ PiCamera is available on the system${NC}"
            else
                echo -e "${RED}✗ PiCamera is not installed${NC}"
                echo "  Install with: sudo apt install -y python3-picamera"
            fi
        else
            echo -e "${RED}✗ Not running on a Raspberry Pi${NC}"
        fi
    else
        echo -e "${YELLOW}? Unknown camera type${NC}"
    fi
else
    echo -e "${RED}✗ Camera script symlink not found${NC}"
    echo "  Run cron_setup.sh to set up the appropriate camera script"
fi

echo -e "\n${BLUE}[5/7] Checking camera permissions...${NC}"
if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    # Check if user is in video group (for Pi camera access)
    if groups | grep -q "video"; then
        echo -e "${GREEN}✓ User is in video group (required for camera access)${NC}"
    else
        echo -e "${RED}✗ User is not in video group${NC}"
        echo "  Run: sudo usermod -a -G video $USER"
        echo "  Then log out and log back in for changes to take effect"
    fi
    
    # Check camera module config
    if grep -q "^start_x=1\|^camera_auto_detect=1" /boot/config.txt; then
        echo -e "${GREEN}✓ Camera module is enabled in /boot/config.txt${NC}"
    else
        echo -e "${RED}✗ Camera module might not be enabled${NC}"
        echo "  Add 'camera_auto_detect=1' or 'start_x=1' to /boot/config.txt and reboot"
    fi
else
    # For non-Pi systems, check for video devices
    if [ -d "/dev/video0" ]; then
        echo -e "${GREEN}✓ Camera device found at /dev/video0${NC}"
        ls -l /dev/video*
    else
        echo -e "${YELLOW}? No video devices found at /dev/video*${NC}"
        echo "  If using USB webcam, ensure it's connected properly"
    fi
fi

echo -e "\n${BLUE}[6/7] Checking log file...${NC}"
if [ -f "$LOG_FILE" ]; then
    echo -e "${GREEN}✓ Log file exists: $LOG_FILE${NC}"
    
    # Check log file size
    LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
    echo "  Log file size: $LOG_SIZE"
    
    # Look for error messages in the log
    ERROR_COUNT=$(grep -c -i "error\|exception\|fail" "$LOG_FILE")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}✗ Found $ERROR_COUNT error/exception messages in log${NC}"
        echo "  Last 5 error messages:"
        grep -i "error\|exception\|fail" "$LOG_FILE" | tail -5
    else
        echo -e "${GREEN}✓ No obvious errors found in log${NC}"
    fi
    
    # Show last few log entries
    echo "  Last 5 log entries:"
    tail -5 "$LOG_FILE"
else
    echo -e "${YELLOW}? Log file not found: $LOG_FILE${NC}"
    echo "  The server might not have started yet or is logging elsewhere"
fi

echo -e "\n${BLUE}[7/7] Checking cron job...${NC}"
if crontab -l 2>/dev/null | grep -q "run_camera_server.sh"; then
    echo -e "${GREEN}✓ Cron job is set up for camera server${NC}"
    crontab -l | grep "camera_server"
else
    echo -e "${RED}✗ No cron job found for camera server${NC}"
    echo "  Run cron_setup.sh to set up automatic startup"
fi

echo -e "\n${BLUE}===================================${NC}"
echo -e "${BLUE}System Information${NC}"
echo -e "${BLUE}===================================${NC}"

# Show IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo -e "🌐 IP Address: ${GREEN}$IP_ADDRESS${NC}"
echo "  Camera server should be accessible at: http://$IP_ADDRESS:12345"

# Show system information
echo -e "\nSystem: $(uname -a)"
if [ -f "/proc/device-tree/model" ]; then
    echo -e "Device: $(cat /proc/device-tree/model)"
fi

# Show disk space
echo -e "\nDisk Space:"
df -h | grep -E '/$|/home'

echo -e "\n${BLUE}===================================${NC}"
echo -e "${BLUE}Troubleshooting Tips${NC}"
echo -e "${BLUE}===================================${NC}"
echo "1. If the server isn't starting automatically:"
echo "   - Check the cron job is set up correctly (crontab -l)"
echo "   - Make sure run_camera_server.sh is executable (chmod +x)"
echo "   - Try running it manually to see immediate errors"
echo ""
echo "2. If the camera isn't working:"
echo "   - Check camera connections and permissions"
echo "   - For Raspberry Pi, ensure camera is enabled in raspi-config"
echo "   - For USB webcams, ensure it's properly connected and recognized"
echo ""
echo "3. For more detailed logs:"
echo "   - Run the server manually with: $INSTALL_DIR/run_camera_server.sh"
echo "   - Check the log file: less $LOG_FILE"
echo ""
echo "4. To restart the server:"
echo "   - Kill the process: pkill -f 'python main.py'"
echo "   - Start it again: $INSTALL_DIR/run_camera_server.sh"
echo ""
echo "5. If all else fails:"
echo "   - Try reinstalling with: ./setup_and_run.sh"
echo "   - Or reconfigure cron with: ./cron_setup.sh"
echo -e "${BLUE}===================================${NC}"
