import cv2
import numpy as np
from abc import ABC, abstractmethod

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
        
    async def open_camera(self) -> bool:
        try:
            self._capture = cv2.VideoCapture(self.camera_index)
            if self._capture.isOpened():
                self._is_open = True
                return True
        except Exception as e:
            print(f"Error opening camera: {e}")
        return False
    
    async def close_camera(self):
        if self._is_open and self._capture:
            self._capture.release()
            self._is_open = False
    
    async def get_frame(self) -> bytes:
        if not self._is_open:
            return None
        
        ret, frame = self._capture.read()
        if not ret:
            return None
            
        _, buffer = cv2.imencode('.jpg', frame)
        return buffer.tobytes()
    
    @property
    def is_open(self) -> bool:
        return self._is_open