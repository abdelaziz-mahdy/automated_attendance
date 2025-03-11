#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Camera Provider Python Server Setup"
echo "===================================="

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

# Install or update dependencies
echo "📦 Installing/updating dependencies..."
uv pip install --upgrade -r requirements.txt

# Check for any outdated packages and inform the user
echo "🔍 Checking for outdated packages..."
uv pip list --outdated

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