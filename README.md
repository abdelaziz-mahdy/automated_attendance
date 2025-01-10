

## 1. System Purpose

The primary goal of this system is to capture camera feeds (either from a local camera or a remote provider), detect faces in real-time, extract embeddings (features) from those faces using OpenCV’s face-recognition models, and optionally use those embeddings to:

- **Identify or verify** specific individuals.
- **Log** when someone arrives or leaves a location.
- **Track** a person’s presence in the building if multiple cameras are set up across entrances, hallways, and exits.

In practical terms, this means:

1. **Entrances** can have one or more cameras to detect and timestamp arrivals.  
2. **Exits** can have cameras to detect and timestamp departures.  
3. **Hallways** or other strategic points can have cameras to keep track of movement if desired.

The architecture has been designed in a modular way to make it easy to integrate new features (like a central database or a user-facing dashboard) without overhauling the entire system.

---

## 2. High-Level Architecture

```mermaid
flowchart LR
    A[Local Camera Provider] --(frames)--> B[CameraProviderServer / HTTP Server]
    B --(Advertise)--> C[BroadcastService]

    subgraph "Local Network"
    C -.udp-broadcast.-> D[DiscoveryService (Data Center)]
    end
    
    D --(HTTP GET /get_image)--> B
    B --(JPEG frames)--> D
    D --> E[FaceProcessingService]
    E --> D[DataCenter View/UI]
```

1. **Local Camera Provider** (Device A) captures frames using OpenCV.  
2. **CameraProviderServer** hosts an HTTP endpoint (`/get_image`) to serve those frames.  
3. **BroadcastService** announces the camera’s presence across the network.  
4. **Data Center** (Device B) runs **DiscoveryService** to find broadcasted cameras automatically.  
5. **RemoteCameraProvider** on the Data Center connects to each discovered camera via HTTP.  
6. **FaceProcessingService** detects faces on the Data Center side, extracts features, and can record or display recognized faces.

---

## 3. Key Components

### 3.1 Camera Providers

1. **`ICameraProvider`**  
   - An interface with common camera operations:  
     - `openCamera()`, `closeCamera()`, `getFrame()`, and `isOpen` (a boolean).
   - This abstraction allows the rest of the system to remain agnostic to whether the camera is local or remote.

2. **`LocalCameraProvider`**  
   - Manages a physical camera (via OpenCV) on the current device.  
   - Uses `VideoCapture.fromDevice(cameraIndex)` to open the camera.  
   - Encodes frames in JPEG (`imencodeAsync`) before returning them as `Uint8List`.

3. **`RemoteCameraProvider`**  
   - Connects over HTTP to retrieve frames from a remote device that’s running the server.  
   - Uses `HttpClient` to send a GET request to `/get_image`.  
   - The response is a JPEG-encoded `Uint8List`.

---

### 3.2 CameraProviderServer & HTTP Endpoints

- **`CameraProviderServer`**  
  - Wraps `LocalCameraProvider` and binds an HTTP server on a specified port (e.g., `:12345`).  
  - Serves frames from `localCameraProvider.getFrame()` via the `/get_image` route.  
  - Also responds to `/test` for basic connectivity checks.  
  - Logs incoming requests using `RequestLogs` for real-time debugging.

When you start the camera provider, it:

1. **Opens** the local camera (e.g., `LocalCameraProvider(0)` for camera index 0).
2. **Starts** the HTTP server and begins listening for requests (e.g., on `0.0.0.0:12345`).
3. **Broadcasts** that it’s a `_camera._tcp` service via `BroadcastService`.

---

### 3.3 Network Discovery

- **`BroadcastService`**  
  - Advertises (broadcasts) the camera’s service name, type, and port (e.g. `_camera._tcp`) so other devices can find it automatically.  
  - Built on `Bonsoir` (or a similar mDNS-based library) to simplify local discovery.  

- **`DiscoveryService`**  
  - Listens for broadcasted services on the Data Center side.  
  - Whenever a new service is found (e.g., “MyCameraProvider” on IP `192.168.1.10`, port `12345`), it notifies the app.  
  - The Data Center can then create a `RemoteCameraProvider` to fetch frames.

---

### 3.4 Data Center

- **`DataCenterView`**  
  - Displays a grid or list of discovered camera feeds.  
  - For each discovered camera, a `RemoteCameraProvider` is used to retrieve frames.  
  - Each camera feed is displayed in a widget (e.g., `DataCenterCameraPreview`) that polls frames at a configurable FPS.

- **`DataCenterCameraPreview`**  
  - Periodically calls `getFrame()` on the given provider.  
  - Optionally passes the frame to `FaceProcessingService` to detect and draw bounding boxes or landmarks.  
  - Renders the final processed image as a `Widget`.

---

### 3.5 Face Detection & Extraction

1. **`FaceExtractionService`**  
   - Uses a **face detection model** (e.g., `face_detection_yunet_2023mar.onnx`) to find faces in the frame.  
   - Returns bounding boxes and landmarks as an OpenCV Mat.

2. **`FaceFeaturesExtractionService`**  
   - Takes the bounding box data from `FaceExtractionService`, aligns and crops the face, then uses a **face recognition model** (e.g., `face_recognition_sface_2021dec.onnx`) to generate a feature vector (embedding).  
   - This embedding can be used to compare or identify faces.

3. **`FaceComparisonService`**  
   - Compares two embeddings to see if they represent the same person.  
   - Provides a “similarity score” or boolean result (similar vs. dissimilar).

4. **`FaceProcessingService`**  
   - A convenience layer that decodes an image, runs detection, optionally draws bounding boxes, and re-encodes the processed image for display.

With this pipeline, once you’ve extracted face embeddings, you could store them in a database (with timestamps) to track:

- **Arrival**: When a face is first seen by an entrance camera.  
- **Departure**: When a face is seen by an exit camera.  
- **Location**: If intermediate hallway cameras detect the same face, you can infer the path the individual took inside the building.

---

## 4. Typical Workflows

### 4.1 Local Camera Provider Workflow

1. **Start the server**: `CameraProviderServer.start()`.  
2. The server opens the local camera using `LocalCameraProvider`.  
3. The server binds an HTTP endpoint (`/get_image`).  
4. `BroadcastService` advertises `_camera._tcp` with the chosen port.

**On the same device (or remote)**, you can confirm the feed by visiting `http://<IP>:12345/get_image`.

---

### 4.2 Remote Camera Discovery & Usage

1. **Data Center** calls `startDiscovery("_camera._tcp")`.  
2. **`DiscoveryService`** listens for broadcasted services. When one is found:  
   - The Data Center automatically instantiates a `RemoteCameraProvider` with `<address>` and `<port>`.  
   - Calls `openCamera()` on it to confirm availability.  
3. The Data Center periodically calls `getFrame()` to retrieve the JPEG frames.  
4. The frames can then be passed to `FaceProcessingService` to detect faces, draw bounding boxes, or extract features.  
5. Display processed frames in `DataCenterCameraPreview`.

---

## 5. Tracking People In and Out

With the face detection and feature extraction pipeline in place, you can log each detected face along with:

- **Time** (current date/time).
- **Camera location** (entrance camera vs. exit camera).
- **Unique identifier** (if you match the face embedding to a known user from your database).

By correlating these logs, you can:

- **Identify** who arrived (and when).  
- **Track** if the same face was detected at another location (e.g., hallway camera or exit).  
- **Determine** how long they stayed before leaving.

You can store these events in a backend database or simply log them. Over time, you build an attendance record or a path history within the building.

---

## 6. Potential Expansions

1. **Authentication & Authorization**  
   - Secure endpoints with basic auth, token-based auth, or HTTPS to prevent unauthorized camera access.

2. **Database Integration**  
   - Store face embeddings and timestamps to build a persistent attendance or movement log.

3. **Notifications or Alerts**  
   - Send push notifications or emails if a recognized face enters or leaves (e.g., for employees or restricted areas).

4. **PTZ (Pan-Tilt-Zoom) Control**  
   - If cameras support PTZ, extend the HTTP interface to accept movement commands.

5. **Scalability**  
   - For large environments, consider a more scalable discovery mechanism and a robust message bus (e.g., MQTT or Kafka).

6. **Analytics & Dashboards**  
   - Create interactive dashboards to visualize who entered, how long they stayed, and their movement paths.

---

## 7. Conclusion

This updated architecture leverages:

- **OpenCV-based face detection** (via `FaceExtractionService`) to find faces in frames.
- **Face embedding extraction** (via `FaceFeaturesExtractionService`) to identify or track people across multiple cameras.
- **Local and Remote camera providers** that unify capturing logic under the `ICameraProvider` interface.
- **Broadcast and Discovery** services to automatically find cameras on the local network without manual IP configuration.
- **Data Center** that aggregates camera feeds, processes frames, and displays them.  

By combining these pieces, you can place cameras at entrances/exits to see when people come or go, and optionally track them inside the building through additional camera placements. This makes it a flexible foundation for attendance, security monitoring, or advanced analytics.