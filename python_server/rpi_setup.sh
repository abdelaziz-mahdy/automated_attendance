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

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "⚠️ uv is not installed"
    echo "📦 Installing uv..."
    
    # Check if pip is installed
    if command -v pip3 &> /dev/null; then
        pip3 install uv
    else
        # First install pip if needed
        echo "📦 Installing pip first..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
        pip3 install uv
    fi
    
    # If installation failed, provide manual instructions
    if ! command -v uv &> /dev/null; then
        echo "❌ Failed to install uv automatically."
        echo "Please install uv manually using one of these methods:"
        echo "  - Using pip: pip install uv"
        echo "  - Using curl: curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "  - For more options visit: https://github.com/astral-sh/uv"
        exit 1
    fi
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
    uv venv .venv
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
    uv venv "$SCRIPT_DIR/.venv"
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

# Install/update dependencies
echo "📦 Installing/updating Python dependencies..."
uv pip install --upgrade -r "$SCRIPT_DIR/requirements.txt"

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