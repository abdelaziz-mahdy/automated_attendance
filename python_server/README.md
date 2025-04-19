# Python Camera Server

A comprehensive and intelligent camera monitoring system with real-time face detection, recognition, and attendance tracking capabilities.

## Features

- **Live Camera Streaming**: Watch real-time camera feeds through your web browser
- **Multiple Stream Modes**: Switch between regular, face detection, and face recognition modes
- **Face Detection**: Automatically detect and highlight faces in the camera stream
- **Face Recognition**: Identify known individuals and track their presence over time
- **Attendance Tracking**: Monitor and record attendance with detailed statistics
- **Batch Face Import**: Import faces from directory structures for efficient training
- **Face Management**: Rename, merge, and organize detected faces
- **Cross-Platform**: Works on Windows, macOS, Linux, and Raspberry Pi

## Installation

### Requirements

- Python 3.7 or higher
- Camera hardware (webcam, IP camera, or Raspberry Pi Camera Module)
- Web browser with JavaScript enabled
- 2GB+ RAM recommended for optimal performance

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/abdelaziz-mahdy/cameras_viewer.git
   cd cameras_viewer/python_server
   ```

2. **Install dependencies**:
   ```bash
   # For standard systems with webcams
   pip install -r requirements-opencv.txt
   
   # For Raspberry Pi Camera
   pip install -r requirements-picamera.txt
   ```

3. **Run the server**:
   ```bash
   python main.py
   ```

4. **Access the web interface**:
   Open your browser and navigate to `http://localhost:12345`

## Usage Guide

### Live Stream Tab
- Select between three stream types:
  - **Regular Stream**: Basic camera feed without processing
  - **Face Detection**: Highlights faces in the camera feed
  - **Face Recognition**: Identifies and labels known faces

### Detected Faces Tab
- View and manage all detected faces
- Rename unnamed faces by clicking the edit button
- Merge similar faces using "Drag to Merge" mode
- Import face data in batch from directories
- View multiple thumbnails for each detected person

### Attendance Tab
- View real-time attendance statistics
- Monitor early, on-time, and late arrivals
- Configure expected arrival times and thresholds
- Track attendance rates and trends

## Face Import Functionality

The face import feature allows you to quickly add multiple people to the recognition system using existing photos.

### Directory Structure

The import functionality expects a specific directory structure:

