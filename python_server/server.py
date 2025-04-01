import asyncio
from aiohttp import web
import json
from zeroconf.asyncio import AsyncZeroconf
import socket
import logging
from camera_provider import create_camera_provider
from face_processor import FaceProcessor
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
        
        # Convert to a format suitable for JSON
        counts_data = {
            face_id: {
                'count': count,
                'is_named': face_id in self.face_processor.known_faces
            }
            for face_id, count in face_counts.items()
        }
        
        response = web.json_response(counts_data)
        
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_FACE_COUNTS request in {elapsed:.2f}ms")
        return response
    
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
            app.router.add_get('/get_face_counts', self._handle_get_face_counts)  # New endpoint
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