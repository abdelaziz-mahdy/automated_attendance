/**
 * Import Faces Module
 * Handles directory selection, batch uploading of images, and progress tracking
 */
document.addEventListener('DOMContentLoaded', () => {
    console.log("Import faces module loaded");
    
    // DOM elements - simplify button selection
    let importFacesBtn = document.getElementById('importFacesBtn');
    
    // If the button doesn't exist by ID, try to find it by another means
    if (!importFacesBtn) {
        // Try to find inside face-stats-actions
        const facesTabActions = document.querySelector('.face-stats-actions');
        if (facesTabActions) {
            // Create a new import button if it doesn't exist
            console.log("Creating import button");
            const newImportBtn = document.createElement('button');
            newImportBtn.id = 'importFacesBtn';
            newImportBtn.className = 'action-button';
            newImportBtn.innerHTML = '<i class="fas fa-file-import"></i> Import Faces';
            facesTabActions.insertBefore(newImportBtn, facesTabActions.firstChild);
            importFacesBtn = newImportBtn;
        } else {
            console.error("Could not find .face-stats-actions element");
        }
    } else {
        console.log("Found existing import button");
    }
    
    // Make sure the button has the right content
    if (importFacesBtn && !importFacesBtn.innerHTML.includes('Import Faces')) {
        importFacesBtn.innerHTML = '<i class="fas fa-file-import"></i> Import Faces';
    }
    
    const importFacesModal = document.getElementById('importFacesModal');
    const closeImportModal = document.getElementById('closeImportModal');
    const browseDirectoryBtn = document.getElementById('browseDirectoryBtn');
    const directoryInput = document.getElementById('directoryInput');
    const selectedDirectoryName = document.getElementById('selectedDirectoryName');
    const startImportBtn = document.getElementById('startImportBtn');
    const batchSizeInput = document.getElementById('batchSizeInput');
    
    // Log if any essential elements are missing
    if (!importFacesModal) console.error("importFacesModal is missing");
    if (!closeImportModal) console.error("closeImportModal is missing");
    if (!browseDirectoryBtn) console.error("browseDirectoryBtn is missing");
    if (!directoryInput) console.error("directoryInput is missing");
    if (!selectedDirectoryName) console.error("selectedDirectoryName is missing");
    if (!startImportBtn) console.error("startImportBtn is missing");
    if (!batchSizeInput) console.error("batchSizeInput is missing");
    
    // Progress elements
    const importProgress = document.getElementById('importProgress');
    const currentBatchProgress = document.getElementById('currentBatchProgress');
    const currentBatchProgressText = document.getElementById('currentBatchProgressText');
    const overallProgress = document.getElementById('overallProgress');
    const overallProgressText = document.getElementById('overallProgressText');
    const importStatusText = document.getElementById('importStatusText');
    const batchStatusText = document.getElementById('batchStatusText');
    
    // Results elements
    const importResults = document.getElementById('importResults');
    const importedPersonsCount = document.getElementById('importedPersonsCount');
    const processedImagesCount = document.getElementById('processedImagesCount');
    const detectedFacesCount = document.getElementById('detectedFacesCount');
    const importedPersonsList = document.getElementById('importedPersonsList');
    const importErrorsContainer = document.getElementById('importErrorsContainer');
    const importErrorsList = document.getElementById('importErrorsList');

    // State variables
    let importInProgress = false;
    let selectedFiles = [];
    let personDirectories = new Map(); // Maps person name to array of files
    let currentResults = {
        persons_imported: [],
        total_images: 0,
        total_faces_detected: 0,
        failed_images: [],
        errors: []
    };

    // Add click event for Import Faces button
    if (importFacesBtn) {
        console.log("Adding click event to import button");
        importFacesBtn.addEventListener('click', () => {
            console.log("Import faces button clicked");
            resetImportUI();
            if (importFacesModal) {
                importFacesModal.classList.add('active');
                console.log("Modal activated");
            } else {
                console.error("Cannot show modal - element not found");
            }
        });
    } else {
        console.error("Import faces button not found");
    }

    // Close the modal when the close button is clicked
    if (closeImportModal) {
        closeImportModal.addEventListener('click', () => {
            if (importInProgress) {
                showToast('Import in progress, please wait...', 'info');
                return;
            }
            importFacesModal.classList.remove('active');
            console.log("Modal closed");
        });
    }

    // Close the modal when clicking outside the modal content
    if (importFacesModal) {
        importFacesModal.addEventListener('click', (e) => {
            if (e.target === importFacesModal && !importInProgress) {
                importFacesModal.classList.remove('active');
                console.log("Modal closed (clicked outside)");
            }
        });
    }

    // Also handle escape key to close modal
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !importInProgress && importFacesModal && importFacesModal.classList.contains('active')) {
            importFacesModal.classList.remove('active');
            console.log("Modal closed (ESC key)");
        }
    });

    // Handle directory selection
    if (browseDirectoryBtn && directoryInput) {
        browseDirectoryBtn.addEventListener('click', () => {
            console.log("Browse directory button clicked");
            directoryInput.click();
        });
    }

    // Process selected directory
    if (directoryInput) {
        directoryInput.addEventListener('change', (event) => {
            console.log("Directory input changed", event);
            handleDirectorySelection(event);
        });
    }

    // Handle import button click
    if (startImportBtn) {
        startImportBtn.addEventListener('click', () => {
            console.log("Start import button clicked", personDirectories);
            if (personDirectories.size === 0) {
                showToast('Please select a directory with person folders', 'error');
                return;
            }
            startImport();
        });
    }

    /**
     * Reset the import UI to its initial state
     */
    function resetImportUI() {
        // Reset file selection
        if (directoryInput) directoryInput.value = '';
        selectedFiles = [];
        personDirectories.clear();
        if (selectedDirectoryName) selectedDirectoryName.textContent = 'No directory selected';
        if (selectedDirectoryName) selectedDirectoryName.title = '';
        if (startImportBtn) startImportBtn.disabled = true;
        
        // Reset progress display
        if (importProgress) importProgress.style.display = 'none';
        if (importResults) importResults.style.display = 'none';
        if (importErrorsContainer) importErrorsContainer.style.display = 'none';
        
        if (currentBatchProgress) currentBatchProgress.style.width = '0%';
        if (currentBatchProgressText) currentBatchProgressText.textContent = '0%';
        if (overallProgress) overallProgress.style.width = '0%';
        if (overallProgressText) overallProgressText.textContent = '0%';
        
        if (importStatusText) importStatusText.textContent = 'Preparing to import...';
        if (batchStatusText) batchStatusText.textContent = 'Processing batch 0 of 0';
        
        // Reset result values
        currentResults = {
            persons_imported: [],
            total_images: 0,
            total_faces_detected: 0,
            failed_images: [],
            errors: []
        };
    }

    /**
     * Handle directory selection from the file input
     */
    function handleDirectorySelection(event) {
        selectedFiles = Array.from(event.target.files || []);
        console.log("Selected files:", selectedFiles.length);
        
        if (selectedFiles.length === 0) {
            selectedDirectoryName.textContent = 'No directory selected';
            selectedDirectoryName.title = '';
            startImportBtn.disabled = true;
            return;
        }
        
        // Process the directory structure
        processDirectoryStructure(selectedFiles).then(result => {
            personDirectories = result.personDirs;
            
            // Get the root directory name
            const rootDir = result.rootDir || 'Selected directory';
            
            // Update UI
            selectedDirectoryName.textContent = `${rootDir} (${personDirectories.size} persons, ${selectedFiles.length} images)`;
            selectedDirectoryName.title = `${personDirectories.size} person directories with ${selectedFiles.length} total images`;
            
            console.log("Processed directories:", personDirectories);
            
            // Enable/disable the import button based on results
            if (personDirectories.size > 0) {
                startImportBtn.disabled = false;
            } else {
                startImportBtn.disabled = true;
                
                if (selectedFiles.length > 0) {
                    showToast('No valid person directories found. Each person should have their own folder.', 'warning');
                }
            }
        });
    }

    /**
     * Process the directory structure to identify person folders
     * @param {File[]} files - Array of selected files
     * @returns {Promise<{personDirs: Map<string, File[]>, rootDir: string}>}
     */
    async function processDirectoryStructure(files) {
        // Map to store person directories and their image files
        const personDirs = new Map();
        let rootDir = '';
        
        // Get the common parent directory (root)
        if (files.length > 0 && files[0].webkitRelativePath) {
            const path = files[0].webkitRelativePath;
            rootDir = path.split('/')[0];
        }
        
        console.log("Processing directory structure. Root dir:", rootDir);
        
        // Group files by person directory (second level directory)
        for (const file of files) {
            // Skip non-image files
            if (!file.type.startsWith('image/')) {
                console.log("Skipping non-image file:", file.name, file.type);
                continue;
            }
            
            const pathParts = file.webkitRelativePath.split('/');
            console.log("Path parts for file:", file.name, pathParts);
            
            // We expect at least: rootDir/personName/image.jpg
            if (pathParts.length >= 3) {
                const personName = pathParts[1];
                
                if (!personDirs.has(personName)) {
                    personDirs.set(personName, []);
                }
                
                personDirs.get(personName).push(file);
            }
        }
        
        // Log the results
        console.log("Found person directories:", personDirs.size);
        personDirs.forEach((files, personName) => {
            console.log(`  - ${personName}: ${files.length} images`);
        });
        
        return { personDirs, rootDir };
    }

    /**
     * Start the import process
     */
    async function startImport() {
        // Mark import as in progress
        importInProgress = true;
        
        // Disable UI elements
        startImportBtn.disabled = true;
        browseDirectoryBtn.disabled = true;
        
        // Show progress UI
        importProgress.style.display = 'block';
        importResults.style.display = 'none';
        
        // Reset progress indicators
        currentBatchProgress.style.width = '0%';
        currentBatchProgressText.textContent = '0%';
        overallProgress.style.width = '0%';
        overallProgressText.textContent = '0%';
        
        // Reset results
        currentResults = {
            persons_imported: [],
            total_images: 0,
            total_faces_detected: 0,
            failed_images: [],
            errors: []
        };
        
        try {
            // Get batch size from input
            const batchSize = parseInt(batchSizeInput.value) || 10;
            console.log("Starting import with batch size:", batchSize);
            
            // Calculate total batches and prepare for import
            const personsArray = Array.from(personDirectories.entries());
            let processedPersons = 0;
            let totalPersons = personsArray.length;
            
            importStatusText.textContent = `Importing ${totalPersons} persons...`;
            
            // Process each person
            for (const [personName, files] of personsArray) {
                // Update status for current person
                importStatusText.textContent = `Importing person: ${personName} (${processedPersons + 1}/${totalPersons})`;
                console.log(`Processing person ${processedPersons + 1}/${totalPersons}: ${personName} with ${files.length} files`);
                
                // Process files in batches
                const totalBatches = Math.ceil(files.length / batchSize);
                let processedBatches = 0;
                
                for (let i = 0; i < files.length; i += batchSize) {
                    const batch = files.slice(i, i + batchSize);
                    processedBatches++;
                    
                    // Update batch status
                    batchStatusText.textContent = `Processing batch ${processedBatches} of ${totalBatches} for ${personName}`;
                    console.log(`Processing batch ${processedBatches}/${totalBatches} with ${batch.length} files`);
                    
                    try {
                        // Process current batch
                        const batchResult = await processPersonBatch(personName, batch, processedBatches, totalBatches);
                        console.log("Batch result:", batchResult);
                        
                        // Update batch progress
                        const batchProgress = Math.min(100, Math.round((processedBatches / totalBatches) * 100));
                        currentBatchProgress.style.width = `${batchProgress}%`;
                        currentBatchProgressText.textContent = `${batchProgress}%`;
                        
                        // Merge batch results
                        mergeResults(batchResult);
                    } catch (error) {
                        console.error("Error processing batch:", error);
                        currentResults.errors.push(`Error processing batch for ${personName}: ${error.message}`);
                    }
                }
                
                // Update person progress
                processedPersons++;
                const personProgress = Math.min(100, Math.round((processedPersons / totalPersons) * 100));
                overallProgress.style.width = `${personProgress}%`;
                overallProgressText.textContent = `${personProgress}%`;
            }
            
            // Import complete
            importStatusText.textContent = 'Import completed!';
            currentBatchProgress.style.width = '100%';
            currentBatchProgressText.textContent = '100%';
            overallProgress.style.width = '100%';
            overallProgressText.textContent = '100%';
            
            // Display results
            displayImportResults(currentResults);
            
            // Mark import as completed
            importInProgress = false;
            
            // Re-enable UI elements
            browseDirectoryBtn.disabled = false;
            
            // Refresh the face counts list
            setTimeout(() => {
                if (typeof window.updateFaceCounts === 'function') {
                    window.updateFaceCounts();
                }
            }, 1000);
            
        } catch (error) {
            console.error('Import error:', error);
            importStatusText.textContent = `Error: ${error.message}`;
            
            // Add to errors
            currentResults.errors.push(`Import failed: ${error.message}`);
            
            // Display partial results if any
            displayImportResults(currentResults);
            
            // Mark import as completed with error
            importInProgress = false;
            browseDirectoryBtn.disabled = false;
            
            // Show error toast
            showToast(`Import failed: ${error.message}`, 'error');
        }
    }

    /**
     * Process a batch of images for a single person
     * @param {string} personName - The name of the person
     * @param {File[]} files - Array of image files
     * @param {number} batchNum - Current batch number
     * @param {number} totalBatches - Total number of batches
     * @returns {Promise<Object>} - Import results for this batch
     */
    async function processPersonBatch(personName, files, batchNum, totalBatches) {
        // Create a FormData object to send the files
        const formData = new FormData();
        
        // Add person name
        formData.append('person_name', personName);
        
        // Log the process
        console.log(`Preparing batch ${batchNum}/${totalBatches} for ${personName} with ${files.length} files`);
        
        // Add each file
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            console.log(`Adding file ${i+1}/${files.length}: ${file.name} (${file.size} bytes)`);
            
            // Check if the file is an image
            if (!file.type.startsWith('image/')) {
                console.warn(`Skipping non-image file: ${file.name} (${file.type})`);
                continue;
            }
            
            formData.append('images', file, file.name);
            
            // Update batch progress during upload preparation
            const fileProgress = Math.min(100, Math.round((i + 1) / files.length * 100));
            currentBatchProgress.style.width = `${fileProgress}%`;
            currentBatchProgressText.textContent = `${fileProgress}%`;
            
            // Small delay to show progress visually
            await new Promise(resolve => setTimeout(resolve, 10));
        }
        
        try {
            // Log before sending
            console.log(`Sending batch to server: ${batchNum}/${totalBatches} for ${personName}`);
            
            // Send the batch to the server
            const response = await fetch('/import_faces_batch', {
                method: 'POST',
                body: formData
            });
            
            console.log(`Server response status: ${response.status}`);
            
            if (!response.ok) {
                const errorText = await response.text();
                console.error(`Server error: ${errorText}`);
                throw new Error(`Server error: ${errorText || response.statusText}`);
            }
            
            // Parse response
            const result = await response.json();
            console.log("Server response data:", result);
            return result;
            
        } catch (error) {
            console.error('Batch processing error:', error);
            
            // Return error result
            return {
                success: false,
                person_name: personName,
                images_processed: 0,
                faces_detected: 0,
                errors: [`Failed to process batch ${batchNum}/${totalBatches} for ${personName}: ${error.message}`],
                failed_images: files.map(f => f.name)
            };
        }
    }

    /**
     * Merge batch results into the overall results
     * @param {Object} batchResult - Results from a single batch
     */
    function mergeResults(batchResult) {
        // Update total counts
        currentResults.total_images += batchResult.images_processed || 0;
        currentResults.total_faces_detected += batchResult.faces_detected || 0;
        
        // Add errors and failed images
        if (batchResult.errors && batchResult.errors.length) {
            currentResults.errors.push(...batchResult.errors);
        }
        
        if (batchResult.failed_images && batchResult.failed_images.length) {
            currentResults.failed_images.push(...batchResult.failed_images);
        }
        
        // Add imported person if successful
        if (batchResult.success && batchResult.person_name) {
            // Check if person already exists in results
            const existingPerson = currentResults.persons_imported.find(p => p.name === batchResult.person_name);
            
            if (existingPerson) {
                // Update existing person
                existingPerson.images_processed += batchResult.images_processed || 0;
                existingPerson.faces_detected += batchResult.faces_detected || 0;
            } else {
                // Add new person
                currentResults.persons_imported.push({
                    name: batchResult.person_name,
                    id: batchResult.face_id || batchResult.person_name,
                    images_processed: batchResult.images_processed || 0,
                    faces_detected: batchResult.faces_detected || 0
                });
            }
        } else if (batchResult.person_name && !currentResults.persons_imported.some(p => p.name === batchResult.person_name)) {
             // If the batch failed but we haven't recorded this person yet, record the attempt
             // This helps show persons that had issues during import
             if (!currentResults.persons_imported.find(p => p.name === batchResult.person_name)) {
                 currentResults.persons_imported.push({
                     name: batchResult.person_name,
                     id: batchResult.person_name, // Use name as ID placeholder
                     images_processed: batchResult.images_processed || 0,
                     faces_detected: 0, // No faces successfully detected for this person yet
                     failed: true // Mark as failed
                 });
             }
        }
    }

    /**
     * Display import results in the UI
     * @param {Object} data - Import results data
     */
    function displayImportResults(data) {
        // Show the results section
        importResults.style.display = 'block';
        
        // Update the summary stats
        importedPersonsCount.textContent = data.persons_imported ? data.persons_imported.filter(p => !p.failed).length : 0; // Count only successful
        processedImagesCount.textContent = data.total_images || 0;
        detectedFacesCount.textContent = data.total_faces_detected || 0;
        
        // Clear and update the imported persons list
        importedPersonsList.innerHTML = '';
        
        if (data.persons_imported && data.persons_imported.length > 0) {
            data.persons_imported.forEach(person => {
                const personItem = document.createElement('div');
                personItem.className = 'imported-person-item';
                if (person.failed || person.faces_detected === 0) {
                    personItem.style.opacity = '0.6'; // Dim failed/empty imports
                }

                // Add thumbnail container
                const thumbnailContainer = document.createElement('div');
                thumbnailContainer.className = 'person-thumbnail';
                thumbnailContainer.innerHTML = '<i class="fas fa-spinner fa-pulse"></i>'; // Loading indicator

                // Create person details container
                const detailsContainer = document.createElement('div');
                detailsContainer.className = 'person-details';

                let statusIcon = person.faces_detected > 0 ? '<i class="fas fa-check-circle" style="color: var(--success-color);"></i>' : '<i class="fas fa-exclamation-triangle" style="color: var(--warning-color);"></i>';
                if (person.failed) {
                     statusIcon = '<i class="fas fa-times-circle" style="color: var(--danger-color);"></i>';
                }

                detailsContainer.innerHTML = `
                    <div class="person-name"><strong>${person.name}</strong> ${statusIcon}</div>
                    <div class="person-stats">
                        <span title="Images processed"><i class="fas fa-image"></i> ${person.images_processed}</span>
                        <span title="Faces detected"><i class="fas fa-user"></i> ${person.faces_detected}</span>
                    </div>
                `;

                // Add both containers to person item
                personItem.appendChild(thumbnailContainer);
                personItem.appendChild(detailsContainer);

                importedPersonsList.appendChild(personItem);

                // Try to get a thumbnail using the person's ID (which should be their name)
                // Use the placeholder generation if no live thumbnail exists yet
                fetchPersonThumbnail(person.id) // Use person.id here
                    .then(thumbnailUrl => {
                        if (thumbnailUrl) {
                            thumbnailContainer.innerHTML = ''; // Clear loading spinner
                            const img = document.createElement('img');
                            img.src = thumbnailUrl;
                            img.alt = person.name;
                            img.className = 'person-thumbnail-img';
                            thumbnailContainer.appendChild(img);
                        } else {
                            thumbnailContainer.innerHTML = '<i class="fas fa-user"></i>'; // Fallback icon
                        }
                    })
                    .catch(() => {
                        thumbnailContainer.innerHTML = '<i class="fas fa-user"></i>'; // Error fallback
                    });
            });
        } else {
            importedPersonsList.innerHTML = '<div class="import-placeholder">No persons were processed or found</div>';
        }

        // Display errors if any
        if ((data.errors && data.errors.length > 0) || (data.failed_images && data.failed_images.length > 0)) {
            importErrorsContainer.style.display = 'block';
            importErrorsList.innerHTML = '';
            
            // Add general errors
            if (data.errors && data.errors.length > 0) {
                data.errors.forEach(error => {
                    const errorItem = document.createElement('div');
                    errorItem.className = 'error-item';
                    errorItem.textContent = error;
                    importErrorsList.appendChild(errorItem);
                });
            }
            
            // Add failed images (limit to 20 to avoid UI overload)
            if (data.failed_images && data.failed_images.length > 0) {
                const failedImagesHeader = document.createElement('div');
                failedImagesHeader.className = 'error-header';
                failedImagesHeader.textContent = `Failed images (${data.failed_images.length} total):`;
                importErrorsList.appendChild(failedImagesHeader);
                
                // Limit displayed failures to keep UI clean
                const displayLimit = 20;
                const displayedImages = data.failed_images.slice(0, displayLimit);
                
                displayedImages.forEach(image => {
                    const errorItem = document.createElement('div');
                    errorItem.className = 'error-item';
                    errorItem.textContent = image;
                    importErrorsList.appendChild(errorItem);
                });
                
                // Show message if there are more failed images
                if (data.failed_images.length > displayLimit) {
                    const moreItem = document.createElement('div');
                    moreItem.className = 'error-item more-item';
                    moreItem.textContent = `... and ${data.failed_images.length - displayLimit} more`;
                    importErrorsList.appendChild(moreItem);
                }
            }
        } else {
            importErrorsContainer.style.display = 'none';
        }

        // Show success/warning notification
        const successfulImports = data.persons_imported ? data.persons_imported.filter(p => !p.failed && p.faces_detected > 0).length : 0;
        if (successfulImports > 0 && data.errors.length === 0 && data.failed_images.length === 0) {
            showToast(`Successfully imported ${successfulImports} person(s)`, 'success');
        } else if (successfulImports > 0) {
             showToast(`Import completed with some issues for ${successfulImports} person(s). Check details.`, 'warning');
        } else {
            showToast('Import completed, but no faces were successfully detected or issues occurred.', 'error');
        }
    }

    /**
     * Fetch a thumbnail for a person or generate a placeholder.
     * Checks window.faceThumbnails first.
     * @param {string} personId - The ID of the person (usually the name)
     * @returns {Promise<string|null>} - Promise resolving to thumbnail URL or null
     */
    async function fetchPersonThumbnail(personId) {
        try {
            // 1. Check live thumbnails from the main script
            if (window.faceThumbnails && window.faceThumbnails[personId] && window.faceThumbnails[personId].length > 0) {
                console.log(`Using live thumbnail for ${personId}`);
                return window.faceThumbnails[personId][window.faceThumbnails[personId].length - 1]; // Use the latest thumbnail
            }

            // 2. Generate placeholder if no live thumbnail exists
            console.log(`Generating placeholder thumbnail for ${personId}`);
            const hash = personId.split('').reduce((acc, char) => char.charCodeAt(0) + acc, 0);
            const hue = hash % 360;

            const canvas = document.createElement('canvas');
            canvas.width = 100;
            canvas.height = 100;
            const ctx = canvas.getContext('2d');

            ctx.fillStyle = `hsl(${hue}, 60%, 70%)`; // Slightly adjusted color
            ctx.fillRect(0, 0, 100, 100);

            const initials = personId.substring(0, 2).toUpperCase();
            ctx.fillStyle = 'white';
            ctx.font = 'bold 40px Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(initials, 50, 55); // Adjust vertical position slightly

            return canvas.toDataURL('image/png');
        } catch (error) {
            console.error(`Error fetching/generating thumbnail for ${personId}:`, error);
            return null; // Return null on error
        }
    }

    /**
     * Helper function to show toast messages
     * @param {string} message - Message to display
     * @param {string} type - Toast type: 'info', 'success', 'error', 'warning'
     */
    function showToast(message, type = 'info') {
        // Check if the global showToast function exists from script.js
        if (typeof window.showToast === 'function') {
            window.showToast(message, type);
        } else {
            // Fallback toast implementation if global function doesn't exist
            const toastContainer = document.getElementById('toastContainer');
            if (!toastContainer) return;
            
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
                    if (toast.parentNode) {
                        toastContainer.removeChild(toast);
                    }
                }, 300);
            }, 3000);
        }
    }
});
