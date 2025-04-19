#!/bin/bash

# Exit on error
set -e

# Default values
CAMERA_TYPE=""
VERBOSE=1
NON_INTERACTIVE=0

# Parse command-line arguments
while getopts "c:vnh" opt; do
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
    h)
      echo "Usage: $0 [-c camera_type] [-v] [-n] [-h]"
      echo "  -c camera_type   Camera type: 'opencv' or 'picamera'"
      echo "  -v               Verbose mode"
      echo "  -n               Non-interactive mode"
      echo "  -h               Show this help"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Print banner
echo "===================================="
echo "Camera Server Setup and Run Script"
echo "===================================="

# Function to select camera type
select_camera_type() {
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CAMERA_TYPE" ]; then
        if [ "$CAMERA_TYPE" = "opencv" ] || [ "$CAMERA_TYPE" = "picamera" ]; then
            echo "$CAMERA_TYPE"
            return
        fi
    fi
    
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        echo "opencv"
        return
    fi
    
    while true; do
        >&2 echo ""
        >&2 echo "Please select your camera type:"
        >&2 echo "1) OpenCV (for standard webcams)"
        >&2 echo "2) PiCamera (for Raspberry Pi camera module)"
        >&2 printf "Enter your choice (1 or 2): "
        read choice
        
        case $choice in
            1)
                echo "opencv"
                return
                ;;
            2)
                echo "picamera"
                return
                ;;
            *)
                >&2 echo "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
}

# Get camera type and capture it properly
if [ -z "$CAMERA_TYPE" ]; then
    CAMERA_TYPE=$(select_camera_type)
fi
[ "$VERBOSE" -eq 1 ] && echo "Using camera type: $CAMERA_TYPE"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "⚠️ uv is not installed"
    echo "📦 Please install uv using one of the following methods:"
    echo "  - Using pip: pip install uv"
    echo "  - Using curl (recommended): curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  - For more options visit: https://github.com/astral-sh/uv"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    [ "$VERBOSE" -eq 1 ] && echo "🔧 Creating virtual environment..."
    uv venv  .venv
else
    [ "$VERBOSE" -eq 1 ] && echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
[ "$VERBOSE" -eq 1 ] && echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Install dependencies based on camera type
[ "$VERBOSE" -eq 1 ] && echo "📦 Installing dependencies for camera type: $CAMERA_TYPE..."
if [ "$CAMERA_TYPE" = "picamera" ]; then
    # Install system dependencies for PiCamera if on Raspberry Pi
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        [ "$VERBOSE" -eq 1 ] && echo "Installing PiCamera system dependencies..."
        # sudo apt-get update
        # sudo apt-get install -y \
        #     python3-picamera \
        #     python3-pip \
        #     python3-numpy  \
        #     python3-zeroconf
        sudo apt install python3-picamera2

        # Set up camera permissions
        sudo usermod -a -G video $USER
    fi
    
    [ "$VERBOSE" -eq 1 ] && echo "Installing Python dependencies for PiCamera..."
    uv pip install --upgrade -r requirements-picamera.txt --extra-index-url https://www.piwheels.org/simple --index-strategy unsafe-best-match
else
    [ "$VERBOSE" -eq 1 ] && echo "Installing Python dependencies for OpenCV..."
    uv pip install --upgrade -r requirements-opencv.txt
fi

echo "===================================="
echo "✅ Setup complete!"
echo "===================================="

# Start the server
[ "$VERBOSE" -eq 1 ] && echo "🚀 Starting camera server..."
if [ "$CAMERA_TYPE" = "picamera" ]; then
    python main.py --camera picamera
else
    python main.py --camera opencv
fi
