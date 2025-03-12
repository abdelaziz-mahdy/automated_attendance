#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Camera Server Setup and Run Script"
echo "===================================="

# Function to select camera type
select_camera_type() {
    echo "Please select your camera type:"
    echo "1) OpenCV (for standard webcams)"
    echo "2) PiCamera (for Raspberry Pi camera module)"
    echo -n "Enter your choice (1 or 2): "
    read choice
    
    case $choice in
        1)
            echo "opencv"
            ;;
        2)
            echo "picamera"
            ;;
        *)
            echo "Invalid choice. Please select 1 or 2."
            exit 1
            ;;
    esac
}

# Get camera type
CAMERA_TYPE=$(select_camera_type)
echo "Using camera type: $CAMERA_TYPE"

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
    echo "🔧 Creating virtual environment..."
    uv venv .venv
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Install dependencies based on camera type
echo "📦 Installing dependencies for camera type: $CAMERA_TYPE..."
if [ "$CAMERA_TYPE" = "picamera" ]; then
    # Install system dependencies for PiCamera if on Raspberry Pi
    if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry Pi" "/proc/device-tree/model"; then
        echo "Installing PiCamera system dependencies..."
        sudo apt-get update
        sudo apt-get install -y \
            python3-picamera \
            python3-pip \
            libatlas-base-dev
        
        # Set up camera permissions
        sudo usermod -a -G video $USER
    fi
    
    echo "Installing Python dependencies for PiCamera..."
    uv pip install --upgrade -r requirements-picamera.txt
else
    echo "Installing Python dependencies for OpenCV..."
    uv pip install --upgrade -r requirements-opencv.txt
fi

echo "===================================="
echo "✅ Setup complete!"
echo "===================================="

# Start the server
echo "🚀 Starting camera server..."
if [ "$CAMERA_TYPE" = "picamera" ]; then
    python main.py --camera picamera
else
    python main.py --camera opencv
fi