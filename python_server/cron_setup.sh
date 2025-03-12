#!/bin/bash

# Exit on error
set -e

# Default values
CAMERA_TYPE=""
VERBOSE=1
NON_INTERACTIVE=0
SKIP_REBOOT=0
INSTALL_DIR="$HOME/camera_server"

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
      echo "  -c camera_type   Camera type: 'opencv' or 'picamera'"
      echo "  -i install_dir   Installation directory (default: ~/camera_server)"
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

# Get current directory (should be inside python_server in the cloned repo)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

echo "===================================="
echo "Camera Server - Cron Setup"
echo "===================================="

# Function to select camera type
select_camera_type() {
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CAMERA_TYPE" ]; then
        if [ "$CAMERA_TYPE" = "opencv" ] || [ "$CAMERA_TYPE" = "picamera" ]; then
            printf "%s\n" "$CAMERA_TYPE"
            return
        fi
    fi
    
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        printf "opencv\n"
        return
    fi
    
    while true; do
        >&2 printf "\nPlease select your camera type:\n"
        >&2 printf "1) OpenCV (for standard webcams)\n"
        >&2 printf "2) PiCamera (for Raspberry Pi camera module)\n"
        >&2 printf "Enter your choice (1 or 2): "
        read -r choice
        
        case $choice in
            1)
                printf "opencv\n"
                return
                ;;
            2)
                printf "picamera\n"
                return
                ;;
            *)
                >&2 printf "Invalid choice. Please select 1 or 2.\n"
                ;;
        esac
    done
}

# Get camera type and capture it properly
if [ -z "$CAMERA_TYPE" ]; then
    CAMERA_TYPE="$(select_camera_type)"
fi
[ "$VERBOSE" -eq 1 ] && echo "Using camera type: $CAMERA_TYPE"

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

# Create startup script for OpenCV
[ "$VERBOSE" -eq 1 ] && echo "📝 Creating OpenCV startup script..."
cat > "$INSTALL_DIR/start_opencv_server.sh" << 'EOL'
#!/bin/bash
cd "$(dirname "$0")"

# Load environment variables if they exist
if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile"
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
    uv pip install -r requirements-opencv.txt
fi

# Get current IP for logging
IP_ADDRESS=$(hostname -I | awk '{print $1}')
LOG_FILE="$HOME/camera_server.log"

# Rotate log if it's getting large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# Start the server
echo "$(date) - Starting OpenCV camera server on $IP_ADDRESS" >> "$LOG_FILE"
python main.py --camera opencv >> "$LOG_FILE" 2>&1
EOL

# Create startup script for PiCamera
[ "$VERBOSE" -eq 1 ] && echo "📝 Creating PiCamera startup script..."
cat > "$INSTALL_DIR/start_picamera_server.sh" << 'EOL'
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
    uv pip install -r requirements-picamera.txt
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
EOL

# Make scripts executable
chmod +x "$INSTALL_DIR/start_opencv_server.sh"
chmod +x "$INSTALL_DIR/start_picamera_server.sh"

# Create symlink to the selected camera script
if [ "$CAMERA_TYPE" = "picamera" ]; then
    ln -sf "$INSTALL_DIR/start_picamera_server.sh" "$INSTALL_DIR/start_camera_server.sh"
else
    ln -sf "$INSTALL_DIR/start_opencv_server.sh" "$INSTALL_DIR/start_camera_server.sh"
fi

# Set up the virtual environment in the install directory
[ "$VERBOSE" -eq 1 ] && echo "🔧 Setting up virtual environment in installation directory..."
cd "$INSTALL_DIR"
if [ ! -d ".venv" ] || [ ! -f ".venv/bin/activate" ]; then
    [ "$VERBOSE" -eq 1 ] && echo "Creating virtual environment..."
    rm -rf .venv
    uv venv .venv
    source .venv/bin/activate
    if [ "$CAMERA_TYPE" = "picamera" ]; then
        uv pip install -r requirements-picamera.txt
    else
        uv pip install -r requirements-opencv.txt
    fi
else
    [ "$VERBOSE" -eq 1 ] && echo "Updating existing virtual environment..."
    source .venv/bin/activate
    if [ "$CAMERA_TYPE" = "picamera" ]; then
        uv pip install --upgrade -r requirements-picamera.txt
    else
        uv pip install --upgrade -r requirements-opencv.txt
    fi
fi

# Create or update cron job
[ "$VERBOSE" -eq 1 ] && echo "⏰ Setting up cron job for automatic startup..."
CRON_JOB="@reboot $INSTALL_DIR/start_camera_server.sh"

# Remove any existing cron jobs for this script
crontab -l 2>/dev/null | grep -v "start_camera_server.sh\|start_opencv_server.sh\|start_picamera_server.sh" | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Install system dependencies if using PiCamera
if [ "$CAMERA_TYPE" = "picamera" ]; then
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        [ "$VERBOSE" -eq 1 ] && echo "Installing PiCamera system dependencies..."
        sudo apt-get update
        sudo apt-get install -y \
            python3-picamera \
            python3-pip         
        # Set up camera permissions
        sudo usermod -a -G video $USER
    fi
fi

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
echo "$ $INSTALL_DIR/start_camera_server.sh"
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
