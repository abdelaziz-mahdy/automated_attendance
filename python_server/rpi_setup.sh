#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Raspberry Pi Camera Server Setup"
echo "===================================="

# Get current directory (should be inside python_server in the cloned repo)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Check if running on Raspberry Pi
if [ ! -f "/proc/device-tree/model" ] || ! grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    echo "Warning: This script is intended for Raspberry Pi. Continuing anyway..."
fi

# Check if python-venv is installed
if ! python3 -c "import venv" &> /dev/null; then
    echo "📦 Installing python3-venv..."
    sudo apt-get update
    sudo apt-get install -y python3-venv
fi

# Check if picamera is already installed
if python3 -c "import picamera" &> /dev/null; then
    echo "✅ picamera module already installed"
else
    echo "📦 Installing picamera dependencies..."
    sudo apt-get update
    sudo apt-get install -y python3-picamera python3-pip libatlas-base-dev
fi

# Check if this is an update and verify venv integrity
UPDATE_MODE=0
if [ -d "$SCRIPT_DIR/.venv" ]; then
    if [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
        UPDATE_MODE=1
        echo "📥 Update mode detected - will upgrade existing installation"
    else
        echo "⚠️ Virtual environment detected but appears corrupted"
        echo "🔧 Removing broken virtual environment and creating a new one"
        rm -rf "$SCRIPT_DIR/.venv"
    fi
fi

if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "🔧 Creating virtual environment..."
    cd "$SCRIPT_DIR"
    python3 -m venv .venv
    if [ ! -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
        echo "❌ Failed to create virtual environment. Something went wrong."
        exit 1
    fi
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
if [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
else
    echo "❌ Virtual environment activation script not found"
    echo "🔧 Recreating virtual environment..."
    rm -rf "$SCRIPT_DIR/.venv"
    python3 -m venv "$SCRIPT_DIR/.venv"
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

# Install/update dependencies
echo "📦 Installing/updating Python dependencies..."
pip install --upgrade pip
pip install --upgrade -r "$SCRIPT_DIR/requirements.txt"

# Make sure permissions are set for the camera
echo "🔒 Setting up camera permissions..."
sudo usermod -a -G video $USER

# Print IP address for connection info
echo "🌐 Network Information:"
hostname -I

if [ "$UPDATE_MODE" -eq 1 ]; then
    echo "===================================="
    echo "✅ Update complete!"
else
    echo "===================================="
    echo "✅ Setup complete!"
fi

echo "===================================="
echo "To run the camera server:"
echo "$ cd $SCRIPT_DIR"
echo "$ source .venv/bin/activate"
echo "$ python main.py --camera picamera"
echo "===================================="

# Ask if user wants to run the server now
read -p "Do you want to start the camera server now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting camera server..."
    cd "$SCRIPT_DIR"
    python main.py --camera picamera
fi