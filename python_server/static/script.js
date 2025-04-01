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
    
    // Stream settings
    let streamType = 'regular';
    let isStreaming = false;
    let streamInterval;
    let frameCount = 0;
    let lastFpsUpdateTime = Date.now();
    
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
        
        // Clear any existing interval
        if (streamInterval) {
            clearInterval(streamInterval);
        }
        
        // Start streaming
        streamInterval = setInterval(updateFrame, 40); // ~25 FPS (40ms interval)
    }
    
    // Update the current frame
    function updateFrame() {
        // Create a unique URL to prevent browser caching
        const url = `${streamUrls[streamType]}?t=${Date.now()}`;
        
        // Preload the image
        const img = new Image();
        img.onload = function() {
            // Once loaded, update the displayed image
            streamImage.src = this.src;
            
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
        };
        
        img.onerror = function() {
            console.error('Error loading stream frame');
        };
        
        img.src = url;
    }
    
    // Change stream type
    function changeStreamType(type) {
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
        
        // Restart stream to apply changes
        startStream();
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
