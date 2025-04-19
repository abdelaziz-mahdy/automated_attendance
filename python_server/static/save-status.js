/**
 * Save Status UI Component
 * Displays auto-save status and countdown in the UI
 */
document.addEventListener('DOMContentLoaded', () => {
    // Create save status indicator if it doesn't exist
    if (!document.getElementById('saveStatusIndicator')) {
        createSaveStatusIndicator();
    }
    
    // Start polling for save status
    startSaveStatusPolling();
});

/**
 * Create the save status indicator UI element
 */
function createSaveStatusIndicator() {
    // Create container element
    const container = document.createElement('div');
    container.id = 'saveStatusIndicator';
    container.className = 'save-status-indicator';
    
    // Create save status icon
    const icon = document.createElement('div');
    icon.className = 'save-icon';
    icon.innerHTML = '<i class="fas fa-save"></i>';
    
    // Create status text element
    const statusText = document.createElement('div');
    statusText.id = 'saveStatusText';
    statusText.className = 'save-status-text';
    statusText.textContent = 'Auto-save: Idle';
    
    // Create progress bar container
    const progressContainer = document.createElement('div');
    progressContainer.className = 'save-progress-container';
    
    // Create progress bar
    const progressBar = document.createElement('div');
    progressBar.id = 'saveProgressBar';
    progressBar.className = 'save-progress-bar';
    
    // Add elements to container
    progressContainer.appendChild(progressBar);
    container.appendChild(icon);
    container.appendChild(statusText);
    container.appendChild(progressContainer);
    
    // Add CSS for save status indicator
    addSaveStatusStyles();
    
    // Add to page - find a good location
    const footer = document.querySelector('footer');
    if (footer) {
        // Add before footer if it exists
        document.body.insertBefore(container, footer);
    } else {
        // Otherwise add to end of body
        document.body.appendChild(container);
    }
}

/**
 * Add CSS styles for save status indicator
 */
function addSaveStatusStyles() {
    if (document.getElementById('saveStatusStyles')) return;
    
    const styleElement = document.createElement('style');
    styleElement.id = 'saveStatusStyles';
    styleElement.textContent = `
        .save-status-indicator {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background-color: rgba(255, 255, 255, 0.9);
            border-radius: 8px;
            padding: 10px 15px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            display: flex;
            flex-direction: column;
            align-items: start;
            gap: 5px;
            z-index: 1000;
            font-size: 14px;
            transition: opacity 0.3s, transform 0.3s;
            opacity: 0.7;
        }
        
        .save-status-indicator:hover {
            opacity: 1;
            transform: translateY(-3px);
        }
        
        .save-icon {
            color: #777;
            margin-right: 8px;
        }
        
        .save-status-indicator.saving .save-icon {
            color: #3498db;
            animation: pulse 1s infinite;
        }
        
        .save-status-text {
            flex: 1;
            white-space: nowrap;
        }
        
        .save-progress-container {
            width: 100%;
            height: 4px;
            background-color: #eee;
            border-radius: 2px;
            overflow: hidden;
        }
        
        .save-progress-bar {
            height: 100%;
            width: 0%;
            background-color: #3498db;
            transition: width 1s linear;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    `;
    
    document.head.appendChild(styleElement);
}

/**
 * Start polling for save status
 */
function startSaveStatusPolling() {
    // Poll every 3 seconds
    setInterval(updateSaveStatus, 3000);
    
    // Initial update
    updateSaveStatus();
}

/**
 * Update save status from server
 */
async function updateSaveStatus() {
    try {
        const response = await fetch('/get_save_status');
        if (response.ok) {
            const status = await response.json();
            updateSaveStatusUI(status);
        }
    } catch (error) {
        console.error('Error fetching save status:', error);
    }
}

/**
 * Update the save status UI based on server response
 */
function updateSaveStatusUI(status) {
    const indicator = document.getElementById('saveStatusIndicator');
    const statusText = document.getElementById('saveStatusText');
    const progressBar = document.getElementById('saveProgressBar');
    
    if (!indicator || !statusText || !progressBar) return;
    
    // Calculate progress percentage
    const interval = status.save_interval || 60;
    const remaining = status.seconds_remaining || 0;
    const progress = ((interval - remaining) / interval) * 100;
    
    // Update progress bar
    progressBar.style.width = `${progress}%`;
    
    // Format countdown time
    const minutes = Math.floor(remaining / 60);
    const seconds = Math.floor(remaining % 60);
    const countdownText = `${minutes}:${seconds.toString().padStart(2, '0')}`;
    
    // Remove force save button if a save is in progress
    const saveInProgress = status.save_in_progress || status.auto_save_in_progress || status.manual_save_requested;
    const forceSaveButton = document.getElementById('forceSaveButton');
    
    if (saveInProgress && forceSaveButton) {
        forceSaveButton.remove();
    }
    
    // Update status text based on save state
    if (status.save_in_progress) {
        indicator.classList.add('saving');
        statusText.textContent = 'Saving in progress...';
    } else if (status.auto_save_in_progress) {
        indicator.classList.add('saving');
        statusText.textContent = 'Auto-saving...';
    } else if (status.manual_save_requested) {
        indicator.classList.add('saving');
        statusText.textContent = 'Manual save in progress...';
    } else {
        indicator.classList.remove('saving');
        
        // Show timer counting down
        if (remaining < interval) {
            statusText.textContent = `Auto-save in: ${countdownText}`;
            
            // Add option to force a save if not available and timer > 10s
            if (!forceSaveButton && remaining > 10) {
                const newForceSaveButton = document.createElement('button');
                newForceSaveButton.id = 'forceSaveButton';
                newForceSaveButton.className = 'save-now-button';
                newForceSaveButton.textContent = 'Save Now';
                newForceSaveButton.addEventListener('click', requestManualSave);
                indicator.appendChild(newForceSaveButton);
            }
        } else {
            statusText.textContent = 'Auto-save pending...';
        }
    }
}

/**
 * Request a manual save operation
 */
async function requestManualSave() {
    try {
        // Show toast notification
        if (window.showToast) {
            window.showToast('Manual save requested...', 'info');
        }
        
        // Request a save from the server
        const response = await fetch('/request_save', {
            method: 'POST'
        });
        
        if (response.ok) {
            if (window.showToast) {
                window.showToast('Save requested successfully', 'success');
            }
            // Update save status immediately
            updateSaveStatus();
        } else {
            if (window.showToast) {
                window.showToast('Failed to request save', 'error');
            }
        }
    } catch (error) {
        console.error('Error requesting save:', error);
        if (window.showToast) {
            window.showToast('Error requesting save', 'error');
        }
    }
}
