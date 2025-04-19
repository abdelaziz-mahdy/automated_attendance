import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/widgets/progress_indicators/batch_progress_indicator.dart';

class FaceImportDialog extends StatefulWidget {
  const FaceImportDialog({super.key});

  @override
  State<FaceImportDialog> createState() => _FaceImportDialogState();
}

class _FaceImportDialogState extends State<FaceImportDialog> {
  String? _selectedDirectoryPath;
  Map<String, List<String>> _personDirectories = {};
  bool _isProcessing = false;
  bool _directoryAnalysisComplete = false;
  int _batchSize = 10;
  double _currentBatchProgress = 0;
  double _overallProgress = 0;
  String _statusText = 'Waiting for directory selection...';
  String _batchStatusText = '';

  // Import results
  int _personsImported = 0;
  int _imagesProcessed = 0;
  int _facesDetected = 0;
  List<String> _errors = [];
  List<String> _failedImages = [];

  final List<int> _availableBatchSizes = [5, 10, 20, 50];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.face, size: 28),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Import Faces from Directory',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isProcessing) {
      return _buildProgressView();
    } else if (_directoryAnalysisComplete && _personDirectories.isNotEmpty) {
      return _buildDirectoryAnalysisResults();
    } else {
      return _buildDirectorySelector();
    }
  }

  Widget _buildDirectorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Select a directory where each subdirectory contains photos of a person.\n'
            'Required structure: root_dir/person_name/image1.jpg, image2.jpg...',
            style: TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Directory'),
              onPressed: _selectDirectory,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedDirectoryPath != null
                      ? path.basename(_selectedDirectoryPath!)
                      : 'No directory selected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontStyle: _selectedDirectoryPath != null
                        ? FontStyle.normal
                        : FontStyle.italic,
                    color: _selectedDirectoryPath != null
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedDirectoryPath != null && !_directoryAnalysisComplete)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: _analyzeDirectory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Analyze Directory'),
            ),
          ),
      ],
    );
  }

  Widget _buildDirectoryAnalysisResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Directory Analysis Results:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Found '),
              TextSpan(
                text: '${_personDirectories.length} ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: 'person directories with '),
              TextSpan(
                text: '${_countTotalImages()} ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: 'total images'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              itemCount: _personDirectories.entries.length,
              itemBuilder: (context, index) {
                final entry = _personDirectories.entries.elementAt(index);
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(entry.key),
                  subtitle: Text('${entry.value.length} images'),
                  dense: true,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Batch size:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _batchSize,
              items: _availableBatchSizes.map((size) {
                final String description = size == 5
                    ? 'Low memory'
                    : size == 10
                        ? 'Recommended'
                        : size == 20
                            ? 'Fast'
                            : 'High memory';
                return DropdownMenuItem<int>(
                  value: size,
                  child: Text('$size images ($description)'),
                );
              }).toList(),
              onChanged: (int? newSize) {
                if (newSize != null) {
                  setState(() {
                    _batchSize = newSize;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDirectoryPath = null;
                  _directoryAnalysisComplete = false;
                  _personDirectories = {};
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Start Import'),
              onPressed: _startImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import Progress',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Text('Current batch:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        BatchProgressIndicator(
          progress: _currentBatchProgress,
          showPercentage: true,
        ),
        const SizedBox(height: 16),
        Text('Overall progress:',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        BatchProgressIndicator(
          progress: _overallProgress,
          showPercentage: true,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _statusText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _batchStatusText,
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        if (_imagesProcessed > 0 || _facesDetected > 0)
          const SizedBox(height: 24),
        if (_imagesProcessed > 0 || _facesDetected > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Results:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                          Icons.person, '$_personsImported', 'Persons'),
                      _buildStatItem(
                          Icons.image, '$_imagesProcessed', 'Images'),
                      _buildStatItem(Icons.face, '$_facesDetected', 'Faces'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_errors.isNotEmpty) const SizedBox(height: 16),
        if (_errors.isNotEmpty)
          Expanded(
            child: Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Errors (${_errors.length}):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _errors.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• ${_errors[index]}',
                              style: TextStyle(color: Colors.red[800]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Future<void> _selectDirectory() async {
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        setState(() {
          _selectedDirectoryPath = directoryPath;
          _directoryAnalysisComplete = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error selecting directory: $e');
    }
  }

  Future<void> _analyzeDirectory() async {
    if (_selectedDirectoryPath == null) return;

    setState(() {
      _statusText = 'Analyzing directory structure...';
      _personDirectories = {};
    });

    try {
      final directory = Directory(_selectedDirectoryPath!);
      final Map<String, List<String>> personDirs = {};

      // Get all subdirectories in the root directory (person directories)
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final personName = path.basename(entity.path);
          final List<String> imageFiles = [];

          // Find all image files in the person's directory
          await for (final file in entity.list(recursive: false)) {
            if (file is File) {
              final extension = path.extension(file.path).toLowerCase();
              if (extension == '.jpg' ||
                  extension == '.jpeg' ||
                  extension == '.png' ||
                  extension == '.bmp' ||
                  extension == '.webp') {
                imageFiles.add(file.path);
              }
            }
          }

          // Only add directories that contain images
          if (imageFiles.isNotEmpty) {
            personDirs[personName] = imageFiles;
          }
        }
      }

      setState(() {
        _personDirectories = personDirs;
        _directoryAnalysisComplete = true;
        _statusText = 'Directory analysis complete';
      });

      if (personDirs.isEmpty) {
        _showErrorSnackbar(
            'No valid person directories found. Each person should have their own folder with images.');
      }
    } catch (e) {
      _showErrorSnackbar('Error analyzing directory: $e');
    }
  }

  int _countTotalImages() {
    int total = 0;
    for (var images in _personDirectories.values) {
      total += images.length;
    }
    return total;
  }

  Future<void> _startImport() async {
    if (_personDirectories.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _currentBatchProgress = 0;
      _overallProgress = 0;
      _statusText = 'Preparing to import...';
      _batchStatusText = '';
      _personsImported = 0;
      _imagesProcessed = 0;
      _facesDetected = 0;
      _errors = [];
      _failedImages = [];
    });

    try {
      final controller = Provider.of<UIStateController>(context, listen: false);

      // Process each person
      final int totalPersons = _personDirectories.length;
      int processedPersons = 0;

      for (final entry in _personDirectories.entries) {
        final String personName = entry.key;
        final List<String> imagePaths = entry.value;

        setState(() {
          _statusText =
              'Importing person: $personName (${processedPersons + 1}/$totalPersons)';
        });

        // Process in batches
        final int totalBatches = (imagePaths.length / _batchSize).ceil();
        int processedBatches = 0;
        int personFacesDetected = 0;

        for (int i = 0; i < imagePaths.length; i += _batchSize) {
          final int end = (i + _batchSize < imagePaths.length)
              ? i + _batchSize
              : imagePaths.length;
          final List<String> batch = imagePaths.sublist(i, end);
          processedBatches++;

          setState(() {
            _batchStatusText =
                'Processing batch $processedBatches of $totalBatches for $personName';
          });

          // Process current batch
          final batchResult = await _processPersonBatch(
              personName, batch, processedBatches, totalBatches);

          // Update state with batch results
          setState(() {
            _imagesProcessed += batch.length;
            _currentBatchProgress = (processedBatches / totalBatches) * 100;

            if (batchResult['success']) {
              _facesDetected += batchResult['faces_detected'] as int;
              personFacesDetected += batchResult['faces_detected'] as int;
            }

            if (batchResult['errors'] != null) {
              _errors.addAll((batchResult['errors'] as List).cast<String>());
            }

            if (batchResult['failed_images'] != null) {
              _failedImages.addAll(
                  (batchResult['failed_images'] as List).cast<String>());
            }
          });
        }

        // Update person progress
        processedPersons++;
        if (personFacesDetected > 0) {
          _personsImported++;
        }

        setState(() {
          _overallProgress = (processedPersons / totalPersons) * 100;
        });
      }

      // Import complete
      setState(() {
        _statusText = 'Import completed!';
        _currentBatchProgress = 100;
        _overallProgress = 100;
        _batchStatusText = '';
      });

      // Update UI with refreshed face data
      await controller.refreshTrackedFaces();

      _showSuccessSnackbar('Successfully imported $_personsImported person(s)');
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
        _errors.add('Import failed: $e');
      });
      _showErrorSnackbar('Import failed: $e');
    }
  }

  Future<Map<String, dynamic>> _processPersonBatch(String personName,
      List<String> imagePaths, int batchNum, int totalBatches) async {
    final Map<String, dynamic> result = {
      'success': true,
      'person_name': personName,
      'images_processed': imagePaths.length,
      'faces_detected': 0,
      'failed_images': <String>[],
      'errors': <String>[],
    };

    try {
      final controller = Provider.of<UIStateController>(context, listen: false);

      // Process each image in the batch
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final file = File(imagePath);

        if (await file.exists()) {
          try {
            // Read the image file
            final imageBytes = await file.readAsBytes();

            // Process image and extract face
            final success = await controller.importFaceImage(
              imageBytes: imageBytes,
              personName: personName,
              filePath: imagePath,
            );

            if (success) {
              result['faces_detected'] = (result['faces_detected'] as int) + 1;
            } else {
              result['failed_images'].add(path.basename(imagePath));
            }

            // Update batch progress for UI
            setState(() {
              _currentBatchProgress = ((i + 1) / imagePaths.length) * 100;
            });
          } catch (e) {
            result['failed_images'].add(path.basename(imagePath));
            result['errors']
                .add('Error processing ${path.basename(imagePath)}: $e');
          }
        } else {
          result['failed_images'].add(path.basename(imagePath));
          result['errors'].add('File not found: ${path.basename(imagePath)}');
        }
      }

      if (result['faces_detected'] == 0) {
        result['success'] = false;
        result['errors'].add(
            'No faces were detected in any of the ${imagePaths.length} images for $personName');
      }
    } catch (e) {
      result['success'] = false;
      result['errors'].add(
          'Failed to process batch $batchNum/$totalBatches for $personName: $e');
      result['failed_images'].addAll(imagePaths.map((p) => path.basename(p)));
    }

    return result;
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
