#!/bin/bash

# Exit on error
set -e

# Get current directory (should be inside python_server in the cloned repo)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Default to parent directory of the script location
DEFAULT_INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
CAMERA_TYPE="auto"
VERBOSE=1
NON_INTERACTIVE=0
SKIP_REBOOT=0
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

# Parse command-line arguments
while getopts "c:i:vnrh" opt; do
  case $opt in
    c)
      CAMERA_TYPE="$OPTARG"
      ;;
    i)
      INSTALL_DIR="$OPTARG"
      ;;
    v)
      VERBOSE=1
      ;;
    n)
      NON_INTERACTIVE=1
      ;;
    r)
      SKIP_REBOOT=1
      ;;
    h)
      echo "Usage: $0 [-c camera_type] [-i install_dir] [-v] [-n] [-r] [-h]"
      echo "  -c camera_type   Camera type: 'auto', 'opencv', 'picamera', or 'picamera2'"
      echo "  -i install_dir   Installation directory (default: parent directory of this script)"
      echo "  -v               Verbose mode"
      echo "  -n               Non-interactive mode"
      echo "  -r               Skip reboot prompt"
      echo "  -h               Show this help"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "===================================="
echo "Camera Server - Cron Setup"
echo "===================================="
[ "$VERBOSE" -eq 1 ] && echo "📂 Using installation directory: $INSTALL_DIR"

# Function to auto-detect best available camera
detect_camera_type() {
  # Check for Raspberry Pi
  if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    # Try PiCamera2 first
    if command -v python3 -c "import picamera2" &> /dev/null || dpkg -l | grep -q python3-picamera2; then
      printf "picamera2\n"
      return
    fi
    
    # Then try PiCamera
    if command -v python3 -c "import picamera" &> /dev/null || dpkg -l | grep -q python3-picamera; then
      printf "picamera\n"
      return
    fi
  fi
  
  # Fall back to OpenCV
  printf "opencv\n"
}

# Function to select camera type
select_camera_type() {
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CAMERA_TYPE" ]; then
        if [ "$CAMERA_TYPE" = "opencv" ] || [ "$CAMERA_TYPE" = "picamera" ] || [ "$CAMERA_TYPE" = "picamera2" ] || [ "$CAMERA_TYPE" = "auto" ]; then
            printf "%s\n" "$CAMERA_TYPE"
            return
        fi
    fi
    
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        printf "auto\n"
        return
    fi
    
    while true; do
        >&2 printf "\nPlease select your camera type:\n"
        >&2 printf "1) Auto (automatically detect best camera)\n"
        >&2 printf "2) OpenCV (for standard webcams)\n"
        >&2 printf "3) PiCamera2 (for Raspberry Pi camera module - newer API)\n"
        >&2 printf "4) PiCamera (for Raspberry Pi camera module - legacy API)\n"
        >&2 printf "Enter your choice (1-4): "
        read -r choice
        
        case $choice in
            1)
                printf "auto\n"
                return
                ;;
            2)
                printf "opencv\n"
                return
                ;;
            3)
                printf "picamera2\n"
                return
                ;;
            4)
                printf "picamera\n"
                return
                ;;
            *)
                >&2 printf "Invalid choice. Please select 1, 2, 3, or 4.\n"
                ;;
        esac
    done
}

# Get camera type and capture it properly
if [ -z "$CAMERA_TYPE" ] || [ "$CAMERA_TYPE" = "auto" ]; then
    # Ask for camera type if not in non-interactive mode
    if [ "$NON_INTERACTIVE" -eq 0 ]; then
        CAMERA_TYPE="$(select_camera_type)"
    else
        CAMERA_TYPE="auto"
    fi
fi

# If auto is selected, detect the best camera
if [ "$CAMERA_TYPE" = "auto" ]; then
    [ "$VERBOSE" -eq 1 ] && echo "🔍 Detecting best available camera..."
    CAMERA_TYPE=$(detect_camera_type)
    [ "$VERBOSE" -eq 1 ] && echo "📷 Auto-detected camera type: $CAMERA_TYPE"
else
    [ "$VERBOSE" -eq 1 ] && echo "Using camera type: $CAMERA_TYPE"
fi

# Check if this is an update
UPDATE_MODE=0
if [ -d "$INSTALL_DIR" ]; then
    UPDATE_MODE=1
    [ "$VERBOSE" -eq 1 ] && echo "📥 Update mode detected - will upgrade existing installation"
fi

# Create install directory if it doesn't exist
[ "$VERBOSE" -eq 1 ] && echo "📁 Setting up installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy necessary files to installation directory
[ "$VERBOSE" -eq 1 ] && echo "📋 Copying server files..."
cp "$SCRIPT_DIR/main.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/server.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/camera_provider.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements-opencv.txt" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements-picamera.txt" "$INSTALL_DIR/"

# Copy setup_and_run.sh script (instead of individual run scripts)
[ "$VERBOSE" -eq 1 ] && echo "📋 Copying setup and run script..."
cp "$SCRIPT_DIR/setup_and_run.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/setup_and_run.sh"

# Create wrapper script for the cron job
WRAPPER_SCRIPT="$INSTALL_DIR/run_camera_server.sh"
[ "$VERBOSE" -eq 1 ] && echo "📝 Creating wrapper script for cron job..."

cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
# Log file setup
LOG_FILE="\$HOME/camera_server.log"

# Start with timestamp
echo "=========================================" >> "\$LOG_FILE"
echo "\$(date) - Starting camera server ($CAMERA_TYPE)" >> "\$LOG_FILE"
echo "=========================================" >> "\$LOG_FILE"

# Check if the server is already running
if pgrep -f "python main.py --camera" > /dev/null; then
    echo "WARNING: Camera server already running. Killing existing process..." >> "\$LOG_FILE"
    pkill -f "python main.py --camera" || echo "Failed to kill existing process" >> "\$LOG_FILE"
    sleep 2
fi

# Rotate log if it's getting large (>10MB)
if [ -f "\$LOG_FILE" ] && [ \$(stat -c%s "\$LOG_FILE" 2>/dev/null || stat -f%z "\$LOG_FILE") -gt 10485760 ]; then
    echo "Rotating log file (exceeds 10MB)" >> "\$LOG_FILE" 
    mv "\$LOG_FILE" "\${LOG_FILE}.old"
    echo "\$(date) - Log rotated, starting new log" > "\$LOG_FILE"
fi

# Run the setup_and_run script with the correct parameters
./setup_and_run.sh -c $CAMERA_TYPE -n >> "\$LOG_FILE" 2>&1

# This code only runs if the server exits
EXIT_CODE=\$?
echo "\$(date) - Server exited with code \$EXIT_CODE" >> "\$LOG_FILE"

# Try to restart if it crashed
if [ \$EXIT_CODE -ne 0 ]; then
    echo "Server crashed, waiting 10 seconds before restarting..." >> "\$LOG_FILE"
    sleep 10
    echo "\$(date) - Restarting server..." >> "\$LOG_FILE"
    ./setup_and_run.sh -c $CAMERA_TYPE -n >> "\$LOG_FILE" 2>&1
fi
EOF

chmod +x "$WRAPPER_SCRIPT"

# Install system dependencies if using PiCamera/PiCamera2
if [ "$CAMERA_TYPE" = "picamera" ] || [ "$CAMERA_TYPE" = "picamera2" ]; then
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        [ "$VERBOSE" -eq 1 ] && echo "Installing Raspberry Pi camera system dependencies..."
        
        if [ "$CAMERA_TYPE" = "picamera2" ]; then
            [ "$VERBOSE" -eq 1 ] && echo "Installing PiCamera2 system package..."
            sudo apt install -y python3-picamera2 python3-libcamera
        elif [ "$CAMERA_TYPE" = "picamera" ]; then
            [ "$VERBOSE" -eq 1 ] && echo "Installing PiCamera system package..."
            sudo apt install -y python3-picamera
        fi
        
        # Set up camera permissions
        sudo usermod -a -G video $USER
    fi
fi

# Create or update cron job
[ "$VERBOSE" -eq 1 ] && echo "⏰ Setting up cron job for automatic startup..."
CRON_JOB="@reboot $INSTALL_DIR/run_camera_server.sh"

# Remove any existing cron jobs for this script
crontab -l 2>/dev/null | grep -v "run_camera_server.sh\|run_opencv_camera.sh\|run_picamera_camera.sh\|run_picamera2_camera.sh" | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Status message
if [ "$UPDATE_MODE" -eq 1 ]; then
    echo "===================================="
    echo "✅ Cron job updated!"
else
    echo "===================================="
    echo "✅ Cron job setup complete!"
fi

echo "===================================="
echo "The camera server will now automatically start on boot."
echo "You can check the server logs at: $HOME/camera_server.log"
echo "To manually start the server, run:"
echo "$ $INSTALL_DIR/run_camera_server.sh"
echo "===================================="

# Print IP address for reference
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "🌐 Your current IP address: $IP_ADDRESS"
echo "Camera server will be accessible at: http://$IP_ADDRESS:12345"

if [ "$SKIP_REBOOT" -eq 0 ] && [ "$NON_INTERACTIVE" -eq 0 ]; then
    read -p "Do you want to reboot now to test automatic startup? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Rebooting system..."
        sudo reboot
    else
        echo "Remember to reboot later to enable automatic startup."
    fi
fi
