#!/bin/bash

# Exit on error
set -e

# Default values
VERBOSE=1
NON_INTERACTIVE=0

# Parse command-line arguments
while getopts "vnh" opt; do
  case $opt in
    v)
      VERBOSE=1
      ;;
    n)
      NON_INTERACTIVE=1
      ;;
    h)
      echo "Usage: $0 [-v] [-n] [-h]"
      echo "  -v               Verbose mode"
      echo "  -n               Non-interactive mode (doesn't prompt for confirmation)"
      echo "  -h               Show this help"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

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

# Check for uncommitted changes
if [ "$VERBOSE" -eq 1 ]; then
    git status
fi

# if [ "$NON_INTERACTIVE" -eq 0 ]; then
#     read -p "Do you want to proceed with the update? [Y/n] " -n 1 -r
#     echo
#     if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY = "" ]]; then
#         echo "Update canceled."
#         exit 0
#     fi
# fi

# Stash any local changes
[ "$VERBOSE" -eq 1 ] && echo "🔧 Saving any local changes..."
git stash -q || true

# Get the current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$VERBOSE" -eq 1 ] && echo "🔍 Current branch: $BRANCH"

# Pull the latest changes
[ "$VERBOSE" -eq 1 ] && echo "📥 Pulling latest changes..."
git pull origin $BRANCH

echo "✅ Repository updated successfully"
echo "===================================="
echo "To setup and run the server, use:"
echo "$ bash setup_and_run.sh"

# Pop stashed changes if there were any
if git stash list | grep -q "stash@{0}"; then
    [ "$VERBOSE" -eq 1 ] && echo "Restoring local changes..."
    git stash pop -q
    [ "$VERBOSE" -eq 1 ] && echo "Local changes restored."
fi