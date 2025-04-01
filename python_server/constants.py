"""
Constants for the Python Camera Server
"""

class FaceRecognition:
    """Constants related to face recognition."""
    # Threshold values for face similarity comparison
    COSINE_THRESHOLD = 0.38  # Higher values mean more similar (0-1 range)
    NORM_L2_THRESHOLD = 1.12  # Lower values mean more similar
    
    # Confidence threshold for face detection
    DETECTION_CONFIDENCE_THRESHOLD = 0.9
    
    # Tracking timeout (seconds)
    FACE_TRACKING_TIMEOUT = 1.0
