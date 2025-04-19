import os
import json
import datetime
import logging
import numpy as np
import threading
import time
from person import Person

logger = logging.getLogger(__name__)

class FaceMemory:
    """Class that manages storage and retrieval of face recognition data.
    
    This implementation keeps all data in memory for fast lookups and
    periodically backs up to disk for persistence.
    """
    
    def __init__(self, storage_dir=None):
        self.people = {}  # Maps ID to Person object - all data stays in memory
        self.storage_dir = storage_dir
        
        # Save management
        self._save_requested = False
        self._last_save_time = 0  # Initialize to 0 to force initial save after loading
        self._save_interval = 60  # Save every 60 seconds
        self._lock = threading.RLock()  # Reentrant lock for thread safety
        
        # Create storage directory if it doesn't exist
        if self.storage_dir and not os.path.exists(self.storage_dir):
            os.makedirs(self.storage_dir, exist_ok=True)
            
        # Load from persistence if available - this populates the in-memory data
        self._load_from_storage()
        
        # Start the periodic save thread
        self._start_periodic_save()
        
        logger.info(f"FaceMemory initialized with {len(self.people)} people loaded from storage")
        
    def _get_storage_path(self):
        """Get storage file path."""
        if not self.storage_dir:
            return None
        return os.path.join(self.storage_dir, "face_memory.json")
    
    def _start_periodic_save(self):
        """Start a background thread for periodic saving."""
        self._stop_periodic_save = False
        self._save_thread = threading.Thread(target=self._periodic_save_worker, daemon=True)
        self._save_thread.start()
        logger.info("Started periodic save thread")
    
    def _periodic_save_worker(self):
        """Worker function that periodically saves data."""
        while not getattr(self, "_stop_periodic_save", False):
            try:
                # Check if save is requested or if it's been too long since last save
                current_time = time.time()
                with self._lock:
                    save_due_to_interval = (current_time - self._last_save_time) > self._save_interval
                    save_needed = self._save_requested or save_due_to_interval
                    
                    if save_needed:
                        # If a save is needed, perform it
                        self.save_to_storage()
                        self._save_requested = False
                        self._last_save_time = current_time
                        logger.debug(f"Periodic save at {datetime.datetime.now().isoformat()}, {len(self.people)} people")
            except Exception as e:
                logger.error(f"Error in periodic save worker: {e}", exc_info=True)
            
            # Sleep briefly before checking again (checking more frequently than the save interval)
            time.sleep(5)  # Check every 5 seconds if a save is needed
    
    def request_save(self):
        """Request a save operation to happen on next check."""
        with self._lock:
            self._save_requested = True
            logger.debug("Save requested")
        
    def _load_from_storage(self):
        """Load face data from persistent storage into memory."""
        storage_path = self._get_storage_path()
        if not storage_path or not os.path.exists(storage_path):
            logger.info("No storage file found, starting with empty memory")
            return
            
        try:
            with self._lock:
                # First, try to load the main file
                try:
                    with open(storage_path, 'r') as f:
                        logger.info(f"Loading face data from {storage_path}")
                        data = json.load(f)
                except (json.JSONDecodeError, IOError) as e:
                    logger.error(f"Error reading main storage file: {e}")
                    
                    # If main file fails, try backup file
                    backup_path = f"{storage_path}.bak"
                    if os.path.exists(backup_path):
                        logger.info(f"Attempting to load from backup file: {backup_path}")
                        with open(backup_path, 'r') as f:
                            data = json.load(f)
                    else:
                        logger.warning("No valid storage files found")
                        return
                        
                # Clear any existing data and populate from storage
                self.people.clear()
                for person_data in data.get('people', []):
                    person_id = person_data.get('id')
                    if person_id:
                        person = Person(person_id)
                        person.from_dict(person_data)
                        self.people[person_id] = person
                    
                logger.info(f"Loaded {len(self.people)} people from storage")
                
                # Set last save time to track when we last loaded or saved
                self._last_save_time = time.time()
            
        except Exception as e:
            logger.error(f"Error loading face data: {e}", exc_info=True)
            # Proceed with empty memory if loading fails
            self.people.clear()
            
    def save_to_storage(self):
        """Save face data from memory to persistent storage."""
        storage_path = self._get_storage_path()
        if not storage_path:
            logger.warning("No storage path specified, cannot save face data")
            return
            
        try:
            people_count = len(self.people)
            logger.info(f"Saving {people_count} people to storage at {storage_path}")
            
            with self._lock:
                # Create a backup of the existing file first
                if os.path.exists(storage_path):
                    backup_path = f"{storage_path}.bak"
                    try:
                        with open(storage_path, 'r') as src, open(backup_path, 'w') as dst:
                            dst.write(src.read())
                        logger.debug(f"Created backup at {backup_path}")
                    except Exception as e:
                        logger.warning(f"Failed to create backup: {e}")
                
                # Convert all people to dictionaries with JSON-safe values
                try:
                    people_data = []
                    for person in self.people.values():
                        try:
                            # Validate each person's data for JSON compatibility
                            person_dict = self._validate_json_data(person.to_dict())
                            people_data.append(person_dict)
                        except Exception as e:
                            logger.error(f"Error processing person {person.id} for JSON: {e}")
                            # Skip this person if there's an error, but continue with others
                            continue
                except Exception as e:
                    logger.error(f"Error converting people to dicts: {e}")
                    raise
                
                # Create data structure with metadata
                data = {
                    'people': people_data,
                    'timestamp': datetime.datetime.now().isoformat(),
                    'version': '1.0',
                    'count': people_count
                }
                
                # Write to a temporary file first, then rename for atomicity
                temp_path = f"{storage_path}.tmp"
                try:
                    with open(temp_path, 'w') as f:
                        json.dump(data, f, indent=2, default=self._json_serializer)
                except TypeError as e:
                    logger.error(f"JSON serialization error: {e}")
                    # Try to identify the problematic value
                    self._identify_json_problem(data)
                    raise
                
                # Rename (atomic on most filesystems)
                os.replace(temp_path, storage_path)
                
                # Update last save time after successful save
                self._last_save_time = time.time()
                
            logger.info(f"Successfully saved {people_count} people to storage")
            
        except Exception as e:
            logger.error(f"Error saving face data: {e}", exc_info=True)
            
    def _json_serializer(self, obj):
        """Custom JSON serializer to handle non-serializable types."""
        # Handle numpy arrays
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        # Handle datetime objects
        if isinstance(obj, datetime.datetime):
            return obj.isoformat()
        # Handle numpy numeric types
        if isinstance(obj, (np.int_, np.intc, np.intp, np.int8, np.int16, np.int32, np.int64,
                            np.uint8, np.uint16, np.uint32, np.uint64)):
            return int(obj)
        if isinstance(obj, (np.float_, np.float16, np.float32, np.float64)):
            return float(obj)
        # Handle numpy booleans
        if isinstance(obj, np.bool_):
            return bool(obj)
        # Raise TypeError for all other non-serializable types
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
    
    def _validate_json_data(self, data):
        """Validate and sanitize data to ensure it's JSON-compatible."""
        if data is None:
            return None
            
        if isinstance(data, dict):
            result = {}
            for key, value in data.items():
                if not isinstance(key, str):
                    key = str(key)  # Convert non-string keys to strings
                result[key] = self._validate_json_data(value)
            return result
            
        elif isinstance(data, list):
            return [self._validate_json_data(item) for item in data]
            
        elif isinstance(data, np.ndarray):
            return data.tolist()
            
        elif isinstance(data, (str, int, float, bool)) or data is None:
            return data
            
        elif isinstance(data, datetime.datetime):
            return data.isoformat()
            
        elif isinstance(data, (np.int_, np.intc, np.intp, np.int8, np.int16, np.int32, np.int64,
                                np.uint8, np.uint16, np.uint32, np.uint64)):
            return int(data)
            
        elif isinstance(data, (np.float_, np.float16, np.float32, np.float64)):
            return float(data)
            
        elif isinstance(data, np.bool_):
            return bool(data)
            
        else:
            # For all other types, try to convert to string
            logger.warning(f"Converting {type(data)} to string for JSON compatibility")
            return str(data)
    
    def _identify_json_problem(self, data, path=""):
        """Recursively identify problematic values for JSON serialization."""
        if isinstance(data, dict):
            for key, value in data.items():
                self._identify_json_problem(value, f"{path}.{key}" if path else key)
        elif isinstance(data, list):
            for i, item in enumerate(data):
                self._identify_json_problem(item, f"{path}[{i}]")
        else:
            try:
                json.dumps(data)
            except (TypeError, OverflowError) as e:
                logger.error(f"JSON problem at {path}: {type(data)} - {e}")

    def shutdown(self):
        """Shutdown the face memory, ensuring data is saved."""
        logger.info("Shutting down FaceMemory")
        
        # Stop the periodic save thread
        self._stop_periodic_save = True
        if hasattr(self, '_save_thread') and self._save_thread.is_alive():
            self._save_thread.join(timeout=5)
            
        # Do a final save to ensure latest data is persisted
        try:
            self.save_to_storage()
            logger.info("Final save completed during shutdown")
        except Exception as e:
            logger.error(f"Error during final save: {e}", exc_info=True)
            
        logger.info("FaceMemory shutdown complete")
        
    def get_person(self, person_id):
        """Get a person by ID from memory (fast lookup)."""
        with self._lock:
            return self.people.get(person_id)
    
    def add_person(self, person_id, feature_vector, is_named=False):
        """Add a new person to memory."""
        with self._lock:
            person = Person(person_id, feature_vector, is_named)
            self.people[person_id] = person
            self._save_requested = True
            return person
    
    def update_person(self, person_id, feature_vector=None, box=None, 
                     confidence=None, match_score=None, increment_count=True):
        """Update a person's data in memory."""
        with self._lock:
            person = self.get_person(person_id)
            if not person:
                return None
                
            # Update properties
            if feature_vector is not None:
                person.update_feature(feature_vector)
                
            if box is not None and confidence is not None:
                person.update_detection(box, confidence)
                
            if match_score is not None:
                person.update_match(match_score)
                
            if increment_count:
                person.increment_count()
                
            # Always update last seen time
            person.update_last_seen()
            
            # Request a save since data was modified
            self._save_requested = True
            
            return person
    
    def rename_person(self, old_id, new_id):
        """Rename a person in memory."""
        with self._lock:
            if old_id not in self.people:
                logger.error(f"Cannot rename: Person {old_id} not found")
                return False
                
            if new_id in self.people:
                logger.error(f"Cannot rename: Person {new_id} already exists")
                return False
                
            # Get the person and update ID
            person = self.people[old_id]
            person.id = new_id
            person.is_named = True  # If renamed, assume it's a named person
            
            # Add to new ID and remove from old ID
            self.people[new_id] = person
            del self.people[old_id]
            
            # Request a save since data was modified
            self._save_requested = True
            
            logger.info(f"Renamed person {old_id} to {new_id}")
            return True
    
    def merge_people(self, source_id, target_id):
        """Merge two people in memory, keeping the target person."""
        with self._lock:
            source = self.get_person(source_id)
            target = self.get_person(target_id)
            
            if not source:
                logger.error(f"Cannot merge: Source person {source_id} not found")
                return False
                
            if not target:
                logger.error(f"Cannot merge: Target person {target_id} not found")
                return False
                
            # Combine appearance counts
            target.appearance_count += source.appearance_count
            
            # Keep earliest first_seen time
            if source.first_seen < target.first_seen:
                target.first_seen = source.first_seen
                
            # Keep latest last_seen time
            if source.last_seen > target.last_seen:
                target.last_seen = source.last_seen
                
            # Update feature vector with weighted average if possible
            if source.feature_vector is not None and target.feature_vector is not None:
                # Weight by appearance count
                total_count = source.appearance_count + target.appearance_count
                if total_count > 0:
                    source_weight = source.appearance_count / total_count
                    target_weight = target.appearance_count / total_count
                    target.feature_vector = (target_weight * target.feature_vector + 
                                            source_weight * source.feature_vector)
            
            # Remove source person
            del self.people[source_id]
            
            # Request a save since data was modified
            self._save_requested = True
            
            logger.info(f"Merged person {source_id} into {target_id}")
            return True
    
    def find_similar_people(self, feature_vector, threshold=0.6):
        """Find people with similar feature vectors in memory."""
        with self._lock:
            similar_people = []
            
            for person_id, person in self.people.items():
                if person.feature_vector is None:
                    continue
                    
                # Calculate cosine similarity
                similarity = self._calculate_similarity(feature_vector, person.feature_vector)
                
                if similarity >= threshold:
                    similar_people.append((person_id, similarity))
                    
            # Sort by similarity (highest first)
            similar_people.sort(key=lambda x: x[1], reverse=True)
            
            return similar_people
    
    def _calculate_similarity(self, vec1, vec2):
        """Calculate cosine similarity between two vectors."""
        dot_product = np.dot(vec1, vec2)
        norm1 = np.linalg.norm(vec1)
        norm2 = np.linalg.norm(vec2)
        
        if norm1 == 0 or norm2 == 0:
            return 0
            
        return dot_product / (norm1 * norm2)
    
    def get_all_people(self):
        """Get all people from memory (returns a copy for thread safety)."""
        with self._lock:
            # Return a copy to prevent concurrent modification issues
            return dict(self.people)
    
    def get_stats(self):
        """Get statistics about the face memory."""
        with self._lock:
            total_people = len(self.people)
            named_people = sum(1 for p in self.people.values() if p.is_named)
            unnamed_people = total_people - named_people
            total_appearances = sum(p.appearance_count for p in self.people.values())
            
            return {
                'total_people': total_people,
                'named_people': named_people,
                'unnamed_people': unnamed_people,
                'total_appearances': total_appearances,
                'last_save_time': datetime.datetime.fromtimestamp(self._last_save_time).isoformat(),
                'in_memory': True  # Flag to indicate we're using in-memory storage
            }
