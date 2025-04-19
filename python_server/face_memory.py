import os
import json
import datetime
import logging
import numpy as np
import threading
import time
import shutil
from person import Person
import concurrent.futures
import queue

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
        
        # Save status tracking for UI
        self._next_scheduled_save = 0
        self._auto_save_in_progress = False
        self._manual_save_requested = False
        
        # Create storage directory if it doesn't exist
        if self.storage_dir and not os.path.exists(self.storage_dir):
            os.makedirs(self.storage_dir, exist_ok=True)
        
        # Create thumbnails directory within storage directory
        self.thumbnails_dir = None
        if self.storage_dir:
            self.thumbnails_dir = os.path.join(self.storage_dir, "thumbnails")
            os.makedirs(self.thumbnails_dir, exist_ok=True)
            logger.info(f"Created thumbnails directory at {self.thumbnails_dir}")
            
        # Load from persistence if available - this populates the in-memory data
        self._load_from_storage()
        
        # Start the periodic save thread
        self._start_periodic_save()
        
        # Create process pool for background saves
        self._process_pool = concurrent.futures.ProcessPoolExecutor(max_workers=1)
        self._save_queue = queue.Queue()
        self._save_in_progress = False
        self._save_results = []  # Store futures for save operations
        
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
                    # Calculate time until next scheduled save
                    self._next_scheduled_save = self._last_save_time + self._save_interval
                    time_remaining = max(0, self._next_scheduled_save - current_time)
                    
                    save_due_to_interval = (current_time >= self._next_scheduled_save)
                    save_needed = self._save_requested or save_due_to_interval
                    
                    if save_needed:
                        # Set auto-save flag if triggered by interval
                        self._auto_save_in_progress = save_due_to_interval
                        self._manual_save_requested = self._save_requested
                        
                        # If a save is needed, perform it
                        self.save_to_storage()
                        self._save_requested = False
                        self._last_save_time = current_time
                        self._next_scheduled_save = current_time + self._save_interval
                        
                        # Log the save with appropriate message
                        if self._auto_save_in_progress:
                            logger.info(f"Auto-save completed at {datetime.datetime.now().isoformat()}, {len(self.people)} people")
                        else:
                            logger.info(f"Manual save completed at {datetime.datetime.now().isoformat()}, {len(self.people)} people")
                        
                        # Reset flags
                        self._auto_save_in_progress = False
                        self._manual_save_requested = False
            except Exception as e:
                logger.error(f"Error in periodic save worker: {e}", exc_info=True)
                self._auto_save_in_progress = False
                self._manual_save_requested = False
            
            # Sleep briefly before checking again (checking more frequently than the save interval)
            time.sleep(5)  # Check every 5 seconds if a save is needed
    
    def request_save(self):
        """Request a manual save operation to happen on next check."""
        with self._lock:
            self._save_requested = True
            self._manual_save_requested = True
            logger.debug("Manual save requested")
        
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
                        person = Person(person_id, thumbnails_dir=self.thumbnails_dir)
                        person.from_dict(person_data)
                        self.people[person_id] = person
                    
                logger.info(f"Loaded {len(self.people)} people from storage")
                
                # Set last save time to track when we last loaded or saved
                self._last_save_time = time.time()
                
                # Verify feature vector types after loading 
                # This extra check helps identify any potential type issues
                for person_id, person in self.people.items():
                    if person.feature_vector is not None:
                        if person.feature_vector.dtype != np.float32:
                            logger.warning(f"Converting feature vector for {person_id} from {person.feature_vector.dtype} to float32")
                            person.feature_vector = person.feature_vector.astype(np.float32)
            
        except Exception as e:
            logger.error(f"Error loading face data: {e}", exc_info=True)
            # Proceed with empty memory if loading fails
            self.people.clear()
            
    def save_to_storage(self):
        """Prepare data and save to persistent storage in a background process."""
        storage_path = self._get_storage_path()
        if not storage_path:
            logger.warning("No storage path specified, cannot save face data")
            return
            
        try:
            people_count = len(self.people)
            logger.info(f"Preparing {people_count} people for storage at {storage_path}")
            
            # This block prepares data while holding the lock, but doesn't perform I/O
            with self._lock:
                if self._save_in_progress:
                    logger.debug("Save already in progress, skipping duplicate save")
                    return
                    
                self._save_in_progress = True
                
                # Convert all people to dictionaries with JSON-safe values
                try:
                    people_data = []
                    for person in self.people.values():
                        try:
                            person_dict = self._validate_json_data(person.to_dict())
                            people_data.append(person_dict)
                        except Exception as e:
                            logger.error(f"Error processing person {person.id} for JSON: {e}")
                            continue
                except Exception as e:
                    logger.error(f"Error converting people to dicts: {e}")
                    self._save_in_progress = False
                    raise
                
                # Create data structure with metadata
                data = {
                    'people': people_data,
                    'timestamp': datetime.datetime.now().isoformat(),
                    'version': '1.0',
                    'count': people_count
                }
                
                # Serialize data to JSON string before passing to worker process
                # This avoids serialization issues with complex Python objects
                try:
                    json_data = json.dumps(data, indent=2, default=self._json_serializer)
                except TypeError as e:
                    logger.error(f"JSON serialization error: {e}")
                    self._identify_json_problem(data)
                    self._save_in_progress = False
                    raise
                    
                # Create a backup of the existing file if it exists
                backup_path = f"{storage_path}.bak"
                backup_exists = os.path.exists(storage_path)
            
            # Submit the actual save operation to the process pool
            # This happens outside the lock to avoid blocking
            future = self._process_pool.submit(
                self._save_worker,
                storage_path,
                backup_path,
                backup_exists,
                json_data
            )
            
            # Add callback to handle completion
            future.add_done_callback(self._save_completed)
            
            # Store the future to prevent it from being garbage collected
            self._save_results.append(future)
            
            # Clean up completed futures 
            self._save_results = [f for f in self._save_results if not f.done()]
            
            # Update last save time after initiating save (not waiting for completion)
            with self._lock:
                self._last_save_time = time.time()
                
            logger.info(f"Save operation for {people_count} people initiated in background")
            
        except Exception as e:
            logger.error(f"Error preparing data for save: {e}", exc_info=True)
            with self._lock:
                self._save_in_progress = False
    
    @staticmethod
    def _save_worker(storage_path, backup_path, backup_exists, json_data):
        """Worker function that runs in a separate process to save data to disk.
        
        Args:
            storage_path: Path to the storage file
            backup_path: Path to the backup file
            backup_exists: Whether the storage file already exists
            json_data: JSON string to write to file
            
        Returns:
            dict: Result information including success/failure
        """
        try:
            # Create a backup of the existing file first if it exists
            if backup_exists:
                try:
                    # Simple file copy instead of reading/writing
                    shutil.copy2(storage_path, backup_path)
                except Exception as e:
                    # Log but continue - backup failure shouldn't prevent save
                    return {"success": False, "stage": "backup", "error": str(e)}
            
            # Write to a temporary file first, then rename for atomicity
            temp_path = f"{storage_path}.tmp"
            with open(temp_path, 'w') as f:
                f.write(json_data)  # Write pre-serialized JSON string
            
            # Rename (atomic on most filesystems)
            os.replace(temp_path, storage_path)
            
            return {"success": True, "path": storage_path}
            
        except Exception as e:
            return {"success": False, "stage": "write", "error": str(e)}
    
    def _save_completed(self, future):
        """Callback for when a save operation completes."""
        try:
            result = future.result()
            
            with self._lock:
                self._save_in_progress = False
                self._auto_save_in_progress = False
                self._manual_save_requested = False
                
            if result["success"]:
                logger.info(f"Background save completed successfully at {result['path']}")
            else:
                logger.error(f"Background save failed during {result['stage']}: {result['error']}")
                
        except Exception as e:
            logger.error(f"Error in save completion callback: {e}")
            with self._lock:
                self._save_in_progress = False
                self._auto_save_in_progress = False
                self._manual_save_requested = False
    
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
            
        # Wait for any pending save operations to complete
        if hasattr(self, '_save_results') and self._save_results:
            # Wait for current save operations to complete with timeout
            try:
                # Use a short timeout to avoid hanging during shutdown
                concurrent.futures.wait(self._save_results, timeout=10)
                logger.info("All pending save operations completed")
            except Exception as e:
                logger.error(f"Error waiting for pending saves: {e}")
        
        # Do a final synchronous save to ensure latest data is persisted
        try:
            # Use a direct save method that doesn't use the process pool
            self._direct_save_to_storage()
            logger.info("Final save completed during shutdown")
        except Exception as e:
            logger.error(f"Error during final save: {e}", exc_info=True)
            
        # Shutdown the process pool
        if hasattr(self, '_process_pool'):
            self._process_pool.shutdown(wait=False)
            
        logger.info("FaceMemory shutdown complete")
    
    def _direct_save_to_storage(self):
        """Direct synchronous save method for shutdown."""
        storage_path = self._get_storage_path()
        if not storage_path:
            return
            
        with self._lock:
            try:
                # Prepare data
                people_data = []
                for person in self.people.values():
                    try:
                        person_dict = self._validate_json_data(person.to_dict())
                        people_data.append(person_dict)
                    except Exception:
                        continue
                
                data = {
                    'people': people_data,
                    'timestamp': datetime.datetime.now().isoformat(),
                    'version': '1.0',
                    'count': len(people_data)
                }
                
                # Create backup
                backup_path = f"{storage_path}.bak"
                if os.path.exists(storage_path):
                    shutil.copy2(storage_path, backup_path)
                
                # Save data
                temp_path = f"{storage_path}.tmp"
                with open(temp_path, 'w') as f:
                    json.dump(data, f, indent=2, default=self._json_serializer)
                
                os.replace(temp_path, storage_path)
                
            except Exception as e:
                logger.error(f"Error in direct save: {e}", exc_info=True)
                raise
        
    def get_person(self, person_id):
        """Get a person by ID from memory (fast lookup)."""
        with self._lock:
            return self.people.get(person_id)
    
    def add_person(self, person_id, feature_vector, is_named=False):
        """Add a new person to memory."""
        with self._lock:
            person = Person(person_id, feature_vector, is_named, thumbnails_dir=self.thumbnails_dir)
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
            
            # Rename thumbnail directory if it exists
            if self.thumbnails_dir and person.person_thumbnails_dir:
                old_thumbnail_dir = person.person_thumbnails_dir
                new_thumbnail_dir = os.path.join(self.thumbnails_dir, Person(new_id)._get_safe_id())
                
                if os.path.exists(old_thumbnail_dir):
                    try:
                        # Create new directory if it doesn't exist
                        os.makedirs(new_thumbnail_dir, exist_ok=True)
                        
                        # Move files from old to new directory
                        for filename in person.thumbnails:
                            old_file = os.path.join(old_thumbnail_dir, filename)
                            new_file = os.path.join(new_thumbnail_dir, filename)
                            if os.path.exists(old_file):
                                shutil.copy2(old_file, new_file)
                        
                        # Remove old directory after moving files
                        shutil.rmtree(old_thumbnail_dir, ignore_errors=True)
                        
                        # Update thumbnail directory
                        person.person_thumbnails_dir = new_thumbnail_dir
                    except Exception as e:
                        logger.error(f"Error moving thumbnail directory: {e}")
            
            # Update person ID
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
            
            # Merge thumbnails - copy thumbnail files from source to target
            if self.thumbnails_dir and source.thumbnails and target.person_thumbnails_dir:
                try:
                    source_dir = source.person_thumbnails_dir
                    target_dir = target.person_thumbnails_dir
                    
                    if os.path.exists(source_dir):
                        # Make sure target directory exists
                        os.makedirs(target_dir, exist_ok=True)
                        
                        # Copy up to 3 of the latest thumbnails from source to target
                        latest_source_thumbnails = source.thumbnails[-3:] if len(source.thumbnails) > 3 else source.thumbnails
                        
                        for filename in latest_source_thumbnails:
                            source_file = os.path.join(source_dir, filename)
                            if os.path.exists(source_file):
                                # Generate new filename with current timestamp
                                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
                                new_filename = f"{timestamp}.jpg"
                                target_file = os.path.join(target_dir, new_filename)
                                
                                # Copy the file
                                shutil.copy2(source_file, target_file)
                                
                                # Add to target's thumbnails list
                                target.thumbnails.append(new_filename)
                        
                        # Limit target thumbnails to 5
                        while len(target.thumbnails) > 5:
                            oldest = target.thumbnails.pop(0)
                            oldest_path = os.path.join(target_dir, oldest)
                            if os.path.exists(oldest_path):
                                os.remove(oldest_path)
                                
                        target.thumbnail_count = len(target.thumbnails)
                        
                        # Clean up source thumbnail directory
                        shutil.rmtree(source_dir, ignore_errors=True)
                    
                except Exception as e:
                    logger.error(f"Error merging thumbnail directories: {e}")
            
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
    
    def get_save_status(self):
        """Get the current save status for UI display.
        
        Returns:
            dict: A dictionary containing save status information:
                - next_save_time: Timestamp when the next auto-save will occur
                - seconds_remaining: Seconds until next auto-save
                - auto_save_in_progress: Whether an auto-save is currently in progress
                - manual_save_requested: Whether a manual save has been requested
                - save_in_progress: Whether any type of save is in progress
        """
        with self._lock:
            current_time = time.time()
            next_save_time = self._next_scheduled_save
            seconds_remaining = max(0, next_save_time - current_time)
            
            # Check if any save operation is in progress (background or foreground)
            save_in_progress = self._auto_save_in_progress or self._manual_save_requested or self._save_in_progress
            
            return {
                'next_save_time': datetime.datetime.fromtimestamp(next_save_time).isoformat(),
                'seconds_remaining': int(seconds_remaining),
                'auto_save_in_progress': self._auto_save_in_progress,
                'manual_save_requested': self._manual_save_requested,
                'save_in_progress': save_in_progress,
                'save_interval': self._save_interval
            }
