#!/bin/bash

# Exit on error
set -e

# Default values
CAMERA_TYPE="auto"
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
      echo "  -c camera_type   Camera type: 'auto', 'opencv', 'picamera', or 'picamera2'"
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

# Function to auto-detect best available camera
detect_camera_type() {
  # Check for Raspberry Pi
  if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    # Try PiCamera2 first
    if python3 -c "import picamera2" &> /dev/null || dpkg -l | grep -q python3-picamera2; then
      echo "picamera2"
      return
    fi
    
    # Then try PiCamera
    if python3 -c "import picamera" &> /dev/null || dpkg -l | grep -q python3-picamera; then
      echo "picamera"
      return
    fi
  fi
  
  # Fall back to OpenCV
  echo "opencv"
}

# Function to select camera type
select_camera_type() {
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CAMERA_TYPE" ]; then
        if [ "$CAMERA_TYPE" = "opencv" ] || [ "$CAMERA_TYPE" = "picamera" ] || [ "$CAMERA_TYPE" = "picamera2" ] || [ "$CAMERA_TYPE" = "auto" ]; then
            echo "$CAMERA_TYPE"
            return
        fi
    fi
    
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        echo "auto"
        return
    fi
    
    while true; do
        >&2 echo ""
        >&2 echo "Please select your camera type:"
        >&2 echo "1) Auto (automatically detect best camera)"
        >&2 echo "2) OpenCV (for standard webcams)"
        >&2 echo "3) PiCamera2 (for Raspberry Pi camera module - newer API)"
        >&2 echo "4) PiCamera (for Raspberry Pi camera module - legacy API)"
        >&2 printf "Enter your choice (1-4): "
        read choice
        
        case $choice in
            1)
                echo "auto"
                return
                ;;
            2)
                echo "opencv"
                return
                ;;
            3)
                echo "picamera2"
                return
                ;;
            4)
                echo "picamera"
                return
                ;;
            *)
                >&2 echo "Invalid choice. Please select 1, 2, 3, or 4."
                ;;
        esac
    done
}

# Get camera type and capture it properly
if [ -z "$CAMERA_TYPE" ] || [ "$CAMERA_TYPE" = "auto" ]; then
    # Ask for camera type if not in non-interactive mode
    if [ "$NON_INTERACTIVE" -eq 0 ]; then
        CAMERA_TYPE=$(select_camera_type)
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

# Check if uv is installed
if command -v uv &> /dev/null; then
    [ "$VERBOSE" -eq 1 ] && echo "✅ Using uv package manager"
    PIP_CMD="uv pip"
else
    [ "$VERBOSE" -eq 1 ] && echo "⚙️ Using standard pip (uv not found)"
    # Try to find pip in different forms
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
    else
        PIP_CMD="pip"
    fi
    [ "$VERBOSE" -eq 1 ] && echo "Using $PIP_CMD for package installation"
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    [ "$VERBOSE" -eq 1 ] && echo "🔧 Creating virtual environment..."
    
    # For PiCamera2, use system-site-packages to access system-installed picamera2
    if [ "$CAMERA_TYPE" = "picamera2" ] || [ "$CAMERA_TYPE" = "picamera" ]; then
        [ "$VERBOSE" -eq 1 ] && echo "Using system-site-packages for camera libraries..."
        python3 -m venv --system-site-packages .venv
    else
        # For OpenCV, create a standard virtual environment
        if command -v uv &> /dev/null; then
            uv venv .venv
        else
            python3 -m venv .venv
        fi
    fi
else
    [ "$VERBOSE" -eq 1 ] && echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
[ "$VERBOSE" -eq 1 ] && echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Install dependencies based on camera type
[ "$VERBOSE" -eq 1 ] && echo "📦 Installing dependencies for camera type: $CAMERA_TYPE..."
if [ "$CAMERA_TYPE" = "picamera" ] || [ "$CAMERA_TYPE" = "picamera2" ]; then
    # Install system dependencies for PiCamera if on Raspberry Pi
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
    
    [ "$VERBOSE" -eq 1 ] && echo "Installing Python dependencies for $CAMERA_TYPE..."
    $PIP_CMD install --upgrade -r requirements-picamera.txt || {
        [ "$VERBOSE" -eq 1 ] && echo "⚠️ Failed with $PIP_CMD, trying with pip directly..."
        pip install --upgrade -r requirements-picamera.txt
    }
else
    [ "$VERBOSE" -eq 1 ] && echo "Installing Python dependencies for OpenCV..."
    $PIP_CMD install --upgrade -r requirements-opencv.txt || {
        [ "$VERBOSE" -eq 1 ] && echo "⚠️ Failed with $PIP_CMD, trying with pip directly..."
        pip install --upgrade -r requirements-opencv.txt
    }
fi

echo "===================================="
echo "✅ Setup complete!"
echo "===================================="

# Start the server
[ "$VERBOSE" -eq 1 ] && echo "🚀 Starting camera server..."
python main.py --camera $CAMERA_TYPE
