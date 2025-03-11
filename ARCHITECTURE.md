# Automated Attendance System: Architecture & Design

## System Overview

The Automated Attendance System works in two main modes:

- **Camera Provider Mode:**  
  Your device's camera captures video frames. The app processes these frames (using face detection techniques) and then broadcasts your camera service over your local network. Other devices (Data Centers) can discover your device and request a snapshot (JPEG image) when needed.

- **Data Center Mode:**  
  This mode automatically discovers available Camera Providers on your network. It polls these providers to get the latest image frames, processes them to detect faces, and then displays recognized faces and attendance logs.

**Alternate Option:**  
If you prefer a simpler setup, you can run a dedicated Python server as your Camera Provider. This server exposes the same `/get_image` HTTP endpoint to serve camera images without the full application interface.

All communication between devices is done over your local network via simple HTTP requests.

## How It Works (Detailed)

### 1. Camera Provider Mode

- **Capture & Process:** The app accesses your device's camera, captures frames, and processes them into JPEG images.
- **Broadcasting:** It then "announces" itself on the network using Zeroconf/mDNS so that other devices can find it.
- **Serve Frames:** When a Data Center sends an HTTP request (to `/get_image`), your device sends back the latest image frame.
- **Different Implementations:**
  - **Flutter App**: Uses camera plugins for mobile devices
  - **Desktop**: Uses OpenCV for camera access
  - **Raspberry Pi**: Uses the picamera library for the Pi Camera Module

### 2. Data Center Mode

- **Discovery:** The system uses a discovery service to find all available Camera Providers.
- **Poll & Process:** It periodically sends an HTTP request to each provider's `/get_image` endpoint. When a frame is received, it is processed (using isolates if enabled) to detect faces.
- **Face Detection & Recognition:**
  - Detects faces in each frame
  - Extracts face features
  - Compares with known faces
  - Tracks faces over time
- **Attendance Tracking:** Recognized faces are logged with timestamps for attendance records.

### 3. Python Server Option

- **Lightweight Provider:** If you prefer not to run the full Camera Provider interface, you can run a dedicated Python server. This server serves JPEG images via the `/get_image` endpoint.
- **Same Endpoint:** The Data Center interacts with the Python server exactly as it does with the full Camera Provider—no additional configuration is needed.
- **Platform Support:** Works on standard computers (using OpenCV) and Raspberry Pi (using picamera)

## System Architecture Diagram

Below is a simplified diagram that illustrates the overall communication:

```mermaid
graph LR
    A[Camera Provider Device / Python Server]
    B[Network Discovery Service]
    C[Data Center Device]
    D[Face Processing & Attendance Tracking]

    A -- "Broadcasts service" --> B
    B -- "Discovered by" --> C
    C -- "HTTP Request (/get_image)" --> A
    A -- "Sends JPEG Frame" --> C
    C -- "Processes frame for faces" --> D
```

## Component Breakdown

### Camera Provider Components
- Camera access layer (platform-specific)
- HTTP server for image serving
- Service discovery broadcaster
- Frame processing utilities

### Data Center Components
- Service discovery listener
- Frame polling manager
- Face detection and recognition engine
- Attendance tracking database
- User interface for displaying results

## Technical Implementation

### Face Recognition Process
1. Face Detection: Using YuNet neural network model
2. Feature Extraction: Using SFace model to create face embeddings
3. Feature Comparison: Computing distance between face embeddings
4. Identity Assignment: Matching with known faces or creating a new identity

### Performance Optimizations
- Optional use of isolates for parallel processing
- Dynamic frame rate adjustment based on system load
- Efficient memory management for face thumbnails