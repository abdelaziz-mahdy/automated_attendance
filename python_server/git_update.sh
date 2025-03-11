#!/bin/bash

# Exit on error
set -e

echo "===================================="
echo "Camera Server Git Update Script"
echo "===================================="

# Get current directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
cd "$SCRIPT_DIR"

# Check if we're in a git repository
if [ ! -d "../.git" ] && [ ! -d "../../.git" ]; then
    echo "⚠️ Not in a git repository. Please clone the repository first:"
    echo "git clone https://github.com/abdelaziz-mahdy/automated_attendance.git"
    exit 1
fi

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
echo "===================================="
echo "To setup and run the server, use:"
echo "$ bash setup_and_run.sh"