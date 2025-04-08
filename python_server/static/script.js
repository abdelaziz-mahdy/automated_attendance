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
    
    // Variables for face tracking and merging
    let faceCountUpdateInterval = null;
    let inDragMode = false;
    let draggedFaceId = null;
    let faceData = {};
    let faceThumbnails = {}; // Store thumbnails for faces
    
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
                
                // If in recognition mode, we might want to capture a frame as a thumbnail
                if (streamType === 'recognition' && !document.hidden) {
                    // We don't need to capture every frame, just occasionally
                    if (Math.random() < 0.05) { // 5% chance per frame
                        await captureFrameForThumbnails(blob);
                    }
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
            // First add a new face with the new ID
            // We need to get a current frame
            const blob = await fetchFrameAsBlob();
            if (!blob) {
                showToast('Failed to capture frame for renaming', 'error');
                return false;
            }
            
            // Create temporary image element to display this frame
            const img = new Image();
            img.src = URL.createObjectURL(blob);
            
            await new Promise(resolve => {
                img.onload = resolve;
            });
            
            // We need to update the stream image temporarily to add the new face
            const originalSrc = streamImage.src;
            streamImage.src = img.src;
            
            // Now add the new face
            const addResponse = await fetch(`/add_face?id=${encodeURIComponent(newId)}`);
            if (!addResponse.ok) {
                // Restore original image
                streamImage.src = originalSrc;
                URL.revokeObjectURL(img.src);
                const errorText = await addResponse.text();
                showToast(`Error creating new face: ${errorText}`, 'error');
                return false;
            }
            
            // Merge the old face into the new one
            const mergeResponse = await fetch(`/merge_faces?source=${encodeURIComponent(oldId)}&target=${encodeURIComponent(newId)}`);
            
            // Restore original image
            streamImage.src = originalSrc;
            URL.revokeObjectURL(img.src);
            
            if (!mergeResponse.ok) {
                const errorText = await mergeResponse.text();
                showToast(`Error merging faces: ${errorText}`, 'error');
                return false;
            }
            
            // Update face thumbnails for the new ID
            if (faceThumbnails[oldId]) {
                faceThumbnails[newId] = [...faceThumbnails[oldId]];
                delete faceThumbnails[oldId];
            }
            
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
        
        if (inDragMode) {
            toggleDragModeBtn.textContent = 'Exit Drag Mode';
            toggleDragModeBtn.innerHTML = '<i class="fas fa-times"></i> Exit Drag Mode';
            dropzone.classList.add('active');
            
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
                
                // Show dropdown to select target face
                const targetFaces = Object.keys(faceData).filter(id => id !== droppedFaceId);
                if (targetFaces.length === 0) {
                    showToast('No other faces to merge with', 'error');
                    return;
                }
                
                // Replace dropzone content with merge selection
                const originalContent = dropzone.innerHTML;
                dropzone.innerHTML = `
                    <div style="margin-bottom: 10px;">Merge "${droppedFaceId}" into:</div>
                    <div style="display: flex; gap: 10px; align-items: center;">
                        <select id="mergeTargetSelect" style="flex: 1; padding: 8px; border-radius: 4px; border: 1px solid #ddd;">
                            ${targetFaces.map(id => `<option value="${id}">${id}</option>`).join('')}
                        </select>
                        <button id="confirmMergeBtn" style="background-color: var(--warning-color);">Merge</button>
                        <button id="cancelMergeBtn">Cancel</button>
                    </div>
                `;
                
                // Set up event listeners for new buttons
                document.getElementById('confirmMergeBtn').addEventListener('click', async () => {
                    const targetFaceId = document.getElementById('mergeTargetSelect').value;
                    
                    showToast(`Merging ${droppedFaceId} into ${targetFaceId}...`, 'info');
                    
                    const success = await mergeFaces(droppedFaceId, targetFaceId);
                    if (success) {
                        showToast(`Successfully merged faces!`, 'success');
                        // Update face counts after merging
                        setTimeout(updateFaceCounts, 500);
                    }
                    
                    // Restore original dropzone content
                    dropzone.innerHTML = originalContent;
                });
                
                document.getElementById('cancelMergeBtn').addEventListener('click', () => {
                    // Restore original dropzone content
                    dropzone.innerHTML = originalContent;
                });
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
    }
    
    // Event listeners
    // Stream type buttons
    regularStreamBtn.addEventListener('click', () => changeStreamType('regular'));
    detectionStreamBtn.addEventListener('click', () => changeStreamType('detection'));
    recognitionStreamBtn.addEventListener('click', () => changeStreamType('recognition'));
    
    // Face management
    refreshFaceCountsBtn.addEventListener('click', updateFaceCounts);
    
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
    
    // Start with regular stream
    startStream();
    
    // Test connection initially
    fetch('/test')
        .catch(err => {
            showToast('Error connecting to server', 'error');
            console.error('Server connection error:', err);
        });
});
