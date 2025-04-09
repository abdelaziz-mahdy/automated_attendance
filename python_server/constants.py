"""
Constants for the Python Camera Server
"""

class FaceRecognition:
    """Constants related to face recognition."""
    # Threshold values for face similarity comparison
    COSINE_THRESHOLD = 0.33  # Higher values mean more similar (0-1 range) - Lowered from 0.38 to be more lenient
    NORM_L2_THRESHOLD = 1.20  # Lower values mean more similar - Increased from 1.12 to be more lenient
    
    # Confidence threshold for face detection
    DETECTION_CONFIDENCE_THRESHOLD = 0.9
    
    # Tracking timeout (seconds) - Increased to improve tracking consistency
    FACE_TRACKING_TIMEOUT = 2.0
