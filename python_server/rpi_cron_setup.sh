#!/bin/bash
# Script to set up automatic startup for camera server on Raspberry Pi

# Exit on error
set -e

# Get current directory (should be inside python_server in the cloned repo)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
INSTALL_DIR="$HOME/automated_attendance_server"

echo "===================================="
echo "Raspberry Pi Camera Server - Cron Setup"
echo "===================================="

# Check if this is an update
UPDATE_MODE=0
if [ -d "$INSTALL_DIR" ]; then
    UPDATE_MODE=1
    echo "📥 Update mode detected - will upgrade existing installation"
fi

# Check if python-venv is installed
if ! python3 -c "import venv" &> /dev/null; then
    echo "📦 Installing python3-venv..."
    sudo apt-get update
    sudo apt-get install -y python3-venv
fi

# First ensure the camera setup is done
if [ -f "$SCRIPT_DIR/rpi_setup.sh" ]; then
    echo "📋 Running camera setup script first..."
    bash "$SCRIPT_DIR/rpi_setup.sh"
else
    echo "⚠️ Warning: rpi_setup.sh not found in current directory."
    echo "Please run rpi_setup.sh first to ensure dependencies are installed."
    exit 1
fi

# Create install directory if it doesn't exist
echo "📁 Setting up installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy necessary files to installation directory
echo "📋 Copying server files..."
cp "$SCRIPT_DIR/main.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/server.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/camera_provider.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"

# Create or update startup script
echo "📝 Creating startup script..."
cat > "$INSTALL_DIR/start_camera_server.sh" << 'EOL'
#!/bin/bash
cd "$(dirname "$0")"

# Activate virtual environment if it exists
if [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
else
  echo "Virtual environment missing or corrupted. Recreating..."
  rm -rf .venv
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
fi

# Get current IP for logging
IP_ADDRESS=$(hostname -I | awk '{print $1}')
LOG_FILE="$HOME/camera_server.log"

# Rotate log if it's getting large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
  mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# Start the server
echo "$(date) - Starting camera server on $IP_ADDRESS" >> "$LOG_FILE"
python main.py --camera picamera >> "$LOG_FILE" 2>&1
EOL

chmod +x "$INSTALL_DIR/start_camera_server.sh"

# Set up the virtual environment in the install directory
echo "🔧 Setting up virtual environment in installation directory..."
cd "$INSTALL_DIR"
if [ ! -d ".venv" ] || [ ! -f ".venv/bin/activate" ]; then
    echo "Creating virtual environment..."
    rm -rf .venv
    python3 -m venv .venv
    if [ ! -f ".venv/bin/activate" ]; then
        echo "❌ Failed to create virtual environment. Something went wrong."
        exit 1
    fi
    source .venv/bin/activate
    pip install -r requirements.txt
else
    echo "Updating existing virtual environment..."
    source .venv/bin/activate
    pip install --upgrade -r requirements.txt
fi

# Create or update cron job
echo "⏰ Setting up cron job for automatic startup..."
CRON_JOB="@reboot $INSTALL_DIR/start_camera_server.sh"

# Remove any existing cron jobs for this script
crontab -l 2>/dev/null | grep -v "start_camera_server.sh" | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Status message
if [ "$UPDATE_MODE" -eq 1 ]; then
    echo "===================================="
    echo "✅ Update complete!"
else
    echo "===================================="
    echo "✅ Cron setup complete!"
fi

echo "===================================="
echo "The camera server will now automatically start on boot."
echo "You can check the server logs at: $HOME/camera_server.log"
echo "To manually start the server, run:"
echo "$ $INSTALL_DIR/start_camera_server.sh"
echo "===================================="

# Print IP address for reference
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "🌐 Your Raspberry Pi IP address: $IP_ADDRESS"
echo "Camera server will be accessible at: http://$IP_ADDRESS:12345"

read -p "Do you want to reboot now to test automatic startup? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Rebooting system..."
    sudo reboot
else
    echo "Remember to reboot later to enable automatic startup."
fi