import cv2
import numpy as np
from abc import ABC, abstractmethod
import logging
import platform
import os
import io
import asyncio

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class ICameraProvider(ABC):
    @abstractmethod
    async def open_camera(self) -> bool:
        pass
    
    @abstractmethod
    async def close_camera(self):
        pass
    
    @abstractmethod
    async def get_frame(self) -> bytes:
        pass
    
    @property
    @abstractmethod
    def is_open(self) -> bool:
        pass

class LocalCameraProvider(ICameraProvider):
    def __init__(self, camera_index: int):
        self.camera_index = camera_index
        self._capture = None
        self._is_open = False
        self._frame_count = 0
        logger.info(f"Initialized LocalCameraProvider with camera index {camera_index}")
        
    async def open_camera(self) -> bool:
        try:
            logger.info(f"Attempting to open camera {self.camera_index}")
            self._capture = cv2.VideoCapture(self.camera_index)
            if self._capture.isOpened():
                self._is_open = True
                # Get camera properties
                width = self._capture.get(cv2.CAP_PROP_FRAME_WIDTH)
                height = self._capture.get(cv2.CAP_PROP_FRAME_HEIGHT)
                fps = self._capture.get(cv2.CAP_PROP_FPS)
                logger.info(f"Camera opened successfully:")
                logger.info(f"  - Resolution: {width}x{height}")
                logger.info(f"  - FPS: {fps}")
                return True
            else:
                logger.error(f"Failed to open camera {self.camera_index}")
        except Exception as e:
            logger.error(f"Error opening camera: {e}")
        return False
    
    async def close_camera(self):
        if self._is_open and self._capture:
            logger.info(f"Closing camera {self.camera_index}")
            logger.info(f"Total frames captured: {self._frame_count}")
            self._capture.release()
            self._is_open = False
            logger.info("Camera closed successfully")
    
    async def get_frame(self) -> bytes:
        if not self._is_open:
            logger.warning("Attempted to get frame but camera is not open")
            return None
        
        try:
            ret, frame = self._capture.read()
            if not ret:
                logger.error("Failed to capture frame")
                return None
                
            self._frame_count += 1
            _, buffer = cv2.imencode('.jpg', frame)
            frame_size = len(buffer.tobytes()) / 1024  # Size in KB
            logger.debug(f"Captured frame #{self._frame_count} (Size: {frame_size:.1f}KB)")
            return buffer.tobytes()
        except Exception as e:
            logger.error(f"Error capturing frame: {e}")
            return None
    
    @property
    def is_open(self) -> bool:
        return self._is_open

class PiCameraProvider(ICameraProvider):
    def __init__(self, camera_index: int = 0, resolution=(640, 480), framerate=30):
        self.camera_index = camera_index
        self.resolution = resolution
        self.framerate = framerate
        self._camera = None
        self._is_open = False
        self._frame_count = 0
        self._picamera_available = self._check_picamera()
        logger.info(f"Initialized PiCameraProvider with camera index {camera_index}, resolution {resolution}, framerate {framerate}")
        
    def _check_picamera(self) -> bool:
        """Check if picamera is available on this system"""
        try:
            import picamera
            return True
        except ImportError:
            logger.warning("picamera module not found. This won't work on Raspberry Pi without it.")
            return False
            
    async def open_camera(self) -> bool:
        if not self._picamera_available:
            logger.error("Cannot open PiCamera - picamera module not available")
            return False
            
        try:
            # Import here to avoid errors on non-Pi systems
            import picamera
            
            logger.info(f"Attempting to initialize Raspberry Pi Camera")
            self._camera = picamera.PiCamera(camera_num=self.camera_index)
            
            # Configure the camera
            self._camera.resolution = self.resolution
            self._camera.framerate = self.framerate
            
            # Allow camera to warm up
            await asyncio.sleep(2)
            self._is_open = True
            
            # Get camera info
            logger.info("Pi Camera opened successfully:")
            logger.info(f"  - Resolution: {self.resolution}")
            logger.info(f"  - Framerate: {self.framerate}")
            
            return True
        except Exception as e:
            logger.error(f"Error opening Pi Camera: {e}")
            return False
    
    async def close_camera(self):
        if self._is_open and self._camera:
            logger.info("Closing Pi Camera")
            logger.info(f"Total frames captured: {self._frame_count}")
            self._camera.close()
            self._is_open = False
            logger.info("Pi Camera closed successfully")
    
    async def get_frame(self) -> bytes:
        if not self._is_open or not self._camera:
            logger.warning("Attempted to get frame but Pi Camera is not open")
            return None
            
        try:
            # Create in-memory stream
            stream = io.BytesIO()
            
            # Capture an image directly to the stream in JPEG format
            self._camera.capture(stream, format='jpeg', use_video_port=True)
            
            # "Rewind" the stream to the beginning
            stream.seek(0)
            
            # Read the stream
            frame_bytes = stream.getvalue()
            
            self._frame_count += 1
            frame_size = len(frame_bytes) / 1024  # Size in KB
            logger.debug(f"Captured Pi Camera frame #{self._frame_count} (Size: {frame_size:.1f}KB)")
            return frame_bytes
        except Exception as e:
            logger.error(f"Error capturing Pi Camera frame: {e}")
            return None
    
    @property
    def is_open(self) -> bool:
        return self._is_open

def create_camera_provider(camera_type: str = "auto", camera_index: int = 0):
    """
    Factory function to create the appropriate camera provider
    
    Args:
        camera_type: "opencv", "picamera", or "auto" (detect based on platform)
        camera_index: Camera index to use
        
    Returns:
        A camera provider instance
    """
    if camera_type == "auto":
        # Auto-detect if we're on a Raspberry Pi
        is_raspberry_pi = (
            os.path.exists("/proc/device-tree/model") and 
            "raspberry pi" in open("/proc/device-tree/model").read().lower()
        ) or platform.machine() in ('armv7l', 'aarch64')
        
        if is_raspberry_pi:
            try:
                import picamera
                logger.info("Detected Raspberry Pi platform, using PiCameraProvider")
                return PiCameraProvider(camera_index)
            except ImportError:
                logger.warning("Raspberry Pi detected but picamera not installed, falling back to OpenCV")
                return LocalCameraProvider(camera_index)
        else:
            logger.info("Using standard OpenCV camera provider")
            return LocalCameraProvider(camera_index)
    elif camera_type == "picamera":
        return PiCameraProvider(camera_index)
    else:  # default to opencv
        return LocalCameraProvider(camera_index)