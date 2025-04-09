document.addEventListener('DOMContentLoaded', () => {
    // DOM elements
    const streamImage = document.getElementById('streamImage');
    const loadingIndicator = document.getElementById('loadingIndicator');
    const streamTypeText = document.getElementById('streamType');
    const fpsCounter = document.getElementById('fpsCounter');
    const regularStreamBtn = document.getElementById('regularStream');
    const detectionStreamBtn = document.getElementById('detectionStream');
    const recognitionStreamBtn = document.getElementById('recognitionStream');
    
    // Get DOM elements for face counts and drag-and-drop
    const refreshFaceCountsBtn = document.getElementById('refreshFaceCounts');
    const totalFacesCount = document.getElementById('totalFacesCount');
    const faceCountsList = document.getElementById('faceCountsList');
    const toggleDragModeBtn = document.getElementById('toggleDragMode');
    const dropzone = document.getElementById('dropzone');
    const toastContainer = document.getElementById('toastContainer');
    
    // Get DOM elements for attendance
    const refreshAttendanceBtn = document.getElementById('refreshAttendance');
    const attendanceDate = document.getElementById('attendanceDate');
    const presentCount = document.getElementById('presentCount');
    const earliestArrival = document.getElementById('earliestArrival');
    const latestArrival = document.getElementById('latestArrival');
    const attendanceList = document.getElementById('attendanceList');
    
    // Tab navigation elements
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');
    
    // Variables for face tracking and merging
    let faceCountUpdateInterval = null;
    let attendanceUpdateInterval = null;
    let inDragMode = false;
    let draggedFaceId = null;
    let faceData = {};
    let attendanceData = {};
    let faceThumbnails = {}; // Store thumbnails for faces
    let droppedFaces = []; // Store faces dropped into the merge area
    let thumbnailCleanupInterval = null; // Interval for cleaning up thumbnails
    
    // Stream settings
    let streamType = 'regular';
    let isStreaming = false;
    let frameRequestInProgress = false; // Flag to track ongoing requests
    let streamTimeout = null;
    let frameCount = 0;
    let lastFpsUpdateTime = Date.now();
    let pendingModeChange = false; // Flag to track mode change requests
    
    // Stream URLs
    const streamUrls = {
        regular: '/get_image',
        detection: '/get_image_with_detection',
        recognition: '/get_image_with_recognition'
    };
    
    // Tab navigation functionality
    function setupTabs() {
        // Add click event listeners to all tab buttons
        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const tabId = button.dataset.tab;
                
                // Remove active class from all buttons and contents
                tabButtons.forEach(btn => btn.classList.remove('active'));
                tabContents.forEach(content => content.classList.remove('active'));
                
                // Add active class to selected button and content
                button.addEventListener('click', () => {
                    const tabId = button.dataset.tab;
                    
                    // Remove active class from all buttons and contents
                    tabButtons.forEach(btn => btn.classList.remove('active'));
                    tabContents.forEach(content => content.classList.remove('active'));
                    
                    // Add active class to selected button and content
                    button.classList.add('active');
                    document.getElementById(tabId).classList.add('active');
                    
                    // If switching to faces tab, refresh face counts
                    if (tabId === 'faces-tab') {
                        updateFaceCounts();
                    }
                    
                    // If switching to attendance tab, refresh attendance data
                    if (tabId === 'attendance-tab') {
                        updateAttendance();
                    }
                });
            });
        });
    }
    
    // Initialize the stream
    function startStream() {
        if (isStreaming) return;
        
        isStreaming = true;
        streamImage.style.display = 'none';
        loadingIndicator.style.display = 'block';
        
        // Clear any existing timeout
        if (streamTimeout) {
            clearTimeout(streamTimeout);
        }
        
        // Start requesting frames
        requestNextFrame();
    }
    
    // Request the next frame
    function requestNextFrame() {
        // If there's already a request in progress, don't start another one
        if (frameRequestInProgress) {
            // Schedule the next frame request after a short delay
            streamTimeout = setTimeout(requestNextFrame, 10);
            return;
        }
        
        frameRequestInProgress = true;
        updateFrame().finally(() => {
            frameRequestInProgress = false;
            
            // If we're still supposed to be streaming, request the next frame
            if (isStreaming && !pendingModeChange) {
                // Request next frame with a small delay to prevent overwhelming the server
                streamTimeout = setTimeout(requestNextFrame, 40); // ~25fps
            }
        });
    }
    
    // Update the current frame
    async function updateFrame() {
        // Create a unique URL to prevent browser caching
        const url = `${streamUrls[streamType]}?t=${Date.now()}`;
        
        try {
            // Fetch the image as a blob
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            
            const blob = await response.blob();
            const imgUrl = URL.createObjectURL(blob);
            
            // Only update if we're still in the same stream mode (no pending change)
            if (!pendingModeChange) {
                streamImage.onload = () => {
                    if (streamImage.style.display === 'none') {
                        streamImage.style.display = 'block';
                        loadingIndicator.style.display = 'none';
                    }
                    
                    // Update FPS counter
                    frameCount++;
                    const now = Date.now();
                    const elapsed = now - lastFpsUpdateTime;
                    
                    if (elapsed >= 1000) { // Update FPS every second
                        const fps = Math.round((frameCount / elapsed) * 1000);
                        fpsCounter.textContent = `FPS: ${fps}`;
                        frameCount = 0;
                        lastFpsUpdateTime = now;
                    }
                    
                    // Free the blob URL to prevent memory leaks
                    URL.revokeObjectURL(imgUrl);
                };
                
                streamImage.src = imgUrl;
                
                // If in recognition mode, capture thumbnails
                if (streamType === 'recognition' && !document.hidden) {
                    // Always capture thumbnails on each frame in recognition mode
                    await captureFrameForThumbnails(blob);
                }
            } else {
                // If mode changed while fetching, just free the blob URL
                URL.revokeObjectURL(imgUrl);
            }
        } catch (err) {
            console.error('Error fetching frame:', err);
            // On error, pause slightly before trying again
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
    
    // Capture a frame and create thumbnails for detected faces
    async function captureFrameForThumbnails(blob) {
        try {
            // Get face data from server
            const response = await fetch('/get_face_data');
            if (!response.ok) return;
            
            const data = await response.json();
            if (!data.faces || data.faces.length === 0) return;
            
            // Convert blob to an image
            const img = new Image();
            img.src = URL.createObjectURL(blob);
            
            await new Promise(resolve => {
                img.onload = resolve;
            });
            
            // Create a canvas to extract face regions
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            
            // Process each detected face
            for (const face of data.faces) {
                if (!face.box || !face.id) continue;
                
                // Check if this face is new or has less than 2 thumbnails - prioritize capturing new faces
                const isNewFace = !faceThumbnails[face.id] || faceThumbnails[face.id].length < 2;
                
                // For established faces with 2+ thumbnails, only capture occasionally to avoid unnecessary processing
                if (!isNewFace && Math.random() > 0.1) continue; // 10% chance for faces with enough thumbnails
                
                // Extract face rectangle
                const [x, y, w, h] = face.box;
                
                // Set canvas size to the face size
                canvas.width = w;
                canvas.height = h;
                
                // Draw only the face region to the canvas
                ctx.drawImage(img, x, y, w, h, 0, 0, w, h);
                
                // Convert to JPEG data URL
                const thumbnailUrl = canvas.toDataURL('image/jpeg', 0.7);
                
                // Store thumbnail URL for this face ID
                if (!faceThumbnails[face.id]) {
                    faceThumbnails[face.id] = [];
                }
                
                // Limit to 5 thumbnails per face to avoid memory issues
                if (faceThumbnails[face.id].length >= 5) {
                    faceThumbnails[face.id].shift(); // Remove oldest thumbnail
                }
                
                faceThumbnails[face.id].push(thumbnailUrl);
                
                // Update face thumbnails in the UI if this face is currently displayed
                const faceElement = document.querySelector(`.face-count-item[data-face-id="${face.id}"]`);
                if (faceElement) {
                    updateFaceThumbnails(faceElement, face.id);
                }
            }
            
            // Clean up
            URL.revokeObjectURL(img.src);
        } catch (err) {
            console.error('Error capturing thumbnails:', err);
        }
    }
    
    // Update face thumbnails in the UI
    function updateFaceThumbnails(faceElement, faceId) {
        if (!faceThumbnails[faceId] || faceThumbnails[faceId].length === 0) return;
        
        // Find or create image container
        let imgContainer = faceElement.querySelector('.face-img-container');
        if (!imgContainer) return;
        
        // Clear existing content
        imgContainer.innerHTML = '';
        
        // Use the latest thumbnail as the main image
        const latestThumbnail = faceThumbnails[faceId][faceThumbnails[faceId].length - 1];
        const mainImg = document.createElement('img');
        mainImg.className = 'face-img';
        mainImg.src = latestThumbnail;
        mainImg.alt = `Face ${faceId}`;
        imgContainer.appendChild(mainImg);
        
        // Create thumbnails row if more than one thumbnail exists
        if (faceThumbnails[faceId].length > 1) {
            let thumbnailsContainer = faceElement.querySelector('.face-thumbnails');
            if (!thumbnailsContainer) {
                thumbnailsContainer = document.createElement('div');
                thumbnailsContainer.className = 'face-thumbnails';
                const contentContainer = faceElement.querySelector('.face-content');
                if (contentContainer) {
                    contentContainer.appendChild(thumbnailsContainer);
                }
            }
            
            // Clear existing thumbnails
            thumbnailsContainer.innerHTML = '';
            
            // Add thumbnails
            faceThumbnails[faceId].forEach((thumbnail, index) => {
                const thumbImg = document.createElement('img');
                thumbImg.className = 'face-thumbnail';
                thumbImg.src = thumbnail;
                thumbImg.alt = `Thumbnail ${index + 1}`;
                thumbImg.addEventListener('click', () => {
                    // When clicked, set this thumbnail as the main image
                    mainImg.src = thumbnail;
                });
                thumbnailsContainer.appendChild(thumbImg);
            });
        }
    }
    
    // Clean up thumbnail memory to prevent accumulation
    function cleanupThumbnails() {
        // Get a list of all current face IDs from the faceData object
        const currentFaceIds = Object.keys(faceData);
        const thumbnailsCount = Object.keys(faceThumbnails).length;
        
        // Step 1: Remove thumbnails for faces that no longer exist
        let removedCount = 0;
        for (const faceId in faceThumbnails) {
            if (!currentFaceIds.includes(faceId)) {
                delete faceThumbnails[faceId];
                removedCount++;
            }
        }
        
        // Step 2: Limit the number of thumbnails per face to conserve memory
        // For faces with many thumbnails, keep only the most recent ones
        for (const faceId in faceThumbnails) {
            if (faceThumbnails[faceId] && faceThumbnails[faceId].length > 5) {
                // Keep only 5 most recent thumbnails
                faceThumbnails[faceId] = faceThumbnails[faceId].slice(-5);
            }
        }
        
        // Step 3: Calculate and log memory cleanup stats
        if (removedCount > 0) {
            console.log(`Cleanup: Removed thumbnails for ${removedCount} faces that no longer exist`);
        }
        
        // Return cleanup stats
        return {
            facesRemoved: removedCount,
            remainingFaces: Object.keys(faceThumbnails).length,
            initialCount: thumbnailsCount
        };
    }
    
    // Change stream type
    function changeStreamType(type) {
        if (type === streamType) return;
        
        pendingModeChange = true;
        
        // Reset frame request state
        if (streamTimeout) {
            clearTimeout(streamTimeout);
            streamTimeout = null;
        }
        
        // Show loading indicator during switch
        streamImage.style.display = 'none';
        loadingIndicator.style.display = 'block';
        
        // Update type after a short delay to let current requests finish
        setTimeout(() => {
            streamType = type;
            
            // Update button active states
            regularStreamBtn.classList.toggle('active', type === 'regular');
            detectionStreamBtn.classList.toggle('active', type === 'detection');
            recognitionStreamBtn.classList.toggle('active', type === 'recognition');
            
            // Update stream type display
            let displayType = 'Regular';
            if (type === 'detection') displayType = 'Face Detection';
            if (type === 'recognition') displayType = 'Face Recognition';
            streamTypeText.textContent = `Stream Type: ${displayType}`;
            
            // Reset flags and restart stream
            frameRequestInProgress = false;
            pendingModeChange = false;
            
            // Restart stream
            if (isStreaming) {
                requestNextFrame();
            } else {
                startStream();
            }
        }, 300);
    }
    
    // Add a face to the recognition database (called when adding a new named face)
    async function addFace(faceId, currentFrame) {
        if (!faceId) {
            showToast('Face name cannot be empty', 'error');
            return false;
        }
        
        try {
            showToast('Adding face...', 'info');
            
            // If we have a current frame, use it directly
            if (currentFrame) {
                // Create a temporary form to send the frame
                const formData = new FormData();
                formData.append('frame', currentFrame, 'frame.jpg');
                formData.append('id', faceId);
                
                const response = await fetch(`/add_face?id=${encodeURIComponent(faceId)}`);
                
                if (response.ok) {
                    showToast(`Face "${faceId}" added successfully!`, 'success');
                    return true;
                } else {
                    const errorText = await response.text();
                    showToast(`Error adding face: ${errorText}`, 'error');
                    return false;
                }
            } else {
                // Otherwise, use the server's current frame
                const response = await fetch(`/add_face?id=${encodeURIComponent(faceId)}`);
                
                if (response.ok) {
                    showToast(`Face "${faceId}" added successfully!`, 'success');
                    return true;
                } else {
                    const errorText = await response.text();
                    showToast(`Error adding face: ${errorText}`, 'error');
                    return false;
                }
            }
        } catch (err) {
            showToast('Network error, please try again', 'error');
            console.error('Error adding face:', err);
            return false;
        }
    }
    
    // Show toast notification
    function showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        toastContainer.appendChild(toast);
        
        // Trigger reflow to enable transition
        toast.offsetHeight;
        
        // Show toast
        toast.classList.add('show');
        
        // Auto-hide toast after 3 seconds
        setTimeout(() => {
            toast.classList.remove('show');
            
            // Remove toast from DOM after transition
            setTimeout(() => {
                toastContainer.removeChild(toast);
            }, 300);
        }, 3000);
    }
    
    // Fetch face counts from server
    async function updateFaceCounts() {
        try {
            const response = await fetch('/get_face_counts');
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            
            faceData = await response.json();
            displayFaceCounts(faceData);
        } catch (err) {
            console.error('Error fetching face counts:', err);
        }
    }
    
    // Fetch a single frame to capture a face thumbnail
    async function fetchFrameAsBlob() {
        try {
            const response = await fetch(`/get_image?t=${Date.now()}`);
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            return await response.blob();
        } catch (err) {
            console.error('Error fetching frame for thumbnail:', err);
            return null;
        }
    }
    
    // Rename a face in the database
    async function renameFace(oldId, newId) {
        if (oldId === newId) return true;
        
        try {
            // Show a toast indicating we're renaming the face
            showToast(`Renaming ${oldId} to ${newId}...`, 'info');
            
            // Use the new dedicated rename endpoint for a more reliable rename operation
            const response = await fetch(`/rename_face?old_id=${encodeURIComponent(oldId)}&new_id=${encodeURIComponent(newId)}`);
            
            if (!response.ok) {
                const errorText = await response.text();
                showToast(`Error renaming face: ${errorText}`, 'error');
                return false;
            }
            
            // Update face thumbnails for the new ID
            if (faceThumbnails[oldId]) {
                faceThumbnails[newId] = [...faceThumbnails[oldId]];
                delete faceThumbnails[oldId];
            }
            
            showToast(`Successfully renamed face to "${newId}"!`, 'success');
            return true;
        } catch (err) {
            console.error('Error renaming face:', err);
            showToast('Network error during rename', 'error');
            return false;
        }
    }
    
    // Merge two faces
    async function mergeFaces(sourceFaceId, targetFaceId) {
        if (sourceFaceId === targetFaceId) {
            showToast('Cannot merge a face with itself', 'error');
            return false;
        }
        
        try {
            // Call merge API
            const response = await fetch(`/merge_faces?source=${encodeURIComponent(sourceFaceId)}&target=${encodeURIComponent(targetFaceId)}`);
            
            if (!response.ok) {
                const errorText = await response.text();
                showToast(`Error merging faces: ${errorText}`, 'error');
                return false;
            }
            
            // Update face thumbnails - combine source thumbnails into target
            if (faceThumbnails[sourceFaceId]) {
                if (!faceThumbnails[targetFaceId]) {
                    faceThumbnails[targetFaceId] = [];
                }
                
                // Add thumbnails from source to target (up to 5 total)
                for (let i = 0; i < faceThumbnails[sourceFaceId].length; i++) {
                    if (faceThumbnails[targetFaceId].length < 5) {
                        faceThumbnails[targetFaceId].push(faceThumbnails[sourceFaceId][i]);
                    }
                }
                
                // Remove source thumbnails
                delete faceThumbnails[sourceFaceId];
            }
            
            return true;
        } catch (err) {
            console.error('Error merging faces:', err);
            showToast('Network error during merge', 'error');
            return false;
        }
    }
    
    // Display face counts in the UI with improved layout
    function displayFaceCounts(faceData) {
        // Clear previous content
        faceCountsList.innerHTML = '';
        
        // Get total number of unique faces
        const totalFaces = Object.keys(faceData).length;
        totalFacesCount.textContent = `Total Faces: ${totalFaces}`;
        
        if (totalFaces === 0) {
            // Show placeholder if no faces
            const placeholder = document.createElement('div');
            placeholder.className = 'face-count-placeholder';
            placeholder.textContent = 'No faces detected yet';
            faceCountsList.appendChild(placeholder);
            return;
        }
        
        // Sort faces by count (highest first)
        const sortedFaces = Object.entries(faceData).sort((a, b) => b[1].count - a[1].count);
        
        // Create face count elements with improved UI
        sortedFaces.forEach(([faceId, data]) => {
            const faceItem = document.createElement('div');
            faceItem.className = 'face-count-item';
            faceItem.dataset.faceId = faceId;
            
            // Add class based on whether the face is named or not
            if (data.is_named) {
                faceItem.classList.add('named');
            } else {
                faceItem.classList.add('unnamed');
            }
            
            // Image container
            const imgContainer = document.createElement('div');
            imgContainer.className = 'face-img-container';
            
            // If we have thumbnails, use them, otherwise use placeholder
            if (faceThumbnails[faceId] && faceThumbnails[faceId].length > 0) {
                const img = document.createElement('img');
                img.className = 'face-img';
                img.src = faceThumbnails[faceId][faceThumbnails[faceId].length - 1]; // Latest thumbnail
                img.alt = `Face ${faceId}`;
                imgContainer.appendChild(img);
            } else {
                const placeholder = document.createElement('div');
                placeholder.className = 'face-img-placeholder';
                placeholder.innerHTML = '<i class="fas fa-user"></i>';
                imgContainer.appendChild(placeholder);
            }
            
            faceItem.appendChild(imgContainer);
            
            // Face content container
            const contentContainer = document.createElement('div');
            contentContainer.className = 'face-content';
            
            // Face header with name/ID and count
            const faceHeader = document.createElement('div');
            faceHeader.className = 'face-header';
            
            const nameSpan = document.createElement('div');
            nameSpan.className = 'face-name';
            nameSpan.dataset.faceId = faceId;
            nameSpan.textContent = faceId;
            
            const editButton = document.createElement('button');
            editButton.className = 'edit-button';
            editButton.innerHTML = '<i class="fas fa-edit"></i>';
            editButton.title = 'Edit name';
            editButton.addEventListener('click', () => {
                startEditingName(nameSpan);
            });
            
            faceHeader.appendChild(nameSpan);
            faceHeader.appendChild(editButton);
            
            // Face statistics
            const faceStats = document.createElement('div');
            faceStats.className = 'face-stats';
            faceStats.innerHTML = `<span>Seen ${data.count} times</span>`;
            
            contentContainer.appendChild(faceHeader);
            
            // Add thumbnails gallery if we have more than one thumbnail
            if (faceThumbnails[faceId] && faceThumbnails[faceId].length > 1) {
                const thumbnailsContainer = document.createElement('div');
                thumbnailsContainer.className = 'face-thumbnails';
                
                faceThumbnails[faceId].forEach((thumbnail, index) => {
                    const thumbImg = document.createElement('img');
                    thumbImg.className = 'face-thumbnail';
                    thumbImg.src = thumbnail;
                    thumbImg.alt = `Thumbnail ${index + 1}`;
                    thumbImg.addEventListener('click', () => {
                        // When clicked, set this thumbnail as the main image
                        const mainImg = imgContainer.querySelector('.face-img');
                        if (mainImg) {
                            mainImg.src = thumbnail;
                        }
                    });
                    thumbnailsContainer.appendChild(thumbImg);
                });
                
                contentContainer.appendChild(thumbnailsContainer);
            }
            
            contentContainer.appendChild(faceStats);
            faceItem.appendChild(contentContainer);
            
            // Add drag and drop handlers when in drag mode
            if (inDragMode) {
                faceItem.setAttribute('draggable', 'true');
                
                faceItem.addEventListener('dragstart', (e) => {
                    draggedFaceId = faceId;
                    faceItem.classList.add('dragging');
                    // Set drag ghost image
                    const img = faceItem.querySelector('.face-img');
                    if (img) {
                        const ghost = img.cloneNode(true);
                        ghost.style.width = '60px';
                        ghost.style.height = '60px';
                        ghost.style.position = 'absolute';
                        ghost.style.top = '-1000px';
                        document.body.appendChild(ghost);
                        e.dataTransfer.setDragImage(ghost, 30, 30);
                        setTimeout(() => document.body.removeChild(ghost), 0);
                    }
                    e.dataTransfer.setData('text/plain', faceId);
                });
                
                faceItem.addEventListener('dragend', () => {
                    faceItem.classList.remove('dragging');
                    draggedFaceId = null;
                });
                
                // Target for dropping other faces onto this face
                faceItem.addEventListener('dragover', (e) => {
                    if (draggedFaceId && draggedFaceId !== faceId) {
                        e.preventDefault(); // Allow drop
                        faceItem.classList.add('dragging-over');
                    }
                });
                
                faceItem.addEventListener('dragleave', () => {
                    faceItem.classList.remove('dragging-over');
                });
                
                faceItem.addEventListener('drop', async (e) => {
                    e.preventDefault();
                    faceItem.classList.remove('dragging-over');
                    
                    if (draggedFaceId && draggedFaceId !== faceId) {
                        showToast(`Merging ${draggedFaceId} into ${faceId}...`, 'info');
                        
                        const success = await mergeFaces(draggedFaceId, faceId);
                        if (success) {
                            showToast(`Successfully merged faces!`, 'success');
                            // Update face counts after merging
                            setTimeout(updateFaceCounts, 500);
                        }
                    }
                });
            }
            
            faceCountsList.appendChild(faceItem);
        });
        
        // Update any face thumbnails
        for (const faceId in faceThumbnails) {
            const faceElement = document.querySelector(`.face-count-item[data-face-id="${faceId}"]`);
            if (faceElement) {
                updateFaceThumbnails(faceElement, faceId);
            }
        }
    }
    
    // Start editing a face name
    function startEditingName(nameElement) {
        const faceId = nameElement.dataset.faceId;
        const currentName = nameElement.textContent;
        
        // Replace the name span with an input field
        const parent = nameElement.parentElement;
        
        // Create an edit container
        const editContainer = document.createElement('div');
        editContainer.className = 'face-edit-container';
        
        // Create input field
        const input = document.createElement('input');
        input.type = 'text';
        input.className = 'face-name-edit';
        input.value = currentName;
        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                saveNameEdit(faceId, input.value.trim());
            }
        });
        
        // Create action buttons
        const actionContainer = document.createElement('div');
        actionContainer.className = 'edit-actions';
        
        const saveButton = document.createElement('button');
        saveButton.textContent = 'Save';
        saveButton.addEventListener('click', () => {
            saveNameEdit(faceId, input.value.trim());
        });
        
        const cancelButton = document.createElement('button');
        cancelButton.textContent = 'Cancel';
        cancelButton.addEventListener('click', () => {
            cancelNameEdit();
        });
        
        // Add elements to container
        actionContainer.appendChild(saveButton);
        actionContainer.appendChild(cancelButton);
        editContainer.appendChild(input);
        editContainer.appendChild(actionContainer);
        
        // Replace name with edit container
        parent.replaceChild(editContainer, nameElement);
        
        // Focus the input
        input.focus();
        input.select();
    }
    
    // Save a name edit
    async function saveNameEdit(oldId, newId) {
        if (!newId) {
            showToast('Name cannot be empty', 'error');
            cancelNameEdit();
            return;
        }
        
        if (oldId === newId) {
            cancelNameEdit();
            return;
        }
        
        // Check if the new name already exists
        if (faceData[newId]) {
            const confirmMerge = confirm(`A face with name "${newId}" already exists. Do you want to merge this face into it?`);
            if (confirmMerge) {
                // Merge faces
                showToast(`Merging ${oldId} into ${newId}...`, 'info');
                
                const success = await mergeFaces(oldId, newId);
                if (success) {
                    showToast(`Successfully merged faces!`, 'success');
                    // Update face counts after merging
                    setTimeout(updateFaceCounts, 500);
                }
            }
            cancelNameEdit();
            return;
        }
        
        // Rename the face
        showToast(`Renaming ${oldId} to ${newId}...`, 'info');
        
        const success = await renameFace(oldId, newId);
        if (success) {
            showToast(`Successfully renamed face!`, 'success');
            // Update face counts after renaming
            setTimeout(updateFaceCounts, 500);
        }
        
        cancelNameEdit();
    }
    
    // Cancel a name edit
    function cancelNameEdit() {
        // Find any active edit containers
        const editContainer = document.querySelector('.face-edit-container');
        if (editContainer) {
            const parent = editContainer.parentElement;
            const faceId = parent.parentElement.parentElement.dataset.faceId;
            
            // Create a new name span
            const nameSpan = document.createElement('div');
            nameSpan.className = 'face-name';
            nameSpan.dataset.faceId = faceId;
            nameSpan.textContent = faceId;
            
            // Create a new edit button
            const editButton = document.createElement('button');
            editButton.className = 'edit-button';
            editButton.innerHTML = '<i class="fas fa-edit"></i>';
            editButton.title = 'Edit name';
            editButton.addEventListener('click', () => {
                startEditingName(nameSpan);
            });
            
            // Replace edit container with name and edit button
            parent.innerHTML = '';
            parent.appendChild(nameSpan);
            parent.appendChild(editButton);
        }
    }
    
    // Toggle drag mode on/off
    function toggleDragMode() {
        inDragMode = !inDragMode;
        droppedFaces = []; // Reset dropped faces when toggling
        
        if (inDragMode) {
            toggleDragModeBtn.textContent = 'Exit Drag Mode';
            toggleDragModeBtn.innerHTML = '<i class="fas fa-times"></i> Exit Drag Mode';
            dropzone.classList.add('active');
            updateDropzoneContent();
            
            // Setup dropzone
            dropzone.addEventListener('dragover', (e) => {
                e.preventDefault(); // Allow drop
                dropzone.style.backgroundColor = 'rgba(52, 152, 219, 0.2)';
            });
            
            dropzone.addEventListener('dragleave', () => {
                dropzone.style.backgroundColor = 'rgba(52, 152, 219, 0.05)';
            });
            
            dropzone.addEventListener('drop', async (e) => {
                e.preventDefault();
                dropzone.style.backgroundColor = 'rgba(52, 152, 219, 0.05)';
                
                // Get dropped face ID
                const droppedFaceId = e.dataTransfer.getData('text/plain');
                if (!droppedFaceId) return;
                
                // Check if already in the dropped faces
                if (droppedFaces.includes(droppedFaceId)) {
                    showToast(`Face "${droppedFaceId}" is already added to merge list`, 'info');
                    return;
                }
                
                // Add to dropped faces array
                droppedFaces.push(droppedFaceId);
                showToast(`Added "${droppedFaceId}" to merge list`, 'info');
                
                // Update dropzone content
                updateDropzoneContent();
            });
            
            // Refresh face counts to enable drag and drop
            updateFaceCounts();
        } else {
            toggleDragModeBtn.innerHTML = '<i class="fas fa-arrows-alt"></i> Drag to Merge';
            dropzone.classList.remove('active');
            
            // Refresh face counts to disable drag and drop
            updateFaceCounts();
        }
    }
    
    // Update dropzone content based on current dropped faces
    function updateDropzoneContent() {
        if (droppedFaces.length === 0) {
            // Initial state - no faces dropped yet
            dropzone.innerHTML = `
                <div class="dropzone-message">Drop faces here to merge them</div>
                <div class="drag-instruction">Drag and drop multiple faces to merge them together</div>
            `;
            return;
        }
        
        // Create content with dropped faces
        let content = `
            <div class="dropzone-message">Selected faces to merge (${droppedFaces.length})</div>
            <div class="dropped-faces-container" style="display: flex; flex-wrap: wrap; gap: 10px; margin: 10px 0;">
        `;
        
        // Add each face as a chip/badge
        droppedFaces.forEach(faceId => {
            content += `
                <div class="dropped-face" style="
                    background-color: rgba(52, 152, 219, 0.2); 
                    border-radius: 16px; 
                    padding: 5px 10px;
                    display: flex;
                    align-items: center;
                    gap: 5px;
                ">
                    <span>${faceId}</span>
                    <button 
                        class="remove-face-btn" 
                        data-face-id="${faceId}" 
                        style="background: none; border: none; color: #e74c3c; cursor: pointer; padding: 0; font-size: 14px;"
                    >
                        <i class="fas fa-times-circle"></i>
                    </button>
                </div>
            `;
        });
        
        content += `</div>`;
        
        // Only show merge controls if we have at least 2 faces
        if (droppedFaces.length >= 2) {
            content += `
                <div style="margin-top: 15px;">
                    <div style="margin-bottom: 10px;">Select a target face to merge into:</div>
                    <div style="display: flex; gap: 10px; align-items: center;">
                        <select id="mergeTargetSelect" style="flex: 1; padding: 8px; border-radius: 4px; border: 1px solid #ddd;">
                            ${droppedFaces.map(id => `<option value="${id}">${id}</option>`).join('')}
                        </select>
                        <button id="confirmMergeBtn" style="background-color: var(--warning-color);">
                            <i class="fas fa-object-group"></i> Merge All
                        </button>
                        <button id="clearDroppedBtn">
                            <i class="fas fa-trash"></i> Clear
                        </button>
                    </div>
                </div>
            `;
        } else {
            content += `
                <div class="drag-instruction">
                    Drop at least one more face to enable merging
                </div>
                <div style="margin-top: 10px;">
                    <button id="clearDroppedBtn">
                        <i class="fas fa-trash"></i> Clear
                    </button>
                </div>
            `;
        }
        
        // Update the dropzone content
        dropzone.innerHTML = content;
        
        // Add event listeners to the new buttons
        const removeButtons = dropzone.querySelectorAll('.remove-face-btn');
        removeButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                const faceId = e.currentTarget.dataset.faceId;
                droppedFaces = droppedFaces.filter(id => id !== faceId);
                updateDropzoneContent();
            });
        });
        
        const clearBtn = document.getElementById('clearDroppedBtn');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => {
                droppedFaces = [];
                updateDropzoneContent();
            });
        }
        
        const mergeBtn = document.getElementById('confirmMergeBtn');
        if (mergeBtn) {
            mergeBtn.addEventListener('click', async () => {
                const targetFaceId = document.getElementById('mergeTargetSelect').value;
                await mergeAllFaces(targetFaceId);
            });
        }
    }
    
    // Merge all collected faces into a target face
    async function mergeAllFaces(targetFaceId) {
        if (droppedFaces.length < 2) {
            showToast('Need at least 2 faces to merge', 'error');
            return;
        }
        
        // Get all faces except the target
        const sourceFaces = droppedFaces.filter(id => id !== targetFaceId);
        
        if (sourceFaces.length === 0) {
            showToast('No source faces to merge', 'error');
            return;
        }
        
        showToast(`Merging ${sourceFaces.length} faces into "${targetFaceId}"...`, 'info');
        
        // Track success count
        let successCount = 0;
        let errorMessages = [];
        
        // Create a copy of the faces array to prevent issues when elements are removed
        const facesToMerge = [...sourceFaces];
        
        // Perform merges sequentially
        for (const sourceFaceId of facesToMerge) {
            try {
                const success = await mergeFaces(sourceFaceId, targetFaceId);
                if (success) {
                    successCount++;
                } else {
                    errorMessages.push(`Failed to merge ${sourceFaceId}`);
                }
            } catch (err) {
                console.error(`Error merging ${sourceFaceId} into ${targetFaceId}:`, err);
                errorMessages.push(err.message || `Error merging ${sourceFaceId}`);
            }
        }
        
        // Show results
        if (successCount === facesToMerge.length) {
            showToast(`Successfully merged all ${successCount} faces into "${targetFaceId}"!`, 'success');
        } else if (successCount > 0) {
            showToast(`Merged ${successCount} out of ${facesToMerge.length} faces into "${targetFaceId}"`, 'info');
            if (errorMessages.length > 0) {
                console.error("Merge errors:", errorMessages);
            }
        } else {
            showToast('Failed to merge any faces', 'error');
            if (errorMessages.length > 0) {
                console.error("Merge errors:", errorMessages);
            }
        }
        
        // Clear dropped faces and update UI
        droppedFaces = [];
        updateDropzoneContent();
        
        // Update face counts after merging
        setTimeout(updateFaceCounts, 500);
    }
    
    // Set up auto-refresh for face counts when in recognition mode
    function setupFaceCountUpdates() {
        // Initial update
        if (streamType === 'recognition') {
            updateFaceCounts();
        }
        
        // Start interval for updates when in recognition mode
        clearInterval(faceCountUpdateInterval);
        faceCountUpdateInterval = setInterval(() => {
            if (streamType === 'recognition') {
                updateFaceCounts();
            }
        }, 5000); // Update every 5 seconds when in recognition mode
        
        // Set up the thumbnail cleanup interval
        clearInterval(thumbnailCleanupInterval);
        thumbnailCleanupInterval = setInterval(() => {
            // Run cleanup every 30 seconds to prevent memory issues
            const stats = cleanupThumbnails();
            if (stats.facesRemoved > 0) {
                console.log(`Thumbnail cleanup: Removed ${stats.facesRemoved} faces, ${stats.remainingFaces} remaining`);
            }
        }, 30000); // Clean up every 30 seconds
        
        // Set up attendance updates
        clearInterval(attendanceUpdateInterval);
        attendanceUpdateInterval = setInterval(() => {
            // Only update attendance if we're viewing the attendance tab
            if (document.getElementById('attendance-tab').classList.contains('active')) {
                updateAttendance();
            }
        }, 60000); // Update attendance every 1 minute
    }
    
    // Event listeners
    // Stream type buttons
    regularStreamBtn.addEventListener('click', () => changeStreamType('regular'));
    detectionStreamBtn.addEventListener('click', () => changeStreamType('detection'));
    recognitionStreamBtn.addEventListener('click', () => changeStreamType('recognition'));
    
    // Face management
    refreshFaceCountsBtn.addEventListener('click', updateFaceCounts);
    refreshAttendanceBtn.addEventListener('click', updateAttendance);
    
    // Drag mode controls
    toggleDragModeBtn.addEventListener('click', toggleDragMode);
    
    // Extend the changeStreamType function to update face counts when switching to recognition mode
    const originalChangeStreamType = changeStreamType;
    changeStreamType = function(type) {
        originalChangeStreamType(type);
        // When switching to recognition mode, update face counts
        if (type === 'recognition') {
            setTimeout(updateFaceCounts, 1000); // Slight delay to let recognition start
        }
    };
    
    // Setup face count updates
    setupFaceCountUpdates();
    
    // Initialize tab system
    setupTabs();
    
    // Start with regular stream
    startStream();
    
    // Test connection initially
    fetch('/test')
        .catch(err => {
            showToast('Error connecting to server', 'error');
            console.error('Server connection error:', err);
        });
});

// Attendance Settings and Class Definitions
class AttendanceSettings {
    constructor() {
        // Default values
        this.expectedHour = 9;
        this.expectedMinute = 0;
        this.earlyThresholdMinutes = 30;
        this.lateThresholdMinutes = 15;
        
        // Load settings from localStorage if available
        this.loadSettings();
    }
    
    loadSettings() {
        const savedSettings = localStorage.getItem('attendanceSettings');
        if (savedSettings) {
            try {
                const settings = JSON.parse(savedSettings);
                this.expectedHour = settings.expectedHour || this.expectedHour;
                this.expectedMinute = settings.expectedMinute || this.expectedMinute;
                this.earlyThresholdMinutes = settings.earlyThresholdMinutes || this.earlyThresholdMinutes;
                this.lateThresholdMinutes = settings.lateThresholdMinutes || this.lateThresholdMinutes;
            } catch (e) {
                console.error('Error loading attendance settings:', e);
            }
        }
    }
    
    saveSettings() {
        const settings = {
            expectedHour: this.expectedHour,
            expectedMinute: this.expectedMinute,
            earlyThresholdMinutes: this.earlyThresholdMinutes,
            lateThresholdMinutes: this.lateThresholdMinutes
        };
        localStorage.setItem('attendanceSettings', JSON.stringify(settings));
    }
    
    getExpectedTimeFormatted() {
        const hour = this.expectedHour;
        const minute = this.expectedMinute;
        
        // Format in 12-hour format
        let period = 'AM';
        let displayHour = hour;
        
        if (hour >= 12) {
            period = 'PM';
            displayHour = hour === 12 ? 12 : hour - 12;
        }
        if (displayHour === 0) {
            displayHour = 12;
        }
        
        return `${displayHour}:${minute.toString().padStart(2, '0')} ${period}`;
    }
    
    getEarlyThresholdFormatted() {
        // Calculate the early threshold time
        const expectedDate = new Date();
        expectedDate.setHours(this.expectedHour, this.expectedMinute, 0, 0);
        
        const earlyDate = new Date(expectedDate.getTime() - (this.earlyThresholdMinutes * 60 * 1000));
        
        // Format in 12-hour format
        const hour = earlyDate.getHours();
        const minute = earlyDate.getMinutes();
        
        let period = 'AM';
        let displayHour = hour;
        
        if (hour >= 12) {
            period = 'PM';
            displayHour = hour === 12 ? 12 : hour - 12;
        }
        if (displayHour === 0) {
            displayHour = 12;
        }
        
        return `${displayHour}:${minute.toString().padStart(2, '0')} ${period}`;
    }
    
    getLateThresholdFormatted() {
        // Calculate the late threshold time
        const expectedDate = new Date();
        expectedDate.setHours(this.expectedHour, this.expectedMinute, 0, 0);
        
        const lateDate = new Date(expectedDate.getTime() + (this.lateThresholdMinutes * 60 * 1000));
        
        // Format in 12-hour format
        const hour = lateDate.getHours();
        const minute = lateDate.getMinutes();
        
        let period = 'AM';
        let displayHour = hour;
        
        if (hour >= 12) {
            period = 'PM';
            displayHour = hour === 12 ? 12 : hour - 12;
        }
        if (displayHour === 0) {
            displayHour = 12;
        }
        
        return `${displayHour}:${minute.toString().padStart(2, '0')} ${period}`;
    }
    
    getExpectedDateTime() {
        const today = new Date();
        today.setHours(this.expectedHour, this.expectedMinute, 0, 0);
        return today;
    }
    
    getEarlyThresholdDateTime() {
        const earlyDate = this.getExpectedDateTime();
        earlyDate.setMinutes(earlyDate.getMinutes() - this.earlyThresholdMinutes);
        return earlyDate;
    }
    
    getLateThresholdDateTime() {
        const lateDate = this.getExpectedDateTime();
        lateDate.setMinutes(lateDate.getMinutes() + this.lateThresholdMinutes);
        return lateDate;
    }
    
    updateTimeDescriptions() {
        // Update the UI elements to show the current thresholds
        document.getElementById('earlyTimeDesc').textContent = `Before ${this.getEarlyThresholdFormatted()}`;
        document.getElementById('onTimeTimeDesc').textContent = `${this.getEarlyThresholdFormatted()} - ${this.getLateThresholdFormatted()}`;
        document.getElementById('lateTimeDesc').textContent = `After ${this.getLateThresholdFormatted()}`;
    }
}

class AttendancePerson {
    constructor(id, data) {
        this.id = id;
        this.name = id; // Default name is the ID
        this.isNamed = data.is_named || false;
        this.count = data.count || 0;
        this.thumbnails = []; // Store thumbnail URLs
        
        // Arrival time data
        this.firstSeen = data.first_seen ? new Date(data.first_seen) : null;
        this.lastSeen = data.last_seen ? new Date(data.last_seen) : null;
        
        // Initialize with any thumbnails
        if (faceThumbnails[id] && faceThumbnails[id].length > 0) {
            this.thumbnails = [...faceThumbnails[id]];
        }
    }
    
    getLatestThumbnail() {
        if (this.thumbnails.length > 0) {
            return this.thumbnails[this.thumbnails.length - 1];
        }
        return null;
    }
    
    getArrivalTime() {
        if (this.firstSeen) {
            return this.firstSeen.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                hour12: true 
            });
        }
        return 'Unknown';
    }
    
    getArrivalStatus(settings) {
        if (!this.firstSeen) return 'unknown';
        
        const earlyThreshold = settings.getEarlyThresholdDateTime();
        const lateThreshold = settings.getLateThresholdDateTime();
        
        if (this.firstSeen < earlyThreshold) {
            return 'early';
        } else if (this.firstSeen <= lateThreshold) {
            return 'on-time';
        } else {
            return 'late';
        }
    }
    
    getStatusLabel(settings) {
        const status = this.getArrivalStatus(settings);
        switch (status) {
            case 'early': return 'Early';
            case 'on-time': return 'On Time';
            case 'late': return 'Late';
            default: return 'Unknown';
        }
    }
}

class AttendanceManager {
    constructor() {
        this.settings = new AttendanceSettings();
        this.present = []; // Stores AttendancePerson objects
        this.absent = []; // Stores people who are known but not present
        this.knownPeople = new Set(); // Stores all known face IDs
        
        // Update settings UI with current values
        this._initSettingsUI();
    }
    
    _initSettingsUI() {
        document.getElementById('expectedHour').value = this.settings.expectedHour;
        document.getElementById('expectedMinute').value = this.settings.expectedMinute;
        document.getElementById('earlyThreshold').value = this.settings.earlyThresholdMinutes;
        document.getElementById('lateThreshold').value = this.settings.lateThresholdMinutes;
        
        // Update time descriptions
        this.settings.updateTimeDescriptions();
    }
    
    async loadAttendanceData() {
        try {
            // First, get the list of all known people
            await this.loadKnownPeople();
            
            // Then get current face data
            const response = await fetch('/get_face_counts');
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            
            const data = await response.json();
            
            // Process present people
            this.present = [];
            const namedFaces = Object.entries(data).filter(([_, faceData]) => faceData.is_named);
            
            namedFaces.forEach(([faceId, faceData]) => {
                this.present.push(new AttendancePerson(faceId, faceData));
            });
            
            // Sort present people by arrival time
            this.present.sort((a, b) => {
                if (!a.firstSeen) return 1;
                if (!b.firstSeen) return -1;
                return a.firstSeen.getTime() - b.firstSeen.getTime();
            });
            
            // Determine absent people (in known list but not in present list)
            this.absent = [];
            const presentIds = new Set(this.present.map(person => person.id));
            
            this.knownPeople.forEach(personId => {
                if (!presentIds.has(personId)) {
                    // Create a placeholder absent person
                    const absentPerson = new AttendancePerson(personId, { is_named: true });
                    this.absent.push(absentPerson);
                }
            });
            
            return {
                present: this.present,
                absent: this.absent
            };
        } catch (err) {
            console.error('Error fetching attendance data:', err);
            throw err;
        }
    }
    
    async loadKnownPeople() {
        try {
            // Get all known faces from the server
            const response = await fetch('/get_known_faces');
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            
            const data = await response.json();
            
            // Add all known faces to the set
            this.knownPeople = new Set(data.known_faces || []);
            
            return this.knownPeople;
        } catch (err) {
            console.error('Error fetching known people:', err);
            // Fall back to using face thumbnails as a source of known people
            this.knownPeople = new Set(Object.keys(faceThumbnails || {}).filter(id => {
                // Consider only named faces (those without UUID-like patterns)
                return !/^[0-9a-f]{8}-[0-9a-f]{4}/.test(id);
            }));
            
            return this.knownPeople;
        }
    }
    
    getPresentCount() {
        return this.present.length;
    }
    
    getAbsentCount() {
        return this.absent.length;
    }
    
    getTotalCount() {
        return this.knownPeople.size;
    }
    
    getAttendanceRate() {
        if (this.knownPeople.size === 0) return 0;
        return Math.round((this.present.length / this.knownPeople.size) * 100);
    }
    
    getEarliestArrival() {
        let earliest = null;
        
        for (const person of this.present) {
            if (person.firstSeen) {
                if (!earliest || person.firstSeen < earliest) {
                    earliest = person.firstSeen;
                }
            }
        }
        
        return earliest;
    }
    
    getLatestArrival() {
        let latest = null;
        
        for (const person of this.present) {
            if (person.firstSeen) {
                if (!latest || person.firstSeen > latest) {
                    latest = person.firstSeen;
                }
            }
        }
        
        return latest;
    }
    
    getArrivalsByStatus() {
        const early = [];
        const onTime = [];
        const late = [];
        
        for (const person of this.present) {
            const status = person.getArrivalStatus(this.settings);
            
            switch (status) {
                case 'early':
                    early.push(person);
                    break;
                case 'on-time':
                    onTime.push(person);
                    break;
                case 'late':
                    late.push(person);
                    break;
            }
        }
        
        return { early, onTime, late };
    }
    
    updateAttendanceUI() {
        // Update attendance metrics
        document.getElementById('presentCount').textContent = this.getPresentCount();
        document.getElementById('absentCount').textContent = this.getAbsentCount();
        document.getElementById('attendanceRate').textContent = `${this.getAttendanceRate()}%`;
        
        // Update progress bar
        updateAttendanceChart(this.getPresentCount(), this.getAbsentCount());
        
        // Update arrival times
        const earliestArrival = this.getEarliestArrival();
        const latestArrival = this.getLatestArrival();
        
        if (earliestArrival) {
            document.getElementById('earliestArrival').textContent = earliestArrival.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                hour12: true 
            });
        } else {
            document.getElementById('earliestArrival').textContent = '--:--';
        }
        
        if (latestArrival) {
            document.getElementById('latestArrival').textContent = latestArrival.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                hour12: true 
            });
        } else {
            document.getElementById('latestArrival').textContent = '--:--';
        }
        
        // Update arrival status counts
        const { early, onTime, late } = this.getArrivalsByStatus();
        document.getElementById('earlyCount').textContent = early.length;
        document.getElementById('onTimeCount').textContent = onTime.length;
        document.getElementById('lateCount').textContent = late.length;
        
        // Render attendance lists
        this.renderAttendanceList();
        this.renderAbsenteesList();
    }
    
    renderAttendanceList() {
        const attendanceList = document.getElementById('attendanceList');
        attendanceList.innerHTML = '';
        
        if (this.present.length === 0) {
            const placeholder = document.createElement('div');
            placeholder.className = 'attendance-placeholder';
            placeholder.textContent = 'No registered people detected today';
            attendanceList.appendChild(placeholder);
            return;
        }
        
        // Create attendance items for each present person
        this.present.forEach(person => {
            const attendanceItem = document.createElement('div');
            attendanceItem.className = 'attendance-item';
            
            // Add class based on arrival status
            const status = person.getArrivalStatus(this.settings);
            attendanceItem.classList.add(`${status}-arrival`);
            
            // Image container
            const imgContainer = document.createElement('div');
            imgContainer.className = 'attendance-img-container';
            
            // If we have thumbnails, use them, otherwise use placeholder
            const thumbnail = person.getLatestThumbnail();
            if (thumbnail) {
                const img = document.createElement('img');
                img.className = 'attendance-img';
                img.src = thumbnail;
                img.alt = `Face ${person.id}`;
                imgContainer.appendChild(img);
            } else {
                const placeholder = document.createElement('div');
                placeholder.className = 'attendance-img-placeholder';
                placeholder.innerHTML = '<i class="fas fa-user"></i>';
                imgContainer.appendChild(placeholder);
            }
            
            attendanceItem.appendChild(imgContainer);
            
            // Attendance content
            const contentContainer = document.createElement('div');
            contentContainer.className = 'attendance-content';
            
            // Person name
            const nameElement = document.createElement('div');
            nameElement.className = 'attendance-name';
            nameElement.textContent = person.id;
            
            // Appearance count
            const countElement = document.createElement('div');
            countElement.className = 'attendance-count';
            countElement.textContent = `Seen ${person.count} times today`;
            
            // Arrival time
            const timeContainer = document.createElement('div');
            timeContainer.className = 'attendance-time-container';
            
            const arrivalLabel = document.createElement('span');
            arrivalLabel.className = `arrival-label ${status}`;
            arrivalLabel.textContent = person.getStatusLabel(this.settings);
            
            const timeElement = document.createElement('span');
            timeElement.className = 'attendance-time';
            timeElement.textContent = person.getArrivalTime();
            
            timeContainer.appendChild(arrivalLabel);
            timeContainer.appendChild(timeElement);
            
            contentContainer.appendChild(nameElement);
            contentContainer.appendChild(countElement);
            contentContainer.appendChild(timeContainer);
            attendanceItem.appendChild(contentContainer);
            
            attendanceList.appendChild(attendanceItem);
        });
    }
    
    renderAbsenteesList() {
        const absenteesList = document.getElementById('absenteesList');
        absenteesList.innerHTML = '';
        
        if (this.absent.length === 0) {
            const placeholder = document.createElement('div');
            placeholder.className = 'attendance-placeholder';
            placeholder.textContent = 'All expected people are present';
            absenteesList.appendChild(placeholder);
            return;
        }
        
        // Create attendance items for each absent person
        this.absent.forEach(person => {
            const attendanceItem = document.createElement('div');
            attendanceItem.className = 'attendance-item';
            
            // Image container
            const imgContainer = document.createElement('div');
            imgContainer.className = 'attendance-img-container';
            
            // If we have thumbnails, use them, otherwise use placeholder
            const thumbnail = person.getLatestThumbnail();
            if (thumbnail) {
                const img = document.createElement('img');
                img.className = 'attendance-img';
                img.src = thumbnail;
                img.alt = `Face ${person.id}`;
                imgContainer.appendChild(img);
            } else {
                const placeholder = document.createElement('div');
                placeholder.className = 'attendance-img-placeholder';
                placeholder.innerHTML = '<i class="fas fa-user-xmark"></i>';
                imgContainer.appendChild(placeholder);
            }
            
            attendanceItem.appendChild(imgContainer);
            
            // Attendance content
            const contentContainer = document.createElement('div');
            contentContainer.className = 'attendance-content';
            
            // Person name
            const nameElement = document.createElement('div');
            nameElement.className = 'attendance-name';
            nameElement.textContent = person.id;
            
            // Absence message
            const statusElement = document.createElement('div');
            statusElement.className = 'attendance-count';
            statusElement.innerHTML = '<i class="fas fa-calendar-xmark"></i> Not seen today';
            
            contentContainer.appendChild(nameElement);
            contentContainer.appendChild(statusElement);
            attendanceItem.appendChild(contentContainer);
            
            absenteesList.appendChild(attendanceItem);
        });
    }
    
    saveSettings() {
        // Get values from form
        const expectedHour = parseInt(document.getElementById('expectedHour').value);
        const expectedMinute = parseInt(document.getElementById('expectedMinute').value);
        const earlyThreshold = parseInt(document.getElementById('earlyThreshold').value);
        const lateThreshold = parseInt(document.getElementById('lateThreshold').value);
        
        // Update settings
        this.settings.expectedHour = expectedHour;
        this.settings.expectedMinute = expectedMinute;
        this.settings.earlyThresholdMinutes = earlyThreshold;
        this.settings.lateThresholdMinutes = lateThreshold;
        
        // Save settings
        this.settings.saveSettings();
        
        // Update UI
        this.settings.updateTimeDescriptions();
        
        // Re-calculate attendance statuses
        this.updateAttendanceUI();
        
        return true;
    }
}

// Initialize the attendance manager
let attendanceManager;

document.addEventListener('DOMContentLoaded', () => {
    // Initialize attendance manager
    attendanceManager = new AttendanceManager();
    
    // Add event listeners for attendance settings
    const toggleSettingsBtn = document.getElementById('toggleAttendanceSettings');
    const closeSettingsBtn = document.getElementById('closeAttendanceSettings');
    const saveSettingsBtn = document.getElementById('saveAttendanceSettings');
    const settingsPanel = document.getElementById('attendanceSettings');
    
    toggleSettingsBtn.addEventListener('click', () => {
        settingsPanel.style.display = settingsPanel.style.display === 'none' ? 'block' : 'none';
    });
    
    closeSettingsBtn.addEventListener('click', () => {
        settingsPanel.style.display = 'none';
    });
    
    saveSettingsBtn.addEventListener('click', () => {
        if (attendanceManager.saveSettings()) {
            showToast('Attendance settings saved', 'success');
            settingsPanel.style.display = 'none';
        }
    });
    
    // Add event listener for refresh attendance button
    const refreshAttendanceBtn = document.getElementById('refreshAttendance');
    refreshAttendanceBtn.addEventListener('click', updateAttendance);
});

// Process face data into attendance format - Modified to use the AttendanceManager
async function updateAttendance() {
    try {
        // Set today's date in the header - use current date dynamically
        const today = new Date();
        const dateOptions = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        document.getElementById('attendanceDate').textContent = today.toLocaleDateString('en-US', dateOptions);
        
        // Load attendance data
        await attendanceManager.loadAttendanceData();
        
        // Update the UI
        attendanceManager.updateAttendanceUI();
    } catch (err) {
        console.error('Error updating attendance:', err);
        showToast('Error updating attendance data', 'error');
    }
}
