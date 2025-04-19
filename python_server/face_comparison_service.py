import cv2
import numpy as np
import logging

logger = logging.getLogger(__name__)

class FaceComparisonService:
    """Singleton service that handles face feature comparison."""
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = FaceComparisonService()
        return cls._instance
        
    def __init__(self):
        self._recognizer = None
        self.is_initialized = False
        
    def initialize(self, model_path):
        """Initialize the face recognizer with the provided model."""
        try:
            # Initialize SFace recognizer from OpenCV
            self._recognizer = cv2.FaceRecognizerSF.create(
                model_path, 
                ""  # Empty config string
            )
            self.is_initialized = True
            return True
        except Exception as e:
            logger.error(f"Error initializing face recognizer: {e}")
            self.is_initialized = False
            return False
    
    def _ensure_feature_type(self, feature):
        """Ensure feature vector has consistent data type.
        
        Args:
            feature: Feature vector to check/convert
            
        Returns:
            numpy.ndarray: Feature vector with correct dtype
        """
        if not isinstance(feature, np.ndarray):
            logger.warning("Feature is not a numpy array, converting")
            feature = np.array(feature)
            
        # Always ensure features are float32, which is what OpenCV uses internally
        # This prevents type mismatch errors when comparing features
        if feature.dtype != np.float32:
            logger.debug(f"Converting feature from {feature.dtype} to float32")
            feature = feature.astype(np.float32)
            
        return feature
        
    def are_features_similar(self, feature1, feature2, cosine_threshold=0.363, norm_l2_threshold=1.128):
        """Determine if two faces are similar based on their feature vectors.
        
        Args:
            feature1 (numpy.ndarray): First face feature vector
            feature2 (numpy.ndarray): Second face feature vector
            cosine_threshold (float): Threshold for cosine similarity (higher is more similar)
            norm_l2_threshold (float): Threshold for L2 norm distance (lower is more similar)
            
        Returns:
            bool: True if the faces are similar based on either metric
        """
        if not self.is_initialized:
            logger.error("Face comparison service not initialized")
            return False
            
        try:
            # Ensure features have consistent data types
            feature1 = self._ensure_feature_type(feature1)
            feature2 = self._ensure_feature_type(feature2)
            
            # Calculate cosine similarity (higher is more similar)
            cosine_distance = self.calculate_cosine_distance(feature1, feature2)
            
            # Calculate L2 norm distance (lower is more similar)
            norm_distance = self.calculate_norm_l2_distance(feature1, feature2)
            
            # Faces are similar if either metric indicates similarity
            is_similar = (cosine_distance >= cosine_threshold or norm_distance <= norm_l2_threshold)
            
            return is_similar
        except Exception as e:
            logger.error(f"Error comparing features: {e}")
            return False
    
    def calculate_cosine_distance(self, feature1, feature2):
        """Calculate cosine similarity between two feature vectors.
        
        Args:
            feature1 (numpy.ndarray): First feature vector
            feature2 (numpy.ndarray): Second feature vector
            
        Returns:
            float: Cosine similarity score (higher means more similar)
        """
        try:
            # Ensure features have consistent data types
            feature1 = self._ensure_feature_type(feature1)
            feature2 = self._ensure_feature_type(feature2)
            
            # Use OpenCV's built-in match function with cosine distance metric
            return self._recognizer.match(feature1, feature2, cv2.FaceRecognizerSF_FR_COSINE)
        except Exception as e:
            logger.error(f"Error calculating cosine distance: {e}")
            
            # Fallback to manual calculation if OpenCV method fails
            try:
                dot_product = np.dot(feature1, feature2)
                norm1 = np.linalg.norm(feature1)
                norm2 = np.linalg.norm(feature2)
                
                if norm1 == 0 or norm2 == 0:
                    return 0
                    
                return dot_product / (norm1 * norm2)
            except Exception as e2:
                logger.error(f"Fallback cosine calculation also failed: {e2}")
                return 0
    
    def calculate_norm_l2_distance(self, feature1, feature2):
        """Calculate L2 norm distance between two feature vectors.
        
        Args:
            feature1 (numpy.ndarray): First feature vector
            feature2 (numpy.ndarray): Second feature vector
            
        Returns:
            float: L2 norm distance (lower means more similar)
        """
        try:
            # Ensure features have consistent data types
            feature1 = self._ensure_feature_type(feature1)
            feature2 = self._ensure_feature_type(feature2)
            
            # Use OpenCV's built-in match function with L2 norm metric
            return self._recognizer.match(feature1, feature2, cv2.FaceRecognizerSF_FR_NORM_L2)
        except Exception as e:
            logger.error(f"Error calculating L2 norm: {e}")
            
            # Fallback to manual calculation if OpenCV method fails
            try:
                return np.linalg.norm(feature1 - feature2)
            except Exception as e2:
                logger.error(f"Fallback L2 norm calculation also failed: {e2}")
                return float('inf')  # Return worst case (infinity) if calculation fails