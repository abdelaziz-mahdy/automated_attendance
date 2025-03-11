#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "macOS Update Script"
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

# Run Flutter pub get to update dependencies
echo "📦 Updating Flutter dependencies..."
flutter pub get

# Check if the python_server directory exists
if [ -d "python_server" ]; then
    echo "📦 Updating Python server dependencies..."
    cd python_server
    
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
    
    cd ..
fi

echo "===================================="
echo "✅ Update complete!"
echo "===================================="