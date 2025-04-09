import asyncio
from aiohttp import web
import json
from zeroconf.asyncio import AsyncZeroconf
import socket
import logging
from camera_provider import create_camera_provider
from face_processor import FaceProcessor
from face_comparison_service import FaceComparisonService
from zeroconf import ServiceInfo
import datetime
import argparse
import os
import cv2
import numpy as np

# Configure logging with more detail
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class CameraProviderServer:
    def __init__(self, camera_type='auto', camera_index=0, host='0.0.0.0', port=12345):
        self._server = None
        self._zeroconf = None
        self._service_info = None
        self._camera_type = camera_type
        self._camera_index = camera_index
        self._host = host
        self._port = port
        self.camera_provider = None  # Will be initialized in start()
        self._request_count = 0
        self.face_processor = FaceProcessor()
        self.current_frame = None  # Store the latest frame
        
    async def _handle_test(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received TEST request from {request.remote}")
        response = web.Response(status=200)
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Handled TEST request in {elapsed:.2f}ms")
        return response
        
    async def _handle_get_image(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received GET_IMAGE request from {request.remote}")
        
        if not self.camera_provider.is_open:
            logger.error(f"[Request #{self._request_count}] Camera is not open")
            return web.Response(status=500)
            
        frame = await self.camera_provider.get_frame()
        self.current_frame = frame  # Store the latest frame
        if frame is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        response = web.Response(body=frame, content_type='image/jpeg')
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_IMAGE request in {elapsed:.2f}ms")
        return response
    
    async def _handle_get_image_with_detection(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received FACE_DETECTION request from {request.remote}")
        
        if not self.camera_provider.is_open:
            logger.error(f"[Request #{self._request_count}] Camera is not open")
            return web.Response(status=500)
            
        # Get the raw JPEG frame
        jpeg_data = await self.camera_provider.get_frame()
        if jpeg_data is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        # Convert JPEG to numpy array for OpenCV
        nparr = np.frombuffer(jpeg_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Detect faces
        img_with_faces, _ = self.face_processor.detect_faces(img)
        
        # Convert back to JPEG
        is_success, buffer = cv2.imencode(".jpg", img_with_faces)
        if not is_success:
            logger.error(f"[Request #{self._request_count}] Failed to encode processed image")
            return web.Response(status=500)
        
        # Return the processed image
        response = web.Response(body=buffer.tobytes(), content_type='image/jpeg')
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled FACE_DETECTION request in {elapsed:.2f}ms")
        return response
    
    async def _handle_get_image_with_recognition(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received FACE_RECOGNITION request from {request.remote}")
        
        if not self.camera_provider.is_open:
            logger.error(f"[Request #{self._request_count}] Camera is not open")
            return web.Response(status=500)
            
        # Get the raw JPEG frame
        jpeg_data = await self.camera_provider.get_frame()
        if jpeg_data is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        # Convert JPEG to numpy array for OpenCV
        nparr = np.frombuffer(jpeg_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Recognize faces
        img_with_faces, _ = self.face_processor.recognize_faces(img)
        
        # Convert back to JPEG
        is_success, buffer = cv2.imencode(".jpg", img_with_faces)
        if not is_success:
            logger.error(f"[Request #{self._request_count}] Failed to encode processed image")
            return web.Response(status=500)
        
        # Return the processed image
        response = web.Response(body=buffer.tobytes(), content_type='image/jpeg')
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled FACE_RECOGNITION request in {elapsed:.2f}ms")
        return response
    
    async def _handle_add_face(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received ADD_FACE request from {request.remote}")
        
        # Get face ID from query parameters
        face_id = request.query.get('id', None)
        if face_id is None:
            logger.error(f"[Request #{self._request_count}] No face ID provided")
            return web.Response(status=400, text="Face ID is required")
        
        # Get latest frame or capture new one
        jpeg_data = await self.camera_provider.get_frame()
        if jpeg_data is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        # Convert JPEG to numpy array for OpenCV
        nparr = np.frombuffer(jpeg_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Add the face
        success = self.face_processor.add_face(img, face_id)
        if not success:
            return web.Response(status=500, text="Failed to add face")
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully added face '{face_id}' in {elapsed:.2f}ms")
        return web.Response(text=f"Face '{face_id}' added successfully")
    
    async def _handle_get_face_counts(self, request):
        """Handle requests for face appearance counts."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received GET_FACE_COUNTS request from {request.remote}")
        
        face_counts = self.face_processor.get_face_counts()
        
        # Get the current timestamp for reference
        current_time = datetime.datetime.now().isoformat()
        
        # Convert to a format suitable for JSON with timestamp information
        counts_data = {
            face_id: {
                'count': count,
                'is_named': face_id in self.face_processor.known_faces,
                'first_seen': self.face_processor.get_first_seen_time(face_id),
                'last_seen': self.face_processor.get_last_seen_time(face_id),
                'timestamp': current_time
            }
            for face_id, count in face_counts.items()
        }
        
        response = web.json_response(counts_data)
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_FACE_COUNTS request in {elapsed:.2f}ms")
        return response
    
    async def _handle_get_known_faces(self, request):
        """Handle requests for known face data including features."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received GET_KNOWN_FACES request from {request.remote}")
        
        known_faces = self.face_processor.get_known_faces()
        
        response = web.json_response(known_faces)
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_KNOWN_FACES request in {elapsed:.2f}ms")
        return response
    
    async def _handle_merge_faces(self, request):
        """Handle requests to merge two face entries."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received MERGE_FACES request from {request.remote}")
        
        # Get source and target face IDs from query parameters
        source_face_id = request.query.get('source', None)
        target_face_id = request.query.get('target', None)
        
        if source_face_id is None or target_face_id is None:
            logger.error(f"[Request #{self._request_count}] Missing source or target face ID")
            return web.Response(status=400, text="Both source and target face IDs are required")
        
        # Attempt to merge the faces
        success = self.face_processor.merge_faces(source_face_id, target_face_id)
        
        if not success:
            return web.Response(status=400, text="Failed to merge faces - one or both IDs may not exist")
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully merged faces in {elapsed:.2f}ms")
        return web.Response(text=f"Successfully merged '{source_face_id}' into '{target_face_id}'")
    
    async def _handle_get_face_data(self, request):
        """Handle requests for comprehensive face data including detection and recognition results."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received GET_FACE_DATA request from {request.remote}")
        
        if not self.camera_provider.is_open:
            logger.error(f"[Request #{self._request_count}] Camera is not open")
            return web.Response(status=500)
            
        # Get the raw JPEG frame
        jpeg_data = await self.camera_provider.get_frame()
        if jpeg_data is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        # Convert JPEG to numpy array for OpenCV
        nparr = np.frombuffer(jpeg_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Process with face recognition
        _, recognized_faces = self.face_processor.recognize_faces(img)
        
        # Return just the face data (not the image)
        response = web.json_response({
            'faces': recognized_faces,
            'timestamp': datetime.datetime.now().isoformat()
        })
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_FACE_DATA request in {elapsed:.2f}ms")
        return response
    
    async def _handle_rename_face(self, request):
        """Handle requests to rename a face."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received RENAME_FACE request from {request.remote}")
        
        # Get old and new face IDs from query parameters
        old_face_id = request.query.get('old_id', None)
        new_face_id = request.query.get('new_id', None)
        
        if old_face_id is None or new_face_id is None:
            logger.error(f"[Request #{self._request_count}] Missing old or new face ID")
            return web.Response(status=400, text="Both old and new face IDs are required")
        
        if old_face_id == new_face_id:
            logger.info(f"[Request #{self._request_count}] Old and new face IDs are the same, no action needed")
            return web.Response(text="No changes needed")
        
        # Check if this is actually a merge (new_id already exists)
        if new_face_id in self.face_processor.known_faces:
            logger.info(f"[Request #{self._request_count}] New face ID already exists, redirecting to merge operation")
            # This is a merge operation, not a rename
            success = self.face_processor.merge_faces(old_face_id, new_face_id)
            if not success:
                return web.Response(status=400, text="Failed to merge faces - one or both IDs may not exist")
                
            elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[Request #{self._request_count}] Successfully merged faces in {elapsed:.2f}ms")
            return web.Response(text=f"Successfully merged '{old_face_id}' into '{new_face_id}'")
        
        # Check if old_face_id exists in tracked_faces but not in known_faces
        # This handles the case of renaming a newly detected face
        old_face_in_known = old_face_id in self.face_processor.known_faces
        old_face_in_tracked = old_face_id in self.face_processor.tracked_faces
        
        if not old_face_in_known and not old_face_in_tracked:
            logger.error(f"[Request #{self._request_count}] Face ID '{old_face_id}' not found in known or tracked faces")
            return web.Response(status=400, text=f"Face ID '{old_face_id}' not found")
            
        # If face is only in tracked_faces, we need to move it to known_faces first
        if not old_face_in_known and old_face_in_tracked:
            logger.info(f"[Request #{self._request_count}] Moving face from tracked to known faces before renaming")
            self.face_processor.known_faces[old_face_id] = self.face_processor.tracked_faces[old_face_id]['feature']
            old_face_in_known = True
        
        # This is a true rename operation
        # Update the face entry directly in the processor's dictionaries
        if old_face_in_known:
            # Copy the face feature to the new ID
            self.face_processor.known_faces[new_face_id] = self.face_processor.known_faces[old_face_id]
            # Remove the old entry
            del self.face_processor.known_faces[old_face_id]
            
            # Update appearance counts
            if old_face_id in self.face_processor.face_appearance_count:
                self.face_processor.face_appearance_count[new_face_id] = self.face_processor.face_appearance_count[old_face_id]
                del self.face_processor.face_appearance_count[old_face_id]
            
            # Update tracked faces if necessary
            if old_face_id in self.face_processor.tracked_faces:
                self.face_processor.tracked_faces[new_face_id] = self.face_processor.tracked_faces[old_face_id]
                del self.face_processor.tracked_faces[old_face_id]
                
            elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[Request #{self._request_count}] Successfully renamed face from '{old_face_id}' to '{new_face_id}' in {elapsed:.2f}ms")
            return web.Response(text=f"Successfully renamed '{old_face_id}' to '{new_face_id}'")
        else:
            return web.Response(status=400, text=f"Failed to rename face - something unexpected happened")
    
    async def _handle_static_files(self, request):
        path = request.match_info.get('path', 'index.html')
        static_path = os.path.join(os.path.dirname(__file__), 'static')
        file_path = os.path.join(static_path, path)
        
        if os.path.exists(file_path):
            # Determine content type
            content_type = 'text/html'
            if file_path.endswith('.css'):
                content_type = 'text/css'
            elif file_path.endswith('.js'):
                content_type = 'application/javascript'
            elif file_path.endswith('.jpg') or file_path.endswith('.jpeg'):
                content_type = 'image/jpeg'
            elif file_path.endswith('.png'):
                content_type = 'image/png'
            
            with open(file_path, 'rb') as f:
                return web.Response(body=f.read(), content_type=content_type)
        else:
            return web.Response(status=404)
        
    async def start(self):
        try:
            logger.info("Starting Camera Provider Server...")
            
            # Initialize camera using factory function
            logger.info(f"Initializing camera (type: {self._camera_type}, index: {self._camera_index})...")
            self.camera_provider = create_camera_provider(
                camera_type=self._camera_type,
                camera_index=self._camera_index
            )
            
            success = await self.camera_provider.open_camera()
            if not success:
                raise Exception("Failed to open camera")
            logger.info("Camera initialized successfully")
            
            # Load face processing models
            assets_dir = os.path.join(os.path.dirname(__file__),'..', 'assets')
            detection_model = os.path.join(assets_dir, 'face_detection_yunet_2023mar.onnx')
            recognition_model = os.path.join(assets_dir, 'face_recognition_sface_2021dec.onnx')
            
            success = self.face_processor.load_models(detection_model, recognition_model)
            if not success:
                logger.warning("Failed to load face processing models. Face detection/recognition will not be available.")
            else:
                logger.info("Face processing models loaded successfully")
            
            # Create web application
            logger.info("Setting up web application...")
            app = web.Application()
            app.router.add_get('/test', self._handle_test)
            app.router.add_get('/get_image', self._handle_get_image)
            app.router.add_get('/get_image_with_detection', self._handle_get_image_with_detection)
            app.router.add_get('/get_image_with_recognition', self._handle_get_image_with_recognition)
            app.router.add_get('/add_face', self._handle_add_face)
            app.router.add_get('/get_face_counts', self._handle_get_face_counts)
            app.router.add_get('/get_known_faces', self._handle_get_known_faces)  # New endpoint for known faces
            app.router.add_get('/merge_faces', self._handle_merge_faces)  # New endpoint for merging faces
            app.router.add_get('/get_face_data', self._handle_get_face_data)  # New endpoint for face data without image
            app.router.add_get('/rename_face', self._handle_rename_face)  # New endpoint for renaming faces
            app.router.add_get('/', self._handle_static_files)
            app.router.add_get('/{path:.*}', self._handle_static_files)
            
            # Start server
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, self._host, self._port)
            await site.start()
            logger.info(f"HTTP server started at http://{self._host}:{self._port}")
            
            # Register zeroconf service
            logger.info("Registering Zeroconf service...")
            self._zeroconf = AsyncZeroconf()
            service_name = "PythonCameraProvider"
            service_type = "_camera._tcp.local."
            
            # Get local IP address if binding to all interfaces
            local_ip = self._host
            if local_ip == '0.0.0.0':
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                try:
                    # doesn't even have to be reachable
                    s.connect(('10.255.255.255', 1))
                    local_ip = s.getsockname()[0]
                except Exception:
                    local_ip = '127.0.0.1'
                finally:
                    s.close()
            
            self._service_info = ServiceInfo(
                service_type,
                f"{service_name}.{service_type}",
                addresses=[socket.inet_aton(local_ip)],
                port=self._port,
                properties={
                    "server_type": "python",
                    "version": "1.0",
                    "camera_type": self._camera_type,
                },
            )
            
            await self._zeroconf.async_register_service(self._service_info)
            logger.info(f"Zeroconf service registered successfully:")
            logger.info(f"  - Service Name: {service_name}")
            logger.info(f"  - Service Type: {service_type}")
            logger.info(f"  - IP Address: {local_ip}")
            logger.info(f"  - Port: {self._port}")
            logger.info(f"  - Properties: {self._service_info.properties}")
            logger.info("Server is now fully operational")
            
        except Exception as e:
            logger.error(f"Error starting server: {e}")
            await self.stop()
            raise
            
    async def stop(self):
        logger.info("Stopping Camera Provider Server...")
        
        if self._zeroconf and self._service_info:
            logger.info("Unregistering Zeroconf service...")
            await self._zeroconf.async_unregister_service(self._service_info)
            await self._zeroconf.async_close()
            logger.info("Zeroconf service unregistered")
            
        if self.camera_provider:
            logger.info("Closing camera...")
            await self.camera_provider.close_camera()
            logger.info("Camera closed")
            
        logger.info("Server stopped successfully")