import abc
import logging
import importlib.util
import numpy as np
import io
import traceback
import sys
import os

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
    
    def __init__(self, camera_index=0, debug_level=0):
        super().__init__()
        self.camera_index = camera_index
        self.cap = None
        self.debug_level = debug_level
        self._check_opencv()
        self.frame_count = 0
        self.error_count = 0
        
        # Set OpenCV logging level based on debug_level
        # 0: Debug / All (includes all messages)
        # 1: Info
        # 2: Warnings
        # 3: Error
        # 4: Fatal
        # 5: Silent
        if hasattr(self.cv2, 'utils'):
            if hasattr(self.cv2.utils, 'logging'):
                # Modern OpenCV logging interface (OpenCV 4.5.1+)
                self._setup_modern_logging()
            else:
                # Older versions of OpenCV
                self._setup_legacy_logging()
                
        # Set environment variables to get more verbose backend logs
        # These affect OpenCV's backend (like V4L2, GStreamer, etc.)
        os.environ['OPENCV_VIDEOIO_DEBUG'] = '1'
        
        # This affects the level of ffmpeg logging when used as a backend
        os.environ['OPENCV_FFMPEG_DEBUG'] = '1'
        
        # If on Linux, check for video device permissions
        if sys.platform.startswith('linux'):
            self._check_video_device_permissions()

    def _check_opencv(self):
        try:
            import cv2
            self.cv2 = cv2
            logger.info(f"OpenCV version: {cv2.__version__}")
            # Get build information to identify which backends are available
            if hasattr(cv2, 'getBuildInformation'):
                build_info = cv2.getBuildInformation()
                logger.debug(f"OpenCV build information:")
                for line in build_info.split("\n"):
                    if any(x in line for x in ['Video I/O', 'GStreamer', 'ffmpeg', 'v4l']):
                        logger.debug(f"  {line.strip()}")
        except ImportError:
            raise ImportError("OpenCV (cv2) is required for OpenCVCameraProvider")

    def _setup_modern_logging(self):
        """Setup logging for modern OpenCV versions."""
        try:
            # Set the log level
            log_level = max(0, min(self.debug_level, 5))
            log_level_map = {
                0: self.cv2.utils.logging.LOG_LEVEL_DEBUG,
                1: self.cv2.utils.logging.LOG_LEVEL_INFO,
                2: self.cv2.utils.logging.LOG_LEVEL_WARNING, 
                3: self.cv2.utils.logging.LOG_LEVEL_ERROR,
                4: self.cv2.utils.logging.LOG_LEVEL_FATAL,
                5: self.cv2.utils.logging.LOG_LEVEL_SILENT
            }
            self.cv2.utils.logging.setLogLevel(log_level_map.get(log_level, self.cv2.utils.logging.LOG_LEVEL_INFO))
            logger.info(f"Set OpenCV log level to {log_level}")
        except Exception as e:
            logger.warning(f"Failed to set modern OpenCV logging level: {e}")

    def _setup_legacy_logging(self):
        """Setup logging for older OpenCV versions without utils.logging."""
        # For older versions, we can only use environment variables
        os.environ['OPENCV_LOG_LEVEL'] = str(self.debug_level)
        logger.info(f"Set OpenCV environment log level to {self.debug_level}")

    def _check_video_device_permissions(self):
        """Check permissions for video devices on Linux."""
        try:
            # Check /dev/video* devices
            import glob
            video_devices = glob.glob('/dev/video*')
            
            if not video_devices:
                logger.warning("No video devices found in /dev/video*")
            else:
                logger.info(f"Found {len(video_devices)} video devices: {', '.join(video_devices)}")
                
                # Check if we can access the device we want to use
                target_device = f"/dev/video{self.camera_index}"
                if target_device in video_devices:
                    if os.access(target_device, os.R_OK):
                        logger.info(f"Camera device {target_device} is readable")
                    else:
                        logger.error(f"No read permission for {target_device}. Run 'sudo usermod -a -G video $USER' and log out/in.")
                else:
                    logger.warning(f"Camera index {self.camera_index} (device {target_device}) not found")
                    
                # Check user groups
                import subprocess
                try:
                    groups = subprocess.check_output(['groups'], text=True).strip()
                    logger.debug(f"Current user groups: {groups}")
                    if 'video' not in groups.split():
                        logger.warning("Current user is not in the 'video' group - may not have permission to access cameras")
                except Exception as e:
                    logger.debug(f"Could not check user groups: {e}")
        except Exception as e:
            logger.debug(f"Error checking video device permissions: {e}")

    async def list_available_backends(self):
        """List all available camera backends and devices."""
        try:
            backend_info = []
            
            # Only available in newer OpenCV versions
            if hasattr(self.cv2, 'videoio_registry') and hasattr(self.cv2.videoio_registry, 'getBackends'):
                backends = self.cv2.videoio_registry.getBackends()
                for backend in backends:
                    name = self.cv2.videoio_registry.getBackendName(backend)
                    backend_info.append(f"Backend {backend}: {name}")
                logger.info(f"Available backends: {', '.join(backend_info)}")
            else:
                logger.info("OpenCV version doesn't support videoio_registry.getBackends()")
            
            # Try to list camera devices on Linux
            if sys.platform.startswith('linux'):
                import glob
                devices = glob.glob('/dev/video*')
                logger.info(f"Video devices: {', '.join(devices)}")
        except Exception as e:
            logger.error(f"Error listing camera backends: {e}")

    async def open_camera(self):
        try:
            # First, list available backends and devices for diagnostics
            await self.list_available_backends()
            
            # Try to open with specific backend if possible (only in newer OpenCV versions)
            try_backends = []
            
            # Add available backends to try based on platform
            if sys.platform.startswith('linux'):
                # On Linux, V4L2 is usually best
                if hasattr(self.cv2, 'CAP_V4L2'):
                    try_backends.append(self.cv2.CAP_V4L2)
                
            # If no platform-specific backends or they fail, add defaults
            if hasattr(self.cv2, 'CAP_ANY'):
                try_backends.append(self.cv2.CAP_ANY)
            else:
                # Fallback for older OpenCV versions
                try_backends.append(0)  # 0 is CAP_ANY equivalent
                
            # Try each backend until one works
            for backend in try_backends:
                logger.info(f"Trying to open camera {self.camera_index} with backend {backend}")
                
                # For newer OpenCV versions
                if hasattr(self.cv2, 'CAP_PROP_BACKEND'):
                    self.cap = self.cv2.VideoCapture(self.camera_index, backend)
                else:
                    # Fallback for older versions
                    self.cap = self.cv2.VideoCapture(self.camera_index)
                
                if self.cap.isOpened():
                    logger.info(f"Successfully opened camera with backend {backend}")
                    break
                else:
                    logger.warning(f"Failed to open camera with backend {backend}")
                    
            # If all backends failed
            if not self.cap or not self.cap.isOpened():
                logger.error(f"Failed to open camera {self.camera_index} with any backend")
                return False
                
            # Log camera properties for debugging
            width = self.cap.get(self.cv2.CAP_PROP_FRAME_WIDTH)
            height = self.cap.get(self.cv2.CAP_PROP_FRAME_HEIGHT)
            fps = self.cap.get(self.cv2.CAP_PROP_FPS)
            backend = self.cap.getBackendName() if hasattr(self.cap, 'getBackendName') else "Unknown"
            
            logger.info(f"Camera opened: index={self.camera_index}, resolution={width}x{height}, fps={fps}, backend={backend}")
            
            # Try to read a test frame to verify the camera works
            ret, test_frame = self.cap.read()
            if not ret or test_frame is None:
                logger.error(f"Camera opened but failed to read test frame: camera_index={self.camera_index}")
                return False
                
            logger.info(f"Successfully read test frame: shape={test_frame.shape}")
            self.is_open = True
            self.frame_count = 0
            self.error_count = 0

            # Additional camera tweaks for better performance
            if hasattr(self.cv2, 'CAP_PROP_BUFFERSIZE'):
                self.cap.set(self.cv2.CAP_PROP_BUFFERSIZE, 1)  # Minimize latency

            return True
        except Exception as e:
            exc_type, exc_value, exc_traceback = sys.exc_info()
            stack_trace = traceback.format_exception(exc_type, exc_value, exc_traceback)
            logger.error(f"Error opening camera: {e}")
            logger.debug(f"Stack trace: {''.join(stack_trace)}")
            return False

    async def get_frame(self):
        if not self.is_open:
            logger.warning("Attempt to get frame from unopened camera")
            return None
        try:
            ret, frame = self.cap.read()
            if not ret or frame is None:
                self.error_count += 1
                # Get camera status for debug info
                is_opened = self.cap.isOpened() if self.cap else False
                
                logger.error(f"Failed to capture frame: camera_index={self.camera_index}, "
                             f"is_open={self.is_open}, cap.isOpened={is_opened}, "
                             f"frame_count={self.frame_count}, error_count={self.error_count}")
                
                # If too many errors, try reopening the camera
                if self.error_count > 5:
                    logger.warning("Too many capture errors, attempting to reopen camera")
                    self.cap.release()
                    await self.open_camera()
                    self.error_count = 0
                
                return None
                
            self.frame_count += 1
            self.error_count = 0  # Reset error count on successful frame capture
            
            # Log occasional frame info
            if self.frame_count % 100 == 0:
                logger.debug(f"Captured frame {self.frame_count}: shape={frame.shape}")
                
            _, jpeg_data = self.cv2.imencode('.jpg', frame)
            return jpeg_data.tobytes()
        except Exception as e:
            exc_type, exc_value, exc_traceback = sys.exc_info()
            stack_trace = traceback.format_exception(exc_type, exc_value, exc_traceback)
            logger.error(f"Error capturing frame: {e}")
            logger.debug(f"Stack trace: {''.join(stack_trace)}")
            return None

    async def close_camera(self):
        if self.cap:
            self.cap.release()
        self.is_open = False
        logger.info(f"Camera closed: camera_index={self.camera_index}, total_frames={self.frame_count}")

class PiCamera2Provider(BaseCameraProvider):
    """Camera provider implementation using PiCamera2."""
    
    def __init__(self):
        super().__init__()
        self.camera = None
        self._check_picamera2()
        
    def _check_picamera2(self):
        try:
            # First try to import from system packages
            from picamera2 import Picamera2
            self.Picamera2 = Picamera2
            logger.info("Using system-installed picamera2")
        except ImportError:
            # Fall back to pip-installed package if available
            try:
                from picamera2 import Picamera2
                self.Picamera2 = Picamera2
                logger.info("Using pip-installed picamera2")
            except ImportError:
                raise ImportError("picamera2 is required for PiCamera2Provider. "
                                  "Install with: sudo apt install -y python3-picamera2 python3-libcamera")

    async def open_camera(self):
        try:
            self.camera = self.Picamera2()
            config = self.camera.create_still_configuration(main={"size": (640, 480)})
            self.camera.configure(config)
            self.camera.start()
            self.is_open = True
            logger.info("Successfully initialized PiCamera2")
            return True
        except Exception as e:
            logger.error(f"Error initializing PiCamera2: {e}")
            return False

    async def get_frame(self):
        if not self.is_open:
            return None
        try:
            # Capture frame and convert to JPEG
            frame = self.camera.capture_array()
            # convert to RGB if needed

            # We need OpenCV to encode the image
            import cv2
            image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            _, jpeg_data = cv2.imencode('.jpg', image)
            return jpeg_data.tobytes()
        except Exception as e:
            logger.error(f"Error capturing frame: {e}")
            return None

    async def close_camera(self):
        if self.camera:
            self.camera.close()
        self.is_open = False
        logger.info("PiCamera2 closed")

# Keep the old PiCamera class for backward compatibility
class PiCameraProvider(BaseCameraProvider):
    """Camera provider implementation using PiCamera (legacy)."""
    
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
            self.stream = io.BytesIO()
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
            self.stream.seek(0)
            self.stream.truncate(0)
            
            # Capture frame directly to memory stream
            self.camera.capture(self.stream, format='jpeg')
            self.stream.seek(0)
            return self.stream.read()
        except Exception as e:
            logger.error(f"Error capturing frame: {e}")
            return None

    async def close_camera(self):
        if self.camera:
            self.camera.close()
        if self.stream:
            self.stream.close()
        self.is_open = False
        logger.info("PiCamera closed")

def create_camera_provider(camera_type='auto', camera_index=0):
    """
    Factory function to create the appropriate camera provider.
    
    Args:
        camera_type (str): Type of camera provider ('opencv', 'picamera', 'picamera2', or 'auto')
        camera_index (int): Camera index for OpenCV provider
        
    Returns:
        BaseCameraProvider: An instance of the appropriate camera provider
    """
    if camera_type == 'picamera2':
        return PiCamera2Provider()
    elif camera_type == 'picamera':
        return PiCameraProvider()
    elif camera_type == 'opencv':
        return OpenCVCameraProvider(camera_index)
    else:  # auto detection
        # Try PiCamera2 first on Raspberry Pi
        try:
            if sys.platform.startswith('linux') and os.path.exists("/proc/device-tree/model"):
                with open("/proc/device-tree/model") as f:
                    if "Raspberry Pi" in f.read():
                        # Check for system-installed picamera2
                        try:
                            import picamera2
                            logger.info("Auto-detected system-installed picamera2")
                            return PiCamera2Provider()
                        except ImportError:
                            pass
        except:
            pass
            
        # Then try PiCamera 
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
            
        raise ImportError("No suitable camera provider found. Please install either OpenCV, PiCamera, or PiCamera2.")