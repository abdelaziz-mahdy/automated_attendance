#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Raspberry Pi Camera Server Setup"
echo "===================================="

# Check if running on Raspberry Pi
if [ ! -f "/proc/device-tree/model" ] || ! grep -q "Raspberry Pi" "/proc/device-tree/model"; then
    echo "Warning: This script is intended for Raspberry Pi. Continuing anyway..."
fi

# Check if picamera is already installed
if python3 -c "import picamera" &> /dev/null; then
    echo "✅ picamera module already installed"
else
    echo "📦 Installing picamera dependencies..."
    sudo apt-get update
    sudo apt-get install -y python3-picamera python3-pip libatlas-base-dev
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv .venv
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Make sure permissions are set for the camera
echo "🔒 Setting up camera permissions..."
sudo usermod -a -G video $USER

# Print IP address for connection info
echo "🌐 Network Information:"
hostname -I

echo "===================================="
echo "✅ Setup complete!"
echo "===================================="
echo "To run the camera server:"
echo "$ python main.py --camera picamera"
echo "===================================="

# Ask if user wants to run the server now
read -p "Do you want to start the camera server now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting camera server..."
    python main.py --camera picamera
fi