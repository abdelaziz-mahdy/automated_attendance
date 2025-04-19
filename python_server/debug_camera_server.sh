#!/bin/bash

# Exit on error
set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config file location
CONFIG_FILE="$HOME/.automated_attendance_config"

# Try to detect the installation directory
# First check if we have it in the config file
if [ -f "$CONFIG_FILE" ]; then
    # Safely extract values from config file without sourcing it
    INSTALL_DIR=$(grep "^INSTALL_DIR=" "$CONFIG_FILE" | cut -d'=' -f2)
    CONFIG_CAMERA_TYPE=$(grep "^CAMERA_TYPE=" "$CONFIG_FILE" | cut -d'=' -f2)
    
    if [ -n "$INSTALL_DIR" ]; then
        echo -e "${BLUE}Found installation directory from config: $INSTALL_DIR${NC}"
        if [ -n "$CONFIG_CAMERA_TYPE" ]; then
            echo -e "${BLUE}Found camera type from config: $CONFIG_CAMERA_TYPE${NC}"
            CAMERA_TYPE="$CONFIG_CAMERA_TYPE"
        fi
    else
        # Fallback if we couldn't parse the config file
        INSTALL_DIR=""
    fi
else
    INSTALL_DIR=""
fi

# If we couldn't get the directory from config, try to detect it
if [ -z "$INSTALL_DIR" ]; then
    # If not in config file, try to find it from the script location
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    if [ -f "$SCRIPT_DIR/main.py" ] && [ -f "$SCRIPT_DIR/camera_provider.py" ]; then
        # Script is inside the installation directory
        INSTALL_DIR="$SCRIPT_DIR"
    else
        # Try the parent directory (if script is in python_server subdir)
        POTENTIAL_DIR="$(dirname "$SCRIPT_DIR")"
        if [ -f "$POTENTIAL_DIR/main.py" ] && [ -f "$POTENTIAL_DIR/camera_provider.py" ]; then
            INSTALL_DIR="$POTENTIAL_DIR"
        else
            # Fall back to the default location
            INSTALL_DIR="$HOME/automated_attendance"
            echo -e "${YELLOW}Warning: Could not detect installation directory automatically.${NC}"
            echo -e "${YELLOW}Using default: $INSTALL_DIR${NC}"
        fi
    fi
fi

LOG_FILE="$HOME/camera_server.log"

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}Camera Server Diagnostic Tool${NC}"
echo -e "${BLUE}===================================${NC}"
echo -e "Installation directory: ${GREEN}$INSTALL_DIR${NC}"

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
    
    # List virtual environment contents
    echo "  Virtual environment contents:"
    ls -la "$INSTALL_DIR/.venv/bin" | head -10
    
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

echo -e "\n${BLUE}[4/7] Checking installation directory...${NC}"
echo "  Installation directory: $INSTALL_DIR"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}✓ Installation directory exists${NC}"
    echo "  Directory contents:"
    ls -la "$INSTALL_DIR" | head -20
    
    # Check for key files
    for file in main.py server.py camera_provider.py run_camera_server.sh setup_and_run.sh; do
        if [ -f "$INSTALL_DIR/$file" ];then
            echo -e "  ${GREEN}✓ $file exists${NC}"
        else
            echo -e "  ${RED}✗ $file missing${NC}"
        fi
    done
else
    echo -e "${RED}✗ Installation directory does not exist${NC}"
    echo "  Create it with: mkdir -p $INSTALL_DIR"
fi

echo -e "\n${BLUE}[5/7] Checking cron configuration...${NC}"
if crontab -l 2>/dev/null | grep -q "run_camera_server.sh"; then
    echo -e "${GREEN}✓ Cron job is set up for camera server${NC}"
    echo "  Current cron configuration:"
    crontab -l | grep -E "run_camera_server|camera_server|automated_attendance"
    
    # Check if the script exists at the path specified in cron
    CRON_PATH=$(crontab -l | grep "run_camera_server.sh" | awk '{print $NF}')
    if [ -n "$CRON_PATH" ] && [ -f "$CRON_PATH" ]; then
        echo -e "  ${GREEN}✓ Script exists at path specified in cron: $CRON_PATH${NC}"
    else
        echo -e "  ${RED}✗ Script does not exist at path specified in cron: $CRON_PATH${NC}"
        echo "  Run cron_setup.sh again to fix the path"
    fi
else
    echo -e "${RED}✗ No cron job found for camera server${NC}"
    echo "  Run cron_setup.sh to set up automatic startup"
fi

echo -e "\n${BLUE}[6/7] Checking camera type...${NC}"
# Get camera type from config file or wrapper script
if [ -n "$CAMERA_TYPE" ]; then
    echo -e "  Camera type from config: ${GREEN}$CAMERA_TYPE${NC}"
elif [ -f "$INSTALL_DIR/run_camera_server.sh" ]; then
    CAMERA_TYPE=$(grep "Starting camera server" "$INSTALL_DIR/run_camera_server.sh" | sed -E 's/.*camera server \(([^)]+)\).*/\1/')
    echo -e "  Camera type from wrapper script: ${GREEN}$CAMERA_TYPE${NC}"
else
    CAMERA_TYPE="unknown"
    echo -e "  ${RED}✗ Could not determine camera type${NC}"
fi

# Check for appropriate camera support
if [ "$CAMERA_TYPE" = "opencv" ]; then
    echo -e "  ${GREEN}✓ Using OpenCV camera${NC}"
    # Check if OpenCV is installed in the virtual environment
    if [ -d "$INSTALL_DIR/.venv" ] && [ -f "$INSTALL_DIR/.venv/bin/pip" ] && "$INSTALL_DIR/.venv/bin/pip" list | grep -q "opencv-python"; then
        echo -e "  ${GREEN}✓ OpenCV is installed in virtual environment${NC}"
    else
        echo -e "  ${RED}✗ OpenCV not installed in virtual environment${NC}"
        echo "  Run setup_and_run.sh to install dependencies"
    fi
elif [ "$CAMERA_TYPE" = "picamera2" ]; then
    echo -e "  ${GREEN}✓ Using PiCamera2${NC}"
    # Check if picamera2 is available
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        if python3 -c "import picamera2" &> /dev/null || dpkg -l | grep -q python3-picamera2; then
            echo -e "  ${GREEN}✓ PiCamera2 is available on the system${NC}"
        else
            echo -e "  ${RED}✗ PiCamera2 is not installed${NC}"
            echo "  Install with: sudo apt install -y python3-picamera2 python3-libcamera"
        fi
    else
        echo -e "  ${RED}✗ Not running on a Raspberry Pi${NC}"
    fi
elif [ "$CAMERA_TYPE" = "picamera" ]; then
    echo -e "  ${GREEN}✓ Using PiCamera (legacy)${NC}"
    # Check if picamera is available
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        if python3 -c "import picamera" &> /dev/null || dpkg -l | grep -q python3-picamera; then
            echo -e "  ${GREEN}✓ PiCamera is available on the system${NC}"
        else
            echo -e "  ${RED}✗ PiCamera is not installed${NC}"
            echo "  Install with: sudo apt install -y python3-picamera"
        fi
    else
        echo -e "  ${RED}✗ Not running on a Raspberry Pi${NC}"
    fi
else
    echo -e "  ${YELLOW}? Unknown camera type: $CAMERA_TYPE${NC}"
fi

# Check if setup_and_run.sh exists and is executable
if [ -f "$INSTALL_DIR/setup_and_run.sh" ]; then
    if [ -x "$INSTALL_DIR/setup_and_run.sh" ]; then
        echo -e "  ${GREEN}✓ setup_and_run.sh exists and is executable${NC}"
    else
        echo -e "  ${RED}✗ setup_and_run.sh exists but is not executable${NC}"
        echo "  Run: chmod +x $INSTALL_DIR/setup_and_run.sh"
    fi
else
    echo -e "  ${RED}✗ setup_and_run.sh missing${NC}"
fi

echo -e "\n${BLUE}[7/7] Checking log file...${NC}"
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
echo "   - Make sure setup_and_run.sh is executable (chmod +x)"
echo "   - Try running setup_and_run.sh manually to see immediate errors"
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
echo "   - Try reinstalling with: cd $INSTALL_DIR && ./setup_and_run.sh"
echo "   - Or reconfigure cron with: cd $INSTALL_DIR && ./cron_setup.sh"
echo -e "${BLUE}===================================${NC}"
