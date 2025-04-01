import cv2
import numpy as np
import logging
import os

logger = logging.getLogger(__name__)

class FaceProcessor:
    """Class for handling face detection and recognition using OpenCV and ONNX models."""
    
    def __init__(self):
        self.detection_model = None
        self.recognition_model = None
        self.known_faces = {}  # Dictionary to store known face embeddings
        
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
            
            # Check if this face matches any known faces
            face_id = "Unknown"
            match_confidence = 0.0
            
            for known_id, known_feature in self.known_faces.items():
                cosine_score = self.recognition_model.match(face_feature, known_feature, cv2.FaceRecognizerSF_FR_COSINE)
                if cosine_score > 0.8:  # Threshold for recognition
                    if cosine_score > match_confidence:
                        match_confidence = cosine_score
                        face_id = known_id
            
            # Color based on recognition status (green if recognized, red if unknown)
            color = (0, 255, 0) if face_id != "Unknown" else (0, 0, 255)
            
            # Draw rectangle and label
            cv2.rectangle(result_frame, (x, y), (x + w, y + h), color, 2)
            label = f"{face_id} ({match_confidence:.2f})" if face_id != "Unknown" else "Unknown"
            cv2.putText(result_frame, label, (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            
            # Store recognized face information
            recognized_faces.append({
                'box': box,
                'confidence': float(confidence),
                'id': face_id,
                'match_score': float(match_confidence) if face_id != "Unknown" else 0.0
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
