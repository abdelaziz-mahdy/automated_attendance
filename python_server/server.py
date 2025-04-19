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
import tempfile
from aiohttp import MultipartReader, BodyPartReader

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
        storage_dir = os.path.join(os.path.dirname(__file__), 'data')
        os.makedirs(storage_dir, exist_ok=True)
        self.face_processor = FaceProcessor(storage_dir=storage_dir)
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
        
        # Use memory-based approach to get counts
        people = self.face_processor.memory.get_all_people()
        
        # Get the current timestamp for reference
        current_time = datetime.datetime.now().isoformat()
        
        # Convert to a format suitable for JSON with timestamp information
        counts_data = {
            person_id: {
                'count': person.appearance_count,
                'is_named': person.is_named,
                'first_seen': self.face_processor.get_first_seen_time(person_id),
                'last_seen': self.face_processor.get_last_seen_time(person_id),
                'timestamp': current_time
            }
            for person_id, person in people.items()
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
        
        # Use the existing method that already uses memory
        known_faces = self.face_processor.get_known_faces()
        
        # Additional information about known people
        all_people = self.face_processor.memory.get_all_people()
        known_face_ids = [person_id for person_id, person in all_people.items() if person.is_named]
        
        response = web.json_response({
            'known_faces': known_faces,
            'count': len(known_face_ids),
            'known_faces_list': known_face_ids
        })
        
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
        
        # Check if new ID already exists - this is a merge operation, not a rename
        if self.face_processor.memory.get_person(new_face_id):
            logger.info(f"[Request #{self._request_count}] New face ID already exists, redirecting to merge operation")
            success = self.face_processor.merge_faces(old_face_id, new_face_id)
            if not success:
                return web.Response(status=400, text="Failed to merge faces - one or both IDs may not exist")
                
            elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[Request #{self._request_count}] Successfully merged faces in {elapsed:.2f}ms")
            return web.Response(text=f"Successfully merged '{old_face_id}' into '{new_face_id}'")
        
        # Check if old face exists
        old_person = self.face_processor.memory.get_person(old_face_id)
        if not old_person:
            logger.error(f"[Request #{self._request_count}] Face ID '{old_face_id}' not found")
            return web.Response(status=400, text=f"Face ID '{old_face_id}' not found")
        
        # Use the memory's rename_person method for the rename operation
        success = self.face_processor.memory.rename_person(old_face_id, new_face_id)
        
        if success:
            # Request a save to persist the change
            self.face_processor.memory.request_save()
            
            elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[Request #{self._request_count}] Successfully renamed face from '{old_face_id}' to '{new_face_id}' in {elapsed:.2f}ms")
            return web.Response(text=f"Successfully renamed '{old_face_id}' to '{new_face_id}'")
        else:
            return web.Response(status=400, text=f"Failed to rename face - please check logs for details")
    
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
        
    async def _handle_import_faces_batch(self, request):
        """Handle batch import of faces from uploaded images."""
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received IMPORT_FACES_BATCH request from {request.remote}")

        try:
            # Check content type
            content_type = request.content_type
            if not content_type.startswith('multipart/'):
                logger.warning(f"Invalid content type: {content_type}")
                return web.Response(status=400, text="Invalid content type, expected multipart/form-data")

            reader = await request.multipart()

            # Prepare result object
            result = {
                "success": True,
                "person_name": "",
                "images_processed": 0,
                "faces_detected": 0,
                "failed_images": [],
                "errors": []
            }

            # Create temporary directory for processing
            temp_dir = tempfile.mkdtemp()
            logger.info(f"Created temp directory: {temp_dir}")

            # Initialize tracking variables
            person_name = None
            image_files = [] # Store tuples of (filename, filepath)

            try:
                # Process multipart data
                while True:
                    part = await reader.next()
                    if part is None:
                        break

                    if part.name == 'person_name':
                        person_name = (await part.text()).strip()
                        result["person_name"] = person_name
                        logger.info(f"Processing import for person: {person_name}")
                    elif part.name == 'images':
                        filename = part.filename
                        if filename and self._is_valid_image_filename(filename):
                            # Save file temporarily
                            file_path = os.path.join(temp_dir, filename)
                            with open(file_path, 'wb') as f:
                                while True:
                                    chunk = await part.read_chunk()
                                    if not chunk:
                                        break
                                    f.write(chunk)
                            image_files.append((filename, file_path))
                            logger.debug(f"Saved temporary image: {file_path}")
                        else:
                            logger.warning(f"Skipping invalid file: {filename}")
                            result["failed_images"].append(filename)
                            result["errors"].append(f"Invalid file type: {filename}")

                if not person_name:
                    raise ValueError("Missing 'person_name' in form data")
                if not image_files:
                    raise ValueError("No valid image files provided")

                # Process saved images using FaceProcessor
                detected_faces = 0
                processed_count = 0
                for filename, file_path in image_files:
                    try:
                        # Read image using OpenCV
                        img = cv2.imread(file_path)
                        if img is None:
                            raise ValueError(f"Could not read image file: {filename}")

                        # Process using FaceProcessor
                        success, face_id = await asyncio.get_event_loop().run_in_executor(
                            None, self.face_processor.process_imported_face_image, img, person_name
                        )

                        processed_count += 1
                        if success:
                            detected_faces += 1
                            # face_id should be the person_name if successful
                            result["face_id"] = face_id # Store the confirmed face_id
                        else:
                            result["failed_images"].append(filename)
                            # Add more specific error if possible, otherwise generic
                            if f"No face detected in image for {person_name}" not in str(result["errors"]): # Avoid duplicate no-face errors
                                result["errors"].append(f"Processing failed for {filename} (e.g., no face or low confidence)")

                    except Exception as img_err:
                        logger.error(f"Error processing image {filename}: {img_err}", exc_info=True)
                        result["failed_images"].append(filename)
                        result["errors"].append(f"Error processing {filename}: {str(img_err)}")

                # Update result
                result["images_processed"] = processed_count
                result["faces_detected"] = detected_faces

                # Check if overall success based on detected faces
                if detected_faces == 0 and processed_count > 0:
                    result["success"] = False
                    if not result["errors"]: # Add a generic error if none specific were added
                         result["errors"].append(f"No faces successfully processed for {person_name}")

            finally:
                # Cleanup temp files and directory
                logger.info(f"Cleaning up temp directory: {temp_dir}")
                for _, file_path in image_files:
                    try:
                        if os.path.exists(file_path):
                            os.remove(file_path)
                    except Exception as e:
                        logger.error(f"Error removing temp file {file_path}: {e}")

                try:
                    if os.path.exists(temp_dir):
                        os.rmdir(temp_dir)
                except Exception as e:
                    logger.error(f"Error removing temp directory {temp_dir}: {e}")

            # Return results
            elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[Request #{self._request_count}] Processed batch import for '{person_name}' in {elapsed:.2f}ms - {result['faces_detected']}/{result['images_processed']} faces detected/processed.")

            return web.json_response(result)

        except Exception as e:
            logger.error(f"[Request #{self._request_count}] Error handling batch import: {e}", exc_info=True)
            # Ensure result reflects the error
            error_result = {
                "success": False,
                "person_name": person_name if 'person_name' in locals() else "Unknown",
                "images_processed": 0,
                "faces_detected": 0,
                "failed_images": [f[0] for f in image_files] if 'image_files' in locals() else [],
                "errors": [f"Server error during import: {str(e)}"]
            }
            return web.json_response(error_result, status=500)

    def _is_valid_image_filename(self, filename):
        """Check if filename has a valid image extension."""
        valid_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.webp']
        ext = os.path.splitext(filename.lower())[1]
        return ext in valid_extensions
    
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
            app.router.add_get('/get_known_faces', self._handle_get_known_faces)
            app.router.add_get('/merge_faces', self._handle_merge_faces)
            app.router.add_get('/get_face_data', self._handle_get_face_data)
            app.router.add_get('/rename_face', self._handle_rename_face)
            app.router.add_post('/import_faces_batch', self._handle_import_faces_batch)
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
        
        # Shutdown face memory to ensure data is saved
        if hasattr(self.face_processor, 'memory'):
            logger.info("Shutting down face memory...")
            self.face_processor.memory.shutdown()
            
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
