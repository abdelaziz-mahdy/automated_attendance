import cv2
import numpy as np
import logging
import os
import time
from constants import FaceRecognition as FR
from face_comparison_service import FaceComparisonService

logger = logging.getLogger(__name__)

class FaceProcessor:
    """Class for handling face detection and recognition using OpenCV and ONNX models."""
    
    def __init__(self):
        self.detection_model = None
        self.recognition_model = None
        self.comparison_service = FaceComparisonService.get_instance()
        self.known_faces = {}  # Dictionary to store known face embeddings
        self.tracked_faces = {}  # Dictionary to track faces across frames
        self.face_appearance_count = {}  # Dictionary to count face appearances
        self.last_face_id = 0  # Counter for generating unique face IDs
        # We're no longer using a tracking timeout - faces will remain in memory indefinitely
        
    def load_models(self, detection_model_path, recognition_model_path):
        """Load the face detection and recognition models."""
        try:
            # Check if models exist
            if not os.path.exists(detection_model_path):
                raise FileNotFoundError(f"Detection model not found at {detection_model_path}")
            if not os.path.exists(recognition_model_path):
                raise FileNotFoundError(f"Recognition model not found at {recognition_model_path}")
                
            # Load YuNet face detection model
            self.detection_model = cv2.FaceDetectorYN.create(
                detection_model_path, 
                "", 
                (320, 320),  # Input size can be adjusted
                FR.DETECTION_CONFIDENCE_THRESHOLD,  # Score threshold
                0.3,  # NMS threshold
                5000  # Top K
            )
            
            # Initialize recognition model in comparison service
            if not self.comparison_service.initialize(recognition_model_path):
                raise Exception("Failed to initialize comparison service")
                
            # Load SFace recognition model for features extraction
            self.recognition_model = cv2.FaceRecognizerSF.create(
                recognition_model_path, 
                ""
            )
            
            logger.info("Face detection and recognition models loaded successfully")
            return True
        except Exception as e:
            logger.error(f"Error loading face models: {e}")
            return False
    
    def _get_next_face_id(self):
        """Generate a unique ID for new faces."""
        self.last_face_id += 1
        return f"Face_{self.last_face_id}"
            
    def detect_faces(self, frame):
        """Detect faces in the frame."""
        if self.detection_model is None:
            logger.error("Detection model not loaded")
            return frame, []
            
        # Set input size
        height, width, _ = frame.shape
        self.detection_model.setInputSize((width, height))
        
        # Detect faces
        faces = self.detection_model.detect(frame)
        
        # If no faces detected, return original frame
        if faces[1] is None:
            return frame, []
            
        # Draw bounding boxes around detected faces
        result_frame = frame.copy()
        detected_faces = []
        
        for face_info in faces[1]:
            # Extract face information
            box = list(map(int, face_info[:4]))
            confidence = face_info[4]
            
            # Only process faces with confidence above threshold
            if confidence < FR.DETECTION_CONFIDENCE_THRESHOLD:
                continue
                
            x, y, w, h = box
            # Draw rectangle around face
            cv2.rectangle(result_frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(result_frame, f"Confidence: {confidence:.2f}", (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            
            # Store face information
            detected_faces.append({
                'box': box,
                'confidence': float(confidence)
            })
            
        return result_frame, detected_faces
    
    def _find_matching_tracked_face(self, face_feature, face_box, now):
        """Find if the current face matches any tracked face."""
        best_match_id = None
        best_match_score = 0.0
        
        # Check for best match among tracked faces
        for face_id, tracked_data in list(self.tracked_faces.items()):
            # We're no longer skipping tracked faces based on timeout
            
            # Check similarity first
            is_similar = self.comparison_service.are_features_similar(
                face_feature, 
                tracked_data['feature'],
                cosine_threshold=FR.COSINE_THRESHOLD,
                norm_l2_threshold=FR.NORM_L2_THRESHOLD
            )
            
            # Only get confidence scores if the faces are similar
            if is_similar:
                # Get the cosine score for ranking matches
                cosine_score = self.comparison_service.calculate_cosine_distance(
                    face_feature, tracked_data['feature'])
                
                if cosine_score > best_match_score:
                    best_match_id = face_id
                    best_match_score = cosine_score
        
        return best_match_id, best_match_score
    
    def _find_matching_known_face(self, face_feature):
        """Find if the current face matches any known face in database."""
        best_match_id = None
        best_cosine_score = 0.0
        best_norm_l2_score = float('inf')
        
        # Check each known face for a match
        for known_id, known_feature in self.known_faces.items():
            # Check similarity first
            is_similar = self.comparison_service.are_features_similar(
                face_feature, 
                known_feature,
                cosine_threshold=FR.COSINE_THRESHOLD,
                norm_l2_threshold=FR.NORM_L2_THRESHOLD
            )
            
            # Only get confidence scores if the faces are similar
            if is_similar:
                # Get the confidence scores for ranking matches
                cosine_score = self.comparison_service.calculate_cosine_distance(
                    face_feature, known_feature)
                norm_l2_score = self.comparison_service.calculate_norm_l2_distance(
                    face_feature, known_feature)
                
                if cosine_score > best_cosine_score:
                    best_match_id = known_id
                    best_cosine_score = cosine_score
                    best_norm_l2_score = norm_l2_score
        
        return best_match_id, (best_cosine_score, best_norm_l2_score)
    
    def get_face_counts(self):
        """Return the count of appearances for each tracked face."""
        return self.face_appearance_count
    
    def get_known_faces(self):
        """Return dictionary of known faces and their count.
        
        Returns:
            dict: Dictionary with face IDs as keys and dicts with 'count' and 'feature' as values
        """
        result = {}
        for face_id in self.known_faces:
            result[face_id] = {
                'count': self.face_appearance_count.get(face_id, 0),
                'feature': self.known_faces[face_id].tolist()  # Convert to list for JSON serialization
            }
        return result
        
    def merge_faces(self, source_face_id, target_face_id):
        """Merge two face entries, combining their appearance counts and keeping the target face.
        
        Args:
            source_face_id (str): ID of the source face to merge from
            target_face_id (str): ID of the target face to merge into
            
        Returns:
            bool: True if merge was successful, False otherwise
        """
        # Check if both faces exist - with better error handling
        source_exists = source_face_id in self.known_faces
        target_exists = target_face_id in self.known_faces
        
        if not source_exists and not target_exists:
            logger.error(f"Cannot merge: both face IDs don't exist in known faces")
            return False
        
        # If only one face exists, log but continue with available data
        if not source_exists:
            logger.warning(f"Source face ID '{source_face_id}' not found in known faces, attempting to find it in tracked faces")
            # Try to find the source face in tracked faces
            for tracked_id, tracked_data in list(self.tracked_faces.items()):
                if tracked_id == source_face_id:
                    # Add the tracked face to known faces so we can merge it
                    self.known_faces[source_face_id] = tracked_data['feature']
                    source_exists = True
                    logger.info(f"Found source face '{source_face_id}' in tracked faces and added to known faces")
                    break
            
            if not source_exists:
                logger.error(f"Source face ID '{source_face_id}' not found in tracked faces either, cannot merge")
                return False
                
        if not target_exists:
            logger.warning(f"Target face ID '{target_face_id}' not found in known faces, attempting to find it in tracked faces")
            # Try to find the target face in tracked faces
            for tracked_id, tracked_data in list(self.tracked_faces.items()):
                if tracked_id == target_face_id:
                    # Add the tracked face to known faces so we can merge into it
                    self.known_faces[target_face_id] = tracked_data['feature']
                    target_exists = True
                    logger.info(f"Found target face '{target_face_id}' in tracked faces and added to known faces")
                    break
            
            if not target_exists:
                logger.error(f"Target face ID '{target_face_id}' not found in tracked faces either, cannot merge")
                return False
            
        # Transfer appearance count
        if source_face_id in self.face_appearance_count:
            if target_face_id not in self.face_appearance_count:
                self.face_appearance_count[target_face_id] = self.face_appearance_count[source_face_id]
            else:
                self.face_appearance_count[target_face_id] += self.face_appearance_count[source_face_id]
            
            # Remove source face count
            del self.face_appearance_count[source_face_id]
        
        # Remove source face from known faces
        del self.known_faces[source_face_id]
        
        # Also remove from tracked faces if present
        if source_face_id in self.tracked_faces:
            del self.tracked_faces[source_face_id]
        
        logger.info(f"Successfully merged face '{source_face_id}' into '{target_face_id}'")
        return True
    
    def recognize_faces(self, frame):
        """Detect and recognize faces in the frame."""
        if self.detection_model is None or self.recognition_model is None:
            logger.error("Detection or recognition model not loaded")
            return frame, []
            
        # First detect faces
        height, width, _ = frame.shape
        self.detection_model.setInputSize((width, height))
        faces = self.detection_model.detect(frame)
        
        # If no faces detected, return original frame
        if faces[1] is None:
            return frame, []
            
        result_frame = frame.copy()
        recognized_faces = []
        current_time = time.time()
        
        # We're no longer cleaning up expired tracked faces - they remain in memory
        
        for face_info in faces[1]:
            # Extract face information
            box = list(map(int, face_info[:4]))
            confidence = face_info[4]
            
            # Only process faces with confidence above threshold
            if confidence < FR.DETECTION_CONFIDENCE_THRESHOLD:
                continue
                
            x, y, w, h = box
            
            # Extract aligned face for recognition
            aligned_face = self.recognition_model.alignCrop(frame, face_info)
            
            # Get face feature
            face_feature = self.recognition_model.feature(aligned_face)
            
            # First, try to match with tracked faces to maintain consistent ID
            tracked_face_id, tracked_match_score = self._find_matching_tracked_face(
                face_feature, box, current_time)
            
            # If we found a tracked face match, use that ID
            if tracked_face_id:
                face_id = tracked_face_id
                named_person = face_id in self.known_faces
                match_confidence = tracked_match_score
                
                # Update the tracked face with new data
                self.tracked_faces[face_id] = {
                    'feature': face_feature,
                    'box': box,
                    'last_seen': current_time
                }
                
                # Increment appearance count
                if face_id not in self.face_appearance_count:
                    self.face_appearance_count[face_id] = 1
                else:
                    self.face_appearance_count[face_id] += 1
            else:
                # If no tracked face matches, check against known faces in database
                named_person = False
                face_id = None
                match_confidence = 0.0
                match_scores = (0.0, float('inf'))
                
                # Use the dedicated method to find matching known face
                known_face_id, match_scores = self._find_matching_known_face(face_feature)
                
                if known_face_id:
                    face_id = known_face_id
                    named_person = True
                    match_confidence = match_scores[0]  # Cosine score
                
                # If still no match, assign new face ID
                if not face_id:
                    face_id = self._get_next_face_id()
                    match_confidence = 0.0
                
                # Add or update this face in tracking
                self.tracked_faces[face_id] = {
                    'feature': face_feature,
                    'box': box,
                    'last_seen': current_time
                }
                
                # Initialize appearance count
                if face_id not in self.face_appearance_count:
                    self.face_appearance_count[face_id] = 1
                else:
                    self.face_appearance_count[face_id] += 1
            
            # Color based on recognition status
            if named_person:
                color = (0, 255, 0)  # Green for recognized named people
            else:
                color = (0, 165, 255)  # Orange for tracked but unnamed faces
            
            # Get appearance count
            appearance_count = self.face_appearance_count.get(face_id, 1)
            
            # Draw rectangle and label with more detailed information
            cv2.rectangle(result_frame, (x, y), (x + w, y + h), color, 2)
            
            # Display more informative labels for better UI
            if named_person:
                label = f"{face_id}"
                sub_label = f"Seen {appearance_count} times"
            else:
                label = f"{face_id}"
                sub_label = f"Confidence: {match_confidence:.2f}"
                
            # Draw main label
            cv2.putText(result_frame, label, (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
            
            # Draw sub-label
            cv2.putText(result_frame, sub_label, (x, y + h + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
            
            # Store recognized face information with count and timestamp
            recognized_faces.append({
                'box': box,
                'confidence': float(confidence),
                'id': face_id,
                'match_score': float(match_confidence),
                'named_person': named_person,
                'appearance_count': appearance_count,
                'last_seen': current_time  # Add timestamp to sort by recency
            })
        
        # Sort the recognized faces by recency (newest first)
        # This ensures new faces appear first in the UI
        recognized_faces.sort(key=lambda face: face['last_seen'], reverse=True)
            
        return result_frame, recognized_faces
        
    def add_face(self, frame, face_id):
        """Add a face to the known faces database."""
        if self.detection_model is None or self.recognition_model is None:
            logger.error("Detection or recognition model not loaded")
            return False
            
        # Detect faces in the frame
        height, width, _ = frame.shape
        self.detection_model.setInputSize((width, height))
        faces = self.detection_model.detect(frame)
        
        if faces[1] is None or len(faces[1]) == 0:
            logger.error("No face detected for registration")
            return False
            
        # Use the first (hopefully only) face
        face_info = faces[1][0]
        
        # Extract confidence
        confidence = face_info[4]
        if confidence < FR.DETECTION_CONFIDENCE_THRESHOLD:
            logger.error(f"Face confidence too low for registration: {confidence}")
            return False
        
        # Align and extract face feature
        aligned_face = self.recognition_model.alignCrop(frame, face_info)
        face_feature = self.recognition_model.feature(aligned_face)
        
        # Check if this face is similar to any existing known face
        matching_face_id, similarity_scores = self._find_matching_known_face(face_feature)
        
        if matching_face_id is not None:
            logger.info(f"Face similar to existing face '{matching_face_id}' with similarity {similarity_scores[0]:.2f}")
            # We'll continue adding it but notify caller about similarity
            
        # Store the face feature
        self.known_faces[face_id] = face_feature
        logger.info(f"Added face with ID: {face_id}")
        
        # If this face is similar to a tracked face, update the tracking data
        current_time = time.time()
        for tracked_id, tracked_data in list(self.tracked_faces.items()):
            if tracked_id.startswith("Face_"):  # Only update auto-generated IDs
                is_similar = self.comparison_service.are_features_similar(
                    face_feature, tracked_data['feature'],
                    FR.COSINE_THRESHOLD, FR.NORM_L2_THRESHOLD)
                
                if is_similar:
                    # Transfer appearance count to the named face
                    if tracked_id in self.face_appearance_count:
                        if face_id not in self.face_appearance_count:
                            self.face_appearance_count[face_id] = self.face_appearance_count[tracked_id]
                        else:
                            self.face_appearance_count[face_id] += self.face_appearance_count[tracked_id]
                        del self.face_appearance_count[tracked_id]
                    
                    # Remove the auto-generated entry
                    del self.tracked_faces[tracked_id]
                    logger.info(f"Updated tracking information for newly named face: {face_id}")
        
        return True
