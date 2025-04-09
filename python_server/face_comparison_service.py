import cv2
import numpy as np
import logging

logger = logging.getLogger(__name__)

class FaceComparisonService:
    """Service for comparing face features using OpenCV's face recognition models.
    
    This class mirrors the functionality of the Dart implementation in face_comparison_service.dart.
    """
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """Singleton getter for FaceComparisonService."""
        if cls._instance is None:
            cls._instance = FaceComparisonService()
        return cls._instance
    
    def __init__(self):
        self._recognizer = None
        
    def initialize(self, model_path):
        """Initialize the face recognizer with the given model.
        
        Args:
            model_path (str): Path to the face recognition model.
            
        Returns:
            bool: True if initialization was successful, False otherwise.
        """
        try:
            self._recognizer = cv2.FaceRecognizerSF.create(model_path, "")
            logger.info(f"Face recognizer initialized with model: {model_path}")
            return True
        except Exception as e:
            logger.error(f"Error initializing face recognizer: {e}")
            return False
            
    def are_features_similar(self, feature1, feature2, cosine_threshold=0.38, norm_l2_threshold=1.12):
        """Check if two face features are similar based on thresholds.
        
        Args:
            feature1: First face feature vector
            feature2: Second face feature vector
            cosine_threshold (float): Threshold for cosine similarity (higher means more similar)
            norm_l2_threshold (float): Threshold for L2 norm distance (lower means more similar)
            
        Returns:
            bool: True if features are similar, False otherwise
        """
        if self._recognizer is None:
            logger.error("Face recognizer not initialized")
            return False
            
        cosine_distance = self.calculate_cosine_distance(feature1, feature2)
        norm_l2_distance = self.calculate_norm_l2_distance(feature1, feature2)
        
        return (cosine_distance >= cosine_threshold and 
                norm_l2_distance <= norm_l2_threshold)
                
    def get_confidence(self, feature1, feature2):
        """Calculate confidence scores between two feature vectors.
        
        Args:
            feature1: First face feature vector
            feature2: Second face feature vector
            
        Returns:
            tuple: (cosine_distance, norm_l2_distance) tuple with confidence scores
        """
        if self._recognizer is None:
            logger.error("Face recognizer not initialized")
            return (0.0, float('inf'))
            
        cosine_distance = self.calculate_cosine_distance(feature1, feature2)
        norm_l2_distance = self.calculate_norm_l2_distance(feature1, feature2)
        
        return (cosine_distance, norm_l2_distance)
        
    def calculate_cosine_distance(self, feature1, feature2):
        """Calculate cosine distance between two feature vectors.
        
        Args:
            feature1: First face feature vector
            feature2: Second face feature vector
            
        Returns:
            float: Cosine distance (higher means more similar)
        """
        return self._recognizer.match(feature1, feature2, cv2.FaceRecognizerSF_FR_COSINE)
        
    def calculate_norm_l2_distance(self, feature1, feature2):
        """Calculate L2 norm distance between two feature vectors.
        
        Args:
            feature1: First face feature vector
            feature2: Second face feature vector
            
        Returns:
            float: L2 norm distance (lower means more similar)
        """
        return self._recognizer.match(feature1, feature2, cv2.FaceRecognizerSF_FR_NORM_L2)