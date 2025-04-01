document.addEventListener('DOMContentLoaded', () => {
    // DOM elements
    const streamImage = document.getElementById('streamImage');
    const loadingIndicator = document.getElementById('loadingIndicator');
    const streamTypeText = document.getElementById('streamType');
    const fpsCounter = document.getElementById('fpsCounter');
    const regularStreamBtn = document.getElementById('regularStream');
    const detectionStreamBtn = document.getElementById('detectionStream');
    const recognitionStreamBtn = document.getElementById('recognitionStream');
    const faceIdInput = document.getElementById('faceId');
    const addFaceBtn = document.getElementById('addFace');
    const faceStatus = document.getElementById('faceStatus');
    
    // Get DOM elements for face counts
    const refreshFaceCountsBtn = document.getElementById('refreshFaceCounts');
    const totalFacesCount = document.getElementById('totalFacesCount');
    const faceCountsList = document.getElementById('faceCountsList');
    
    // Variables for face count updates
    let faceCountUpdateInterval = null;
    
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
    
    // Add a face to the recognition database
    async function addFace() {
        const faceId = faceIdInput.value.trim();
        if (!faceId) {
            showStatus('Please enter a name or ID', 'error');
            return;
        }
        
        try {
            showStatus('Adding face...', '');
            
            const response = await fetch(`/add_face?id=${encodeURIComponent(faceId)}`);
            
            if (response.ok) {
                showStatus(`Face "${faceId}" added successfully!`, 'success');
                faceIdInput.value = '';
            } else {
                const errorText = await response.text();
                showStatus(`Error: ${errorText}`, 'error');
            }
        } catch (err) {
            showStatus('Network error, please try again', 'error');
            console.error('Error adding face:', err);
        }
    }
    
    // Display status messages
    function showStatus(message, type) {
        faceStatus.textContent = message;
        faceStatus.className = 'status-message';
        if (type) {
            faceStatus.classList.add(type);
        }
        
        // Clear success messages after 3 seconds
        if (type === 'success') {
            setTimeout(() => {
                if (faceStatus.classList.contains('success')) {
                    faceStatus.textContent = '';
                    faceStatus.className = 'status-message';
                }
            }, 3000);
        }
    }
    
    // Fetch face counts from server
    async function updateFaceCounts() {
        try {
            const response = await fetch('/get_face_counts');
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            
            const faceData = await response.json();
            displayFaceCounts(faceData);
        } catch (err) {
            console.error('Error fetching face counts:', err);
        }
    }
    
    // Display face counts in the UI
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
        
        // Create face count elements
        sortedFaces.forEach(([faceId, data]) => {
            const faceItem = document.createElement('div');
            faceItem.className = 'face-count-item';
            if (data.is_named) {
                faceItem.classList.add('named');
            }
            
            const nameSpan = document.createElement('span');
            nameSpan.textContent = faceId;
            
            const countSpan = document.createElement('span');
            countSpan.textContent = `${data.count} times`;
            
            faceItem.appendChild(nameSpan);
            faceItem.appendChild(countSpan);
            faceCountsList.appendChild(faceItem);
        });
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
    
    // Add event listener for manual refresh of face counts
    refreshFaceCountsBtn.addEventListener('click', updateFaceCounts);
    
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
    
    // Event listeners
    regularStreamBtn.addEventListener('click', () => changeStreamType('regular'));
    detectionStreamBtn.addEventListener('click', () => changeStreamType('detection'));
    recognitionStreamBtn.addEventListener('click', () => changeStreamType('recognition'));
    addFaceBtn.addEventListener('click', addFace);
    
    // Allow pressing Enter in the face ID input to add a face
    faceIdInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            addFace();
        }
    });
    
    // Start with regular stream
    startStream();
    
    // Test connection initially
    fetch('/test')
        .catch(err => {
            showStatus('Error connecting to server', 'error');
            console.error('Server connection error:', err);
        });
});
