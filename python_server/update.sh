#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Camera Provider Python Server Update"
echo "===================================="

# Get current directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
cd "$SCRIPT_DIR"

# Check if we're in a git repository
if [ -d "../.git" ] || [ -d "../../.git" ]; then
    echo "📥 Updating repository from git..."
    
    # Stash any local changes
    echo "🔧 Saving any local changes..."
    git stash -q || true
    
    # Get the current branch name
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "🔍 Current branch: $BRANCH"
    
    # Pull the latest changes
    echo "📥 Pulling latest changes..."
    git pull origin $BRANCH
    
    echo "✅ Repository updated successfully"
else
    echo "⚠️ Not in a git repository. Skipping repository update."
    echo "If you want to update, please clone the repository again:"
    echo "git clone https://github.com/abdelaziz-mahdy/automated_attendance.git"
fi

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "⚠️ uv is not installed"
    echo "📦 Please install uv using one of the following methods:"
    echo "  - Using pip: pip install uv"
    echo "  - Using curl (recommended): curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  - For more options visit: https://github.com/astral-sh/uv"
    exit 1
fi

# Run the setup script to handle dependency updates
echo "🔄 Updating dependencies..."
bash "$SCRIPT_DIR/setup.sh"

echo "===================================="
echo "✅ Update complete!"
echo "===================================="