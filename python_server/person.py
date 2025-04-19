import datetime
import time
import numpy as np
import logging
import os
import cv2

logger = logging.getLogger(__name__)

class Person:
    """Class representing a person detected by face recognition.
    
    This class encapsulates all data related to a recognized face including
    feature vectors, appearance counts, timestamps, and more.
    """
    
    def __init__(self, id, feature_vector=None, is_named=False, thumbnails_dir=None):
        """Initialize a new Person object.
        
        Args:
            id (str): Unique identifier for the person
            feature_vector (numpy.ndarray, optional): Feature vector for face recognition
            is_named (bool): Whether this is a named person (vs auto-generated ID)
            thumbnails_dir (str, optional): Directory to store thumbnails
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
        
        # Store thumbnails as file paths instead of base64 data
        self.thumbnails = []  # List of thumbnail file paths
        self.thumbnail_count = 0
        self.thumbnails_dir = thumbnails_dir
        
        # Create person thumbnail directory if specified
        if self.thumbnails_dir:
            self.person_thumbnails_dir = os.path.join(self.thumbnails_dir, self._get_safe_id())
            os.makedirs(self.person_thumbnails_dir, exist_ok=True)
        else:
            self.person_thumbnails_dir = None
        
        logger.debug(f"Created new Person: {id}, named={is_named}")
    
    def _get_safe_id(self):
        """Get filesystem-safe version of the ID for use in paths."""
        return "".join(c if c.isalnum() else "_" for c in str(self.id))
    
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
        
    def add_thumbnail(self, thumbnail_img):
        """Add a thumbnail image for this person.
        
        Args:
            thumbnail_img (numpy.ndarray): The thumbnail image (cropped face)
            
        Returns:
            str: Path to saved thumbnail file or None if failed
        """
        if self.person_thumbnails_dir is None:
            logger.warning(f"Cannot add thumbnail for {self.id}: No thumbnails directory")
            return None
            
        if thumbnail_img is None or not isinstance(thumbnail_img, np.ndarray):
            logger.warning(f"Invalid thumbnail image for {self.id}")
            return None
            
        try:
            # Create timestamp-based filename
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            filename = f"{timestamp}.jpg"
            filepath = os.path.join(self.person_thumbnails_dir, filename)
            
            # Save thumbnail to file
            cv2.imwrite(filepath, thumbnail_img, [cv2.IMWRITE_JPEG_QUALITY, 80])
            
            # Add filepath to thumbnails list
            self.thumbnails.append(filename)
            
            # Keep only the 5 most recent thumbnails to save space
            if len(self.thumbnails) > 5:
                # Remove oldest thumbnail file
                oldest_file = self.thumbnails.pop(0)
                oldest_path = os.path.join(self.person_thumbnails_dir, oldest_file)
                if os.path.exists(oldest_path):
                    try:
                        os.remove(oldest_path)
                    except Exception as e:
                        logger.warning(f"Failed to remove old thumbnail: {e}")
            
            self.thumbnail_count = len(self.thumbnails)
            return filepath
        except Exception as e:
            logger.error(f"Error saving thumbnail for {self.id}: {e}")
            return None
    
    def get_latest_thumbnail(self):
        """Get the most recent thumbnail file path."""
        if not self.thumbnails or not self.person_thumbnails_dir:
            return None
            
        # Get the latest thumbnail filename
        latest_file = self.thumbnails[-1]
        return os.path.join(self.person_thumbnails_dir, latest_file)
    
    def get_thumbnail_url(self, filename=None):
        """Get a URL path to access the thumbnail via HTTP."""
        if not filename and not self.thumbnails:
            return None
            
        filename = filename or self.thumbnails[-1]  # Use latest if not specified
        
        # Create URL path for access via server
        safe_id = self._get_safe_id()
        return f"/thumbnails/{safe_id}/{filename}"
    
    def get_all_thumbnail_urls(self):
        """Get URLs for all thumbnails."""
        if not self.thumbnails:
            return []
            
        safe_id = self._get_safe_id()
        return [f"/thumbnails/{safe_id}/{filename}" for filename in self.thumbnails]
    
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
        
        # Create dictionary with safe values - store thumbnail filenames instead of data
        return {
            'id': str(self.id),  # Convert ID to string just to be safe
            'is_named': bool(self.is_named),  # Ensure boolean type
            'count': int(self.appearance_count),  # Ensure integer type
            'first_seen': first_seen_str,
            'last_seen': last_seen_str,
            'feature': feature_list,
            'last_box': self.last_box,
            'last_confidence': float(self.last_confidence) if self.last_confidence is not None else None,
            'last_match_score': float(self.last_match_score) if self.last_match_score is not None else None,
            'thumbnails': self.thumbnails,  # Now stores filenames, not base64 data
            'thumbnail_count': self.thumbnail_count
        }
        
    def from_dict(self, data):
        """Update instance from dictionary.
        
        Args:
            data (dict): Dictionary with person data
        """
        if 'feature' in data and data['feature'] is not None:
            # Ensure feature vector is a float32 ndarray (same as what the model produces)
            # This is critical to prevent type mismatches during feature comparison
            self.feature_vector = np.array(data['feature'], dtype=np.float32)
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
        
        # Load thumbnail filenames
        if 'thumbnails' in data and isinstance(data['thumbnails'], list):
            self.thumbnails = data['thumbnails']
            self.thumbnail_count = len(self.thumbnails)
            
            # Make sure thumbnails directory is initialized
            if self.thumbnails_dir:
                self.person_thumbnails_dir = os.path.join(self.thumbnails_dir, self._get_safe_id())
                os.makedirs(self.person_thumbnails_dir, exist_ok=True)
                
                # Validate thumbnail files exist
                valid_thumbnails = []
                for thumbnail in self.thumbnails:
                    thumbnail_path = os.path.join(self.person_thumbnails_dir, thumbnail)
                    if os.path.exists(thumbnail_path):
                        valid_thumbnails.append(thumbnail)
                    else:
                        logger.warning(f"Thumbnail file not found for {self.id}: {thumbnail_path}")
                
                # Update thumbnails list with only valid thumbnails
                if len(valid_thumbnails) != len(self.thumbnails):
                    logger.warning(f"Some thumbnails missing for {self.id}: Found {len(valid_thumbnails)}/{len(self.thumbnails)}")
                    self.thumbnails = valid_thumbnails
                    self.thumbnail_count = len(self.thumbnails)
        elif 'thumbnail_count' in data:
            self.thumbnail_count = data['thumbnail_count']
