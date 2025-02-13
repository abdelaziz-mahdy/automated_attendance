import cv2
import numpy as np
from abc import ABC, abstractmethod
import logging

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