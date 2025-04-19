import cv2
import numpy as np
import logging
import os
import time
import uuid
import datetime
from constants import FaceRecognition as FR
from face_comparison_service import FaceComparisonService
from face_memory import FaceMemory
from person import Person

logger = logging.getLogger(__name__)

class FaceProcessor:
    """Class for handling face detection and recognition using OpenCV and ONNX models."""
    
    def __init__(self, storage_dir=None):
        self.detection_model = None
        self.recognition_model = None
        self.comparison_service = FaceComparisonService.get_instance()
        
        # Replace all dictionaries with FaceMemory
        self.memory = FaceMemory(storage_dir=storage_dir or os.path.join(os.path.dirname(__file__), 'data'))
        
        # Get the local timezone for accurate timestamp tracking
        self.local_timezone = self._get_local_timezone()
        
        # Add instance variable for tracking save request time
        self._last_save_request_time = 0
        
        # Add face count threshold to reduce save frequency
        self._face_updates_since_save = 0
        self._face_update_threshold = 10  # Only save after this many face updates
    
    def _get_local_timezone(self):
        """Get the local timezone for accurate timestamp tracking."""
        try:
            local_timezone = datetime.datetime.now(datetime.timezone.utc).astimezone().tzinfo
            return local_timezone
        except Exception as e:
            logger.warning(f"Error getting local timezone: {e}. Falling back to UTC.")
            return datetime.timezone.utc
    
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
        unique_id = str(uuid.uuid4())[:8]  # Use just the first 8 characters for brevity
        return f"Face_{unique_id}"
            
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
    
    def _find_matching_tracked_face(self, face_feature, face_box):
        """Find if the current face matches any tracked face."""
        best_match_id = None
        best_match_score = 0.0
        
        # Check all people in memory
        for person_id, person in self.memory.get_all_people().items():
            if person.feature_vector is None:
                continue
                
            # Check similarity
            is_similar = self.comparison_service.are_features_similar(
                face_feature, 
                person.feature_vector,
                cosine_threshold=FR.COSINE_THRESHOLD,
                norm_l2_threshold=FR.NORM_L2_THRESHOLD
            )
            
            # Only get confidence scores if the faces are similar
            if is_similar:
                # Get the cosine score for ranking matches
                cosine_score = self.comparison_service.calculate_cosine_distance(
                    face_feature, person.feature_vector)
                
                if cosine_score > best_match_score:
                    best_match_id = person_id
                    best_match_score = cosine_score
        
        return best_match_id, best_match_score
    
    def _find_matching_known_face(self, face_feature):
        """Find if the current face matches any named person in memory."""
        best_match_id = None
        best_cosine_score = 0.0
        best_norm_l2_score = float('inf')
        
        # Check each named person for a match
        for person_id, person in self.memory.get_all_people().items():
            if not person.is_named or person.feature_vector is None:
                continue
                
            # Check similarity first
            is_similar = self.comparison_service.are_features_similar(
                face_feature, 
                person.feature_vector,
                cosine_threshold=FR.COSINE_THRESHOLD,
                norm_l2_threshold=FR.NORM_L2_THRESHOLD
            )
            
            # Only get confidence scores if the faces are similar
            if is_similar:
                # Get the confidence scores for ranking matches
                cosine_score = self.comparison_service.calculate_cosine_distance(
                    face_feature, person.feature_vector)
                norm_l2_score = self.comparison_service.calculate_norm_l2_distance(
                    face_feature, person.feature_vector)
                
                if cosine_score > best_cosine_score:
                    best_match_id = person_id
                    best_cosine_score = cosine_score
                    best_norm_l2_score = norm_l2_score
        
        return best_match_id, (best_cosine_score, best_norm_l2_score)
    
    def get_face_counts(self):
        """Return the count of appearances for each tracked face."""
        result = {}
        for person_id, person in self.memory.get_all_people().items():
            result[person_id] = person.appearance_count
        return result
    
    def get_first_seen_time(self, face_id):
        """Get the timestamp when face was first seen, or None if not tracked."""
        person = self.memory.get_person(face_id)
        if person and person.first_seen:
            # Return as ISO formatted string for JSON compatibility
            return person.first_seen.isoformat()
        return None
        
    def get_last_seen_time(self, face_id):
        """Get the timestamp when face was last seen, or None if not tracked."""
        person = self.memory.get_person(face_id)
        if person and person.last_seen:
            # Return as ISO formatted string for JSON compatibility
            return person.last_seen.isoformat()
        return None
    
    def get_known_faces(self):
        """Return dictionary of known faces and their count."""
        result = {}
        for person_id, person in self.memory.get_all_people().items():
            if person.is_named:
                result[person_id] = {
                    'count': person.appearance_count,
                    'feature': person.feature_vector.tolist() if person.feature_vector is not None else None,
                    'first_seen': self.get_first_seen_time(person_id),
                    'last_seen': self.get_last_seen_time(person_id)
                }
        return result
        
    def merge_faces(self, source_face_id, target_face_id):
        """Merge two face entries, combining their appearance counts and keeping the target face."""
        return self.memory.merge_people(source_face_id, target_face_id)
    
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
        current_datetime = datetime.datetime.now(self.local_timezone)
        
        # Track if we made any updates that require saving
        made_updates = False
        
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
            tracked_face_id, tracked_match_score = self._find_matching_tracked_face(face_feature, box)
            
            # Create a thumbnail from the face region
            thumbnail_img = self._create_thumbnail_from_face(frame, face_info)
            
            # If we found a tracked face match, use that ID
            if tracked_face_id:
                face_id = tracked_face_id
                person = self.memory.get_person(face_id)
                named_person = person.is_named if person else False
                match_confidence = tracked_match_score
                
                # Update the person with new data
                self.memory.update_person(
                    face_id, 
                    feature_vector=face_feature,
                    box=box,
                    confidence=confidence,
                    match_score=match_confidence,
                    increment_count=True
                )
                
                # Add thumbnail to person if available
                if thumbnail_img is not None and person:
                    person.add_thumbnail(thumbnail_img)
                    
                made_updates = True
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
                    
                    # Update the known person
                    person = self.memory.update_person(
                        face_id, 
                        feature_vector=face_feature,
                        box=box,
                        confidence=confidence,
                        match_score=match_confidence,
                        increment_count=True
                    )
                    
                    # Add thumbnail to person if available
                    if thumbnail_img is not None and person:
                        person.add_thumbnail(thumbnail_img)
                        
                    made_updates = True
                
                # If still no match, assign new face ID
                if not face_id:
                    face_id = self._get_next_face_id()
                    match_confidence = 0.0
                    
                    # Add new person to memory
                    person = self.memory.add_person(
                        face_id, 
                        feature_vector=face_feature,
                        is_named=False
                    )
                    
                    # Update with detection info
                    self.memory.update_person(
                        face_id,
                        box=box,
                        confidence=confidence,
                        increment_count=False  # Already set to 1 when created
                    )
                    
                    # Add thumbnail to the new person
                    if thumbnail_img is not None and person:
                        person.add_thumbnail(thumbnail_img)
                        
                    made_updates = True
            
            # Get the person for UI display
            person = self.memory.get_person(face_id)
            if not person:
                continue  # Skip if person not found (shouldn't happen)
                
            # Color based on recognition status
            if named_person:
                color = (0, 255, 0)  # Green for recognized named people
            else:
                color = (0, 165, 255)  # Orange for tracked but unnamed faces
            
            # Get appearance count
            appearance_count = person.appearance_count
            
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
                'last_seen': current_time,  # Add timestamp to sort by recency
                'first_seen': self.get_first_seen_time(face_id),
                'last_seen_formatted': self.get_last_seen_time(face_id),
                'thumbnail_url': person.get_thumbnail_url() if person else None
            })
        
        # Sort the recognized faces by recency (newest first)
        recognized_faces.sort(key=lambda face: face['last_seen'], reverse=True)
        
        # Optimize save request logic to reduce system load
        if made_updates and len(recognized_faces) > 0:
            # Increment counter for face updates
            self._face_updates_since_save += 1
            
            # Only request a save under these conditions:
            # 1. It's been at least 45 seconds since last save request (increased from 30)
            # 2. OR we've accumulated enough face updates to justify a save
            current_time = time.time()
            time_since_last_save = current_time - self._last_save_request_time
            
            if (time_since_last_save > 45 or self._face_updates_since_save >= self._face_update_threshold):
                logger.debug(f"Requesting save after {self._face_updates_since_save} updates and {time_since_last_save:.1f}s")
                self.memory.request_save()
                self._last_save_request_time = current_time
                self._face_updates_since_save = 0  # Reset counter
            
        return result_frame, recognized_faces
        
    def detect_best_face(self, img):
        """Detect the face with the highest confidence in an image."""
        if self.detection_model is None:
            logger.error("Detection model not loaded")
            return None, 0
            
        # Set input size for detection
        height, width, _ = img.shape
        self.detection_model.setInputSize((width, height))
        
        # Detect faces
        faces = self.detection_model.detect(img)
        
        # If no faces detected, return None
        if faces[1] is None or len(faces[1]) == 0:
            return None, 0
        
        # Find face with highest confidence
        best_face = None
        best_confidence = -1
        
        for face_info in faces[1]:
            confidence = face_info[4]
            if confidence > best_confidence:
                best_face = face_info
                best_confidence = confidence
                
        return best_face, best_confidence
    
    def extract_face_feature(self, img, face_info):
        """Extract face features from aligned face."""
        if self.recognition_model is None:
            logger.error("Recognition model not loaded")
            return None
            
        try:
            # Align and extract face
            aligned_face = self.recognition_model.alignCrop(img, face_info)
            face_feature = self.recognition_model.feature(aligned_face)
            return face_feature
        except Exception as e:
            logger.error(f"Error extracting face feature: {e}")
            return None
    
    def add_face(self, frame, face_id):
        """Add a face to the known faces database."""
        if self.detection_model is None or self.recognition_model is None:
            logger.error("Detection or recognition model not loaded")
            return False
            
        # Use shared method to detect the best face  
        face_info, confidence = self.detect_best_face(frame)
        
        if face_info is None or confidence < FR.DETECTION_CONFIDENCE_THRESHOLD:
            logger.error(f"No suitable face detected for registration. Confidence: {confidence}")
            return False
        
        # Use shared method to extract features
        face_feature = self.extract_face_feature(frame, face_info)
        if face_feature is None:
            logger.error("Failed to extract face features")
            return False
            
        # Check if this face is similar to any existing known face
        matching_face_id, similarity_scores = self._find_matching_known_face(face_feature)
        
        if matching_face_id is not None:
            logger.info(f"Face similar to existing face '{matching_face_id}' with similarity {similarity_scores[0]:.2f}")
            # We'll continue adding it but notify caller about similarity
            
        # If person already exists, update them, otherwise add new
        existing_person = self.memory.get_person(face_id)
        if existing_person:
            self.memory.update_person(
                face_id,
                feature_vector=face_feature,
                increment_count=True
            )
        else:
            self.memory.add_person(
                face_id,
                feature_vector=face_feature,
                is_named=True  # This is a named person since we're adding it explicitly
            )
        
        # Check if this face is similar to any existing tracked face
        # and merge if appropriate - but only for unnamed faces
        for person_id, person in self.memory.get_all_people().items():
            if person.is_named or person_id == face_id:
                continue  # Skip named people and the face we just added
                
            if person.feature_vector is None:
                continue
                
            is_similar = self.comparison_service.are_features_similar(
                face_feature, 
                person.feature_vector,
                FR.COSINE_THRESHOLD, 
                FR.NORM_L2_THRESHOLD
            )
            
            if is_similar:
                logger.info(f"Merging similar unnamed face {person_id} into {face_id}")
                self.memory.merge_people(person_id, face_id)
        
        # Save changes to disk
        self.memory.request_save()
        
        logger.info(f"Successfully added face: {face_id}")
        return True

    def process_imported_face_image(self, img, person_name):
        """Process a single face image for batch import and add to known faces."""
        try:
            # Ensure models are loaded
            if self.detection_model is None or self.recognition_model is None:
                logger.error("Face models not loaded, cannot process imported image.")
                # Attempt to load models if not already loaded
                assets_dir = os.path.join(os.path.dirname(__file__),'..', 'assets')
                detection_model_path = os.path.join(assets_dir, 'face_detection_yunet_2023mar.onnx')
                recognition_model_path = os.path.join(assets_dir, 'face_recognition_sface_2021dec.onnx')
                if not self.load_models(detection_model_path, recognition_model_path):
                    return False, None
            
            # 1. Use the shared method to detect the best face
            face_info, confidence = self.detect_best_face(img)
            
            # Check if a face was detected and meets confidence threshold
            # Use a slightly lower threshold for import to be more permissive
            min_import_confidence = 0.85
            if face_info is None or confidence < min_import_confidence:
                if face_info is None:
                    logger.warning(f"No face detected in image for {person_name}")
                else:
                    logger.warning(f"Face confidence too low for import ({person_name}): {confidence:.2f} < {min_import_confidence}")
                return False, None
                
            # 2. Use the shared method to extract face features 
            face_feature = self.extract_face_feature(img, face_info)
            if face_feature is None:
                logger.error(f"Failed to extract face features for {person_name}")
                return False, None

            # 3. Generate a thumbnail from the face for display
            thumbnail_img = self._create_thumbnail_from_face(img, face_info)
                
            # 4. Update the person in memory
            existing_person = self.memory.get_person(person_name)
            if existing_person:
                # Update existing person
                self.memory.update_person(
                    person_name,
                    feature_vector=face_feature,
                    box=[0, 0, 100, 100],  # Default box
                    confidence=confidence,
                    increment_count=True
                )
                # Add thumbnail
                if thumbnail_img is not None:
                    existing_person.add_thumbnail(thumbnail_img)
                logger.info(f"Updated existing person: {person_name}")
            else:
                # Create new person
                person = self.memory.add_person(
                    person_name,
                    feature_vector=face_feature,
                    is_named=True
                )
                
                # Add thumbnail to the new person
                if thumbnail_img is not None and person:
                    person.add_thumbnail(thumbnail_img)
                
                # Update detection info
                self.memory.update_person(
                    person_name,
                    box=[0, 0, 100, 100],  # Default box
                    confidence=confidence,
                    increment_count=False  # Already initialized to 1
                )
                logger.info(f"Added new person: {person_name}")
                
            # 4. Check for similar unnamed faces and merge them
            for person_id, person in self.memory.get_all_people().items():
                if person.is_named or person_id == person_name:
                    continue  # Skip named people and the face we just added
                
                if person.feature_vector is None:
                    continue
                    
                is_similar = self.comparison_service.are_features_similar(
                    face_feature, 
                    person.feature_vector,
                    FR.COSINE_THRESHOLD, 
                    FR.NORM_L2_THRESHOLD
                )
                
                if is_similar:
                    logger.info(f"Import: Merging similar unnamed face {person_id} into {person_name}")
                    self.memory.merge_people(person_id, person_name)
            
            # Request save after import
            self.memory.request_save()
                    
            return True, person_name
            
        except Exception as e:
            logger.error(f"Error processing imported face image for {person_name}: {e}", exc_info=True)
            return False, None
            
    def _create_thumbnail_from_face(self, img, face_info):
        """Create a thumbnail image directly from the detected face region.
        
        Args:
            img (numpy.ndarray): The full image
            face_info (numpy.ndarray): Face detection information
            
        Returns:
            numpy.ndarray: Cropped face thumbnail or None if creation fails
        """
        try:
            # Extract face coordinates
            x, y, w, h = list(map(int, face_info[:4]))
            
            # Add different margins for width and height to account for face proportions
            # Add more margin on top for forehead and less on sides
            margin_x = int(w * 0.15)  # Reduced side margins (was 0.2)
            margin_y_top = int(h * 0.3)  # More margin on top for forehead
            margin_y_bottom = int(h * 0.1)  # Less margin on bottom
            
            # Calculate new coordinates with margins, ensuring they're within image bounds
            height, width = img.shape[:2]
            x1 = max(0, x - margin_x)
            y1 = max(0, y - margin_y_top)  # More space above
            x2 = min(width, x + w + margin_x)
            y2 = min(height, y + h + margin_y_bottom)  # Less space below
            
            # Crop the face region with margin
            face_img = img[y1:y2, x1:x2]
            
            # Resize to a portrait aspect ratio (96x128) for thumbnails
            # This gives us a 3:4 aspect ratio which is better for faces
            face_img = cv2.resize(face_img, (96, 128))
            
            # Return the face image directly (no base64 encoding)
            return face_img
            
        except Exception as e:
            logger.error(f"Error creating thumbnail: {e}")
            return None

