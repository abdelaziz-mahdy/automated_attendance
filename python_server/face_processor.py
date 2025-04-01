import cv2
import numpy as np
import logging
import os
import time

logger = logging.getLogger(__name__)

class FaceProcessor:
    """Class for handling face detection and recognition using OpenCV and ONNX models."""
    
    def __init__(self):
        self.detection_model = None
        self.recognition_model = None
        self.known_faces = {}  # Dictionary to store known face embeddings
        self.tracked_faces = {}  # Dictionary to track faces across frames
        self.face_appearance_count = {}  # Dictionary to count face appearances
        self.last_face_id = 0  # Counter for generating unique face IDs
        self.tracking_timeout = 1.0  # Seconds to keep tracking a face without seeing it
        
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
                0.9,  # Score threshold
                0.3,  # NMS threshold
                5000  # Top K
            )
            
            # Load SFace recognition model
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
            if confidence < 0.9:
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
            # Skip expired tracked faces
            if now - tracked_data['last_seen'] > self.tracking_timeout:
                continue
                
            # Compare face features
            score = self.recognition_model.match(face_feature, tracked_data['feature'], 
                                               cv2.FaceRecognizerSF_FR_COSINE)
            
            # We need a good match score
            if score > 0.8 and score > best_match_score:
                best_match_id = face_id
                best_match_score = score
        
        return best_match_id, best_match_score
    
    def get_face_counts(self):
        """Return the count of appearances for each tracked face."""
        return self.face_appearance_count
        
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
        
        # Clean up expired tracked faces
        for face_id in list(self.tracked_faces.keys()):
            if current_time - self.tracked_faces[face_id]['last_seen'] > self.tracking_timeout:
                del self.tracked_faces[face_id]
        
        for face_info in faces[1]:
            # Extract face information
            box = list(map(int, face_info[:4]))
            confidence = face_info[4]
            
            # Only process faces with confidence above threshold
            if confidence < 0.9:
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
                named_person = tracked_face_id in self.known_faces
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
                
                for known_id, known_feature in self.known_faces.items():
                    cosine_score = self.recognition_model.match(
                        face_feature, known_feature, cv2.FaceRecognizerSF_FR_COSINE)
                    
                    if cosine_score > 0.8 and cosine_score > match_confidence:
                        match_confidence = cosine_score
                        face_id = known_id
                        named_person = True
                
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
            
            # Draw rectangle and label with appearance count
            cv2.rectangle(result_frame, (x, y), (x + w, y + h), color, 2)
            label = f"{face_id} ({match_confidence:.2f}) - {appearance_count} times"
            cv2.putText(result_frame, label, (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            
            # Store recognized face information with count
            recognized_faces.append({
                'box': box,
                'confidence': float(confidence),
                'id': face_id,
                'match_score': float(match_confidence),
                'named_person': named_person,
                'appearance_count': appearance_count
            })
            
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
        aligned_face = self.recognition_model.alignCrop(frame, face_info)
        face_feature = self.recognition_model.feature(aligned_face)
        
        # Store the face feature
        self.known_faces[face_id] = face_feature
        logger.info(f"Added face with ID: {face_id}")
        return True
