import datetime
import time
import numpy as np
import logging

logger = logging.getLogger(__name__)

class Person:
    """Class representing a person detected by face recognition.
    
    This class encapsulates all data related to a recognized face including
    feature vectors, appearance counts, timestamps, and more.
    """
    
    def __init__(self, id, feature_vector=None, is_named=False):
        """Initialize a new Person object.
        
        Args:
            id (str): Unique identifier for the person
            feature_vector (numpy.ndarray, optional): Feature vector for face recognition
            is_named (bool): Whether this is a named person (vs auto-generated ID)
        """
        self.id = id
        self.feature_vector = feature_vector
        self.is_named = is_named
        self.appearance_count = 0
        
        # Timestamp tracking
        self.first_seen = datetime.datetime.now()
        self.last_seen = self.first_seen
        
        # Face detection data (last detected location)
        self.last_box = None  # [x, y, width, height]
        self.last_confidence = 0.0
        
        # Recognition scoring
        self.last_match_score = 0.0
        
        # Associated thumbnails (not stored in this class, just for reference)
        self.thumbnail_count = 0
        
        logger.debug(f"Created new Person: {id}, named={is_named}")
    
    def update_feature(self, feature_vector):
        """Update the person's feature vector.
        
        Args:
            feature_vector (numpy.ndarray): New feature vector
        """
        # If we don't have a feature vector yet, just set it
        if self.feature_vector is None:
            self.feature_vector = feature_vector
            return
            
        # Otherwise, we could do a weighted average to slowly evolve the feature
        # This helps the face adapt to different conditions over time
        # The weight for the new feature can be adjusted (0.3 gives 30% weight to new)
        weight = 0.3  
        self.feature_vector = (1 - weight) * self.feature_vector + weight * feature_vector
        
    def increment_count(self):
        """Increment appearance count."""
        self.appearance_count += 1
        
    def update_last_seen(self, timestamp=None):
        """Update last seen timestamp.
        
        Args:
            timestamp (datetime.datetime, optional): Specific timestamp to use
        """
        self.last_seen = timestamp or datetime.datetime.now()
        
    def update_detection(self, box, confidence):
        """Update detection information.
        
        Args:
            box (list): Bounding box [x, y, width, height]
            confidence (float): Detection confidence
        """
        self.last_box = box
        self.last_confidence = confidence
        
    def update_match(self, match_score):
        """Update match score.
        
        Args:
            match_score (float): Recognition match score
        """
        self.last_match_score = match_score
        
    def to_dict(self):
        """Convert to dictionary for JSON serialization."""
        # Safely convert feature vector to list
        feature_list = None
        if self.feature_vector is not None:
            try:
                feature_list = self.feature_vector.tolist()
            except Exception as e:
                logger.error(f"Error converting feature vector to list: {e}")
                # Fallback to a string representation or None
                feature_list = str(self.feature_vector)
        
        # Safely format datetime objects
        first_seen_str = None
        if self.first_seen:
            try:
                first_seen_str = self.first_seen.isoformat()
            except Exception as e:
                logger.error(f"Error formatting first_seen datetime: {e}")
                first_seen_str = str(self.first_seen)
        
        last_seen_str = None
        if self.last_seen:
            try:
                last_seen_str = self.last_seen.isoformat()
            except Exception as e:
                logger.error(f"Error formatting last_seen datetime: {e}")
                last_seen_str = str(self.last_seen)
        
        # Create dictionary with safe values
        return {
            'id': str(self.id),  # Convert ID to string just to be safe
            'is_named': bool(self.is_named),  # Ensure boolean type
            'count': int(self.appearance_count),  # Ensure integer type
            'first_seen': first_seen_str,
            'last_seen': last_seen_str,
            'feature': feature_list,
            'last_box': self.last_box,
            'last_confidence': float(self.last_confidence) if self.last_confidence is not None else None,
            'last_match_score': float(self.last_match_score) if self.last_match_score is not None else None
        }
        
    def from_dict(self, data):
        """Update instance from dictionary.
        
        Args:
            data (dict): Dictionary with person data
        """
        if 'feature' in data and data['feature'] is not None:
            self.feature_vector = np.array(data['feature'])
        if 'is_named' in data:
            self.is_named = data['is_named']
        if 'count' in data:
            self.appearance_count = data['count']
        if 'first_seen' in data and data['first_seen']:
            self.first_seen = datetime.datetime.fromisoformat(data['first_seen'])
        if 'last_seen' in data and data['last_seen']:
            self.last_seen = datetime.datetime.fromisoformat(data['last_seen'])
        if 'last_box' in data:
            self.last_box = data['last_box']
        if 'last_confidence' in data:
            self.last_confidence = data['last_confidence']
        if 'last_match_score' in data:
            self.last_match_score = data['last_match_score']
