import abc
import logging
import importlib.util
import numpy as np

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class BaseCameraProvider(abc.ABC):
    """Abstract base class for camera providers."""
    
    def __init__(self):
        self.is_open = False

    @abc.abstractmethod
    async def open_camera(self):
        """Open and initialize the camera."""
        pass

    @abc.abstractmethod
    async def get_frame(self):
        """Capture and return a JPEG-encoded frame."""
        pass

    @abc.abstractmethod
    async def close_camera(self):
        """Close and clean up the camera."""
        pass

class OpenCVCameraProvider(BaseCameraProvider):
    """Camera provider implementation using OpenCV."""
    
    def __init__(self, camera_index=0):
        super().__init__()
        self.camera_index = camera_index
        self.cap = None
        self._check_opencv()

    def _check_opencv(self):
        try:
            import cv2
            self.cv2 = cv2
        except ImportError:
            raise ImportError("OpenCV (cv2) is required for OpenCVCameraProvider")

    async def open_camera(self):
        try:
            self.cap = self.cv2.VideoCapture(self.camera_index)
            if not self.cap.isOpened():
                logger.error(f"Failed to open camera {self.camera_index}")
                return False
            self.is_open = True
            logger.info(f"Successfully opened camera {self.camera_index}")
            return True
        except Exception as e:
            logger.error(f"Error opening camera: {e}")
            return False

    async def get_frame(self):
        if not self.is_open:
            return None
        try:
            ret, frame = self.cap.read()
            if not ret or frame is None:
                logger.error("Failed to capture frame")
                return None
            _, jpeg_data = self.cv2.imencode('.jpg', frame)
            return jpeg_data.tobytes()
        except Exception as e:
            logger.error(f"Error capturing frame: {e}")
            return None

    async def close_camera(self):
        if self.cap:
            self.cap.release()
        self.is_open = False
        logger.info("Camera closed")

class PiCameraProvider(BaseCameraProvider):
    """Camera provider implementation using PiCamera."""
    
    def __init__(self):
        super().__init__()
        self.camera = None
        self._check_picamera()
        self.stream = None
        
    def _check_picamera(self):
        try:
            import picamera
            self.picamera = picamera
        except ImportError:
            raise ImportError("picamera is required for PiCameraProvider")

    async def open_camera(self):
        try:
            self.camera = self.picamera.PiCamera()
            self.camera.resolution = (640, 480)
            self.camera.framerate = 24
            self.stream = self.picamera.PiRGBArray(self.camera)
            self.is_open = True
            logger.info("Successfully initialized PiCamera")
            return True
        except Exception as e:
            logger.error(f"Error initializing PiCamera: {e}")
            return False

    async def get_frame(self):
        if not self.is_open:
            return None
        try:
            # Clear the stream
            self.stream.truncate(0)
            self.stream.seek(0)
            
            # Capture frame directly to memory stream
            self.camera.capture(self.stream, format='jpeg', use_video_port=True)
            return self.stream.getvalue()
        except Exception as e:
            logger.error(f"Error capturing frame: {e}")
            return None

    async def close_camera(self):
        if self.camera:
            self.camera.close()
        self.is_open = False
        logger.info("PiCamera closed")

def create_camera_provider(camera_type='auto', camera_index=0):
    """
    Factory function to create the appropriate camera provider.
    
    Args:
        camera_type (str): Type of camera provider ('opencv', 'picamera', or 'auto')
        camera_index (int): Camera index for OpenCV provider
        
    Returns:
        BaseCameraProvider: An instance of the appropriate camera provider
    """
    if camera_type == 'picamera':
        return PiCameraProvider()
    elif camera_type == 'opencv':
        return OpenCVCameraProvider(camera_index)
    else:  # auto detection
        # Try PiCamera first on Raspberry Pi
        try:
            if importlib.util.find_spec("picamera"):
                return PiCameraProvider()
        except ImportError:
            pass
        
        # Fall back to OpenCV
        try:
            if importlib.util.find_spec("cv2"):
                return OpenCVCameraProvider(camera_index)
        except ImportError:
            pass
            
        raise ImportError("No suitable camera provider found. Please install either OpenCV or PiCamera.")