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

### For the Python Server (Standard)

1. **Prerequisites:**
   - Python 3 installed on your system
   - uv package manager (install using: `curl -LsSf https://astral.sh/uv/install.sh | sh`)

2. **Installation:**
   ```bash
   git clone https://github.com/abdelaziz-mahdy/automated_attendance.git
   cd automated_attendance/python_server
   
   # For systems with standard webcams (using OpenCV)
   bash setup.sh --camera opencv
   
   # For Raspberry Pi with PiCamera
   bash setup.sh --camera picamera
   ```

### For Raspberry Pi (Including Raspberry Pi Zero)

1. **Prerequisites:**
   - A Raspberry Pi with camera module connected
   - Raspbian/Raspberry Pi OS installed
   - Internet connection for installing dependencies

2. **Installation Options:**

   **Option 1: Simple Installation**
   ```bash
   # Clone the repository
   git clone https://github.com/abdelaziz-mahdy/automated_attendance.git
   cd automated_attendance/python_server
   
   # Run the setup script (automatically uses PiCamera)
   bash rpi_setup.sh
   ```
   This script will automatically:
   - Install required system dependencies
   - Set up PiCamera without unnecessary OpenCV dependencies
   - Configure camera permissions
   - Create a Python virtual environment using uv

   **Option 2: Auto-start on Boot**
   ```bash
   # Clone the repository
   git clone https://github.com/abdelaziz-mahdy/automated_attendance.git
   cd automated_attendance/python_server
   
   # Run the cron setup script
   bash rpi_cron_setup.sh
   ```
   This option includes everything from Option 1 plus sets up the server to start automatically on boot.

### Updating the System

To update your installation with the latest changes:

```bash
cd automated_attendance/python_server

# For systems with standard webcams (using OpenCV)
bash update.sh --camera opencv

# For Raspberry Pi with PiCamera
bash update.sh --camera picamera
```

## Usage Guide

### App Modes

- **Camera Provider Mode**: Broadcasts your device camera over the network
- **Data Center Mode**: Receives camera feeds and processes faces for attendance tracking

### Basic Usage Steps

1. **Start at least one device as a Camera Provider** (or use the Python server)
2. **Start another device as a Data Center**
3. The Data Center will automatically discover and connect to the Camera Provider
4. View real-time face recognition and attendance tracking in the Data Center interface

For detailed instructions, see the [User Guide](#user-guide) section below.

## System Architecture

For detailed information about how the system works, see [ARCHITECTURE.md](ARCHITECTURE.md).

## User Guide

### Using Camera Provider Mode

- **Permissions:** Allow camera access when prompted
- **Broadcasting:** Your device automatically announces itself on the local network
- **Status:** The app displays the server status and logging information

### Using Data Center Mode

- **Discovery:** The app automatically finds Camera Providers on your network
- **Live Feed:** Shows camera feeds with face detection overlays
- **People Tab:** Shows recognized individuals and allows name assignment
- **Settings:** Configure processing options like face memory and isolate usage

### Troubleshooting

- **No Camera Feed?** Check camera permissions and network connectivity
- **Discovery Issues?** Ensure devices are on the same network
- **Performance Problems?** Try enabling isolates in Settings

## License

[LICENSE](LICENSE)

