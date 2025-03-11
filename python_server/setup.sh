#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Camera Provider Python Server Setup"
echo "===================================="

# Check if python-venv is installed
if ! python3 -c "import venv" &> /dev/null; then
    echo "📦 Installing python3-venv..."
    # Check if we're on a Debian-based system (like Raspberry Pi OS, Ubuntu)
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3-venv
    # Check if we're on a Red Hat-based system (like Fedora, CentOS)
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3-venv
    # Check if we're on a macOS system
    elif command -v brew &> /dev/null; then
        echo "Python venv module should be included with Python on macOS."
        echo "If you're seeing this error, consider reinstalling Python."
    else
        echo "⚠️ Could not detect package manager. Please install python3-venv manually."
        exit 1
    fi
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv .venv
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Install or update dependencies
echo "📦 Installing/updating dependencies..."
pip install --upgrade pip
pip install --upgrade -r requirements.txt

# Check for any outdated packages and inform the user
echo "🔍 Checking for outdated packages..."
pip list --outdated

echo "===================================="
echo "✅ Setup complete!"
echo "===================================="

# Ask if user wants to run the server now
read -p "Do you want to start the camera server now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting camera server..."
    python main.py
else
    echo "To start the server later, run:"
    echo "$ source .venv/bin/activate"
    echo "$ python main.py"
fi