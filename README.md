# Automated Attendance System

A real-time face recognition system that uses networked cameras for automated attendance tracking.

## Quick Start

### For the Flutter App

1. **Prerequisites:**
   - [Flutter](https://flutter.dev/docs/get-started/install) installed on your system
   - A connected device or emulator

2. **Installation:**
   ```bash
   git clone https://github.com/abdelaziz-mahdy/automated_attendance.git
   cd automated_attendance
   flutter pub get
   flutter run
   ```

### For the Python Server

1. **Prerequisites:**
   - Python 3 installed on your system
   - uv package manager (install using: `curl -LsSf https://astral.sh/uv/install.sh | sh`)
   - For Raspberry Pi: A connected camera module
   - For other systems: A connected webcam

2. **Available Scripts:**

   The Python server comes with three specialized scripts:

   a) **Git Update Script** (`git_update.sh`):
   - Updates the repository with the latest changes
   - Maintains your local modifications
   - Use this when you want to update to the latest version
   ```bash
   cd python_server
   bash git_update.sh
   ```

   b) **Setup and Run Script** (`setup_and_run.sh`):
   - Interactive camera type selection
   - Installs all required dependencies
   - Sets up the Python environment
   - Starts the camera server
   ```bash
   cd python_server
   bash setup_and_run.sh
   ```

   c) **Cron Setup Script** (`cron_setup.sh`):
   - Interactive camera type selection
   - Configures automatic startup on boot
   - Sets up system service
   - Manages log rotation
   ```bash
   cd python_server
   bash cron_setup.sh
   ```

3. **Camera Types:**
   When running setup scripts, you'll be prompted to choose your camera type:
   - **OpenCV** (Option 1): For standard webcams on any system
   - **PiCamera** (Option 2): Specifically for Raspberry Pi camera module

4. **First-Time Setup:**
   ```bash
   # Clone the repository
   git clone https://github.com/abdelaziz-mahdy/automated_attendance.git
   cd automated_attendance/python_server
   
   # Run the setup script
   bash setup_and_run.sh
   ```

5. **Automatic Startup Setup (Optional):**
   ```bash
   cd automated_attendance/python_server
   bash cron_setup.sh
   ```

6. **Updating the System:**
   ```bash
   cd automated_attendance/python_server
   # First update the repository
   bash git_update.sh
   # Then run setup again
   bash setup_and_run.sh
   ```

### Server Locations and Logs

- **Installation Directory:** `$HOME/camera_server`
- **Log File:** `$HOME/camera_server.log`
- **Default Port:** 12345
- **Web Interface:** `http://<your-ip>:12345`

### Troubleshooting

1. **Camera Issues:**
   - For PiCamera: Ensure the camera module is enabled in raspi-config
   - For OpenCV: Check if your webcam is recognized by the system

2. **Startup Issues:**
   - Check the logs: `cat $HOME/camera_server.log`
   - Verify camera permissions
   - Ensure the selected camera type matches your hardware

3. **Network Issues:**
   - Confirm the server is running: `http://localhost:12345/test`
   - Check firewall settings
   - Ensure all devices are on the same network

## System Architecture

For detailed information about how the system works, see [ARCHITECTURE.md](ARCHITECTURE.md).

## License

[LICENSE](LICENSE)

