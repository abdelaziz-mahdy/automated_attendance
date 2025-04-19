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
CONFIG_FILE="$HOME/.automated_attendance_config"

# Use the script's location as the installation directory
INSTALL_DIR="$SCRIPT_DIR"

# Parse command-line arguments
while getopts "c:vnrh" opt; do
  case $opt in
    c)
      CAMERA_TYPE="$OPTARG"
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
      echo "Usage: $0 [-c camera_type] [-v] [-n] [-r] [-h]"
      echo "  -c camera_type   Camera type: 'auto', 'opencv', 'picamera', or 'picamera2'"
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
[ "$VERBOSE" -eq 1 ] && echo "📂 Using script directory: $INSTALL_DIR"

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
    
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CAMERA_TYPE" ]; then
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

# Save the installation directory to config file for debugging - MOVED HERE AFTER DETECTION
echo "INSTALL_DIR=$INSTALL_DIR" > "$CONFIG_FILE"
echo "CAMERA_TYPE=$CAMERA_TYPE" >> "$CONFIG_FILE"
echo "SETUP_DATE=\"$(date)\"" >> "$CONFIG_FILE"  # Quote the date value to avoid shell interpretation
chmod 600 "$CONFIG_FILE"
[ "$VERBOSE" -eq 1 ] && echo "💾 Saved configuration to $CONFIG_FILE (with camera type: $CAMERA_TYPE)"

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

# Source profile files to get environment variables (important for cron jobs)
for profile in /etc/profile ~/.bash_profile ~/.bashrc ~/.profile; do
    if [ -f "\$profile" ]; then
        echo "Sourcing \$profile" >> "\$LOG_FILE" 2>&1
        . "\$profile" >> "\$LOG_FILE" 2>&1
    fi
done

# Export PATH to include common locations
export PATH="\$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
echo "PATH: \$PATH" >> "\$LOG_FILE"

# Check for required tools
command -v python3 >/dev/null 2>&1 || { echo "Python3 not found in PATH: \$PATH" >> "\$LOG_FILE"; exit 1; }
echo "Using Python: \$(command -v python3) \$(python3 --version 2>&1)" >> "\$LOG_FILE"

# Check if we have pip installer available
if command -v uv >/dev/null 2>&1; then
    echo "Using uv: \$(command -v uv) \$(uv --version 2>&1)" >> "\$LOG_FILE" 
    PIP_CMD="uv pip"
elif command -v pip3 >/dev/null 2>&1; then
    echo "Using pip3: \$(command -v pip3) \$(pip3 --version 2>&1)" >> "\$LOG_FILE"
    PIP_CMD="pip3"
elif command -v pip >/dev/null 2>&1; then
    echo "Using pip: \$(command -v pip) \$(pip --version 2>&1)" >> "\$LOG_FILE"
    PIP_CMD="pip"
else
    echo "ERROR: No pip installer found. Please install pip or uv." >> "\$LOG_FILE"
    exit 1
fi

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

# Just run the setup_and_run.sh script with the right parameters
echo "Running setup_and_run.sh from current directory..." >> "\$LOG_FILE"
./setup_and_run.sh -c $CAMERA_TYPE -n >> "\$LOG_FILE" 2>&1
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
        
  
    fi
fi

# Create or update cron job
[ "$VERBOSE" -eq 1 ] && echo "⏰ Setting up cron job for automatic startup..."
CRON_JOB="@reboot $INSTALL_DIR/run_camera_server.sh"

# Remove any existing cron jobs for camera server scripts
[ "$VERBOSE" -eq 1 ] && echo "Removing any existing camera server cron jobs..."
(crontab -l 2>/dev/null | grep -v "run_camera_server.sh\|automated_attendance\|camera_server" || echo "") | crontab -

# Add new cron job
[ "$VERBOSE" -eq 1 ] && echo "Adding new cron job: $CRON_JOB"
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Verify cron job was added correctly
if crontab -l 2>/dev/null | grep -q "$INSTALL_DIR/run_camera_server.sh"; then
    [ "$VERBOSE" -eq 1 ] && echo "✅ Verified cron job was added correctly"
else
    [ "$VERBOSE" -eq 1 ] && echo "⚠️ Warning: Could not verify cron job. Please check 'crontab -l' manually."
fi

# Status message
echo "===================================="
echo "✅ Cron job setup complete!"
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
