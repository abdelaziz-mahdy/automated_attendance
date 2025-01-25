// camera_manager.dart
import 'dart:async';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/services/face_processing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart';
// lib/models/tracked_face.dart

class TrackedFace {
  final String id;
  final List<double> features;
  final String name;
  DateTime? firstSeen;
  DateTime? lastSeen;
  String? lastSeenProvider;
  Uint8List? thumbnail; // Now directly in the class

  TrackedFace({
    required this.id,
    required this.features,
    required this.name,
    this.firstSeen,
    this.lastSeen,
    this.lastSeenProvider,
    this.thumbnail,
  });
}

class CameraManager extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final FaceComparisonService _faceComparisonService = FaceComparisonService();

  final Map<String, ICameraProvider> activeProviders = {};
  final Map<String, Uint8List> _lastFrames = {};

  // Keep a timer for each provider
  final Map<String, Timer> _pollTimers = {};

  // Stream controller for face embeddings
  final StreamController<List<double>> _faceFeaturesStreamController =
      StreamController.broadcast();

  Stream<List<double>> get faceFeaturesStream =>
      _faceFeaturesStreamController.stream;

  /// NEW: A list to store all cropped face thumbnails.
  final List<Uint8List> capturedFaces = [];

  /// Map to store features of tracked faces and their information.
  final Map<String, TrackedFace> trackedFaces = {};

  bool _isListening = false;

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    await _discoveryService.startDiscovery(serviceType: '_camera._tcp');
    _discoveryService.discoveryStream.listen(_onServiceDiscovered);
    _discoveryService.removeStream.listen(_onServiceRemoved);
  }

  Future<void> stopListening() async {
    _isListening = false;

    await _discoveryService.stopDiscovery();

    // Cancel all provider timers
    for (var timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();

    // Close all active providers
    for (var provider in activeProviders.values) {
      await provider.closeCamera();
    }
    activeProviders.clear();
    _lastFrames.clear();
  }

  Future<void> _onServiceDiscovered(ServiceInfo serviceInfo) async {
    final address = serviceInfo.address;
    final port = serviceInfo.port;

    if (address == null || port == null) return;
    if (activeProviders.containsKey(address)) return;

    final provider = RemoteCameraProvider(
      serverAddress: address,
      serverPort: port,
    );

    final opened = await provider.openCamera();
    if (!opened) return;

    activeProviders[address] = provider;

    // Start a periodic timer for polling frames
    const int fps = 10;
    final pollInterval = Duration(milliseconds: (1000 / fps).round());
    // print("Starting polling for $address at $fps FPS");
    _pollTimers[address] = Timer.periodic(pollInterval, (timer) {
      // If the provider is removed or manager is not listening, cancel the timer.
      if (!_isListening || !activeProviders.containsKey(address)) {
        timer.cancel();
        _pollTimers.remove(address);
        return;
      }
      _pollFramesOnce(provider, address);
    });

    notifyListeners();
  }

  Future<void> _onServiceRemoved(ServiceInfo serviceInfo) async {
    final address = serviceInfo.address;
    if (address == null) return;

    // Cancel the timer for this provider
    _pollTimers[address]?.cancel();
    _pollTimers.remove(address);

    final provider = activeProviders.remove(address);
    if (provider != null) {
      await provider.closeCamera();
    }

    _lastFrames.remove(address);
    notifyListeners();
  }

  /// Fetch and process exactly one frame from the given provider
  Future<void> _pollFramesOnce(ICameraProvider provider, String address) async {
    try {
      final frame = await provider.getFrame();
      if (frame != null) {
        // 1) Process frame for face detection + bounding boxes
        final processedFrame = await FaceProcessingService.processFrame(frame);

        if (processedFrame != null) {
          // Keep the annotated frame for UI display
          _lastFrames[address] = processedFrame.processedFrame;

          // 2) Extract face embeddings if needed
          final features = await _extractFaceFeatures(
            processedFrame.processedFrameMat,
            processedFrame.faces,
          );
          if (features.isNotEmpty) {
            for (int i = 0; i < features.length; i++) {
              _faceFeaturesStreamController.add(features[i]);

              // NEW: Compare extracted features with tracked faces
              _compareWithTrackedFaces(
                features[i],
                address,
                await _cropSingleFace(
                  processedFrame.processedFrameMat,
                  processedFrame.faces,
                  i,
                ),
              );
            }
          }

          // 3) Crop out each detected face as a thumbnail
          _cropAndStoreAllFaces(
            processedFrame.processedFrameMat,
            processedFrame.faces,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error polling frames for $address: $e");
    }
  }

  /// Compares extracted face features with tracked faces.
  void _compareWithTrackedFaces(
      List<double> features, String providerAddress, Uint8List? faceThumbnail) {
    bool isKnownFace = false;

    for (final entry in trackedFaces.entries) {
      final trackedId = entry.key;
      final trackedFace = entry.value; // Now a TrackedFace object
      final trackedFeatures = trackedFace.features;

      final isSimilar = _faceComparisonService.areFeaturesSimilar(
        features,
        trackedFeatures,
      );

      if (isSimilar) {
        trackedFace.firstSeen ??= DateTime.now();
        trackedFace.lastSeen = DateTime.now();
        trackedFace.lastSeenProvider = providerAddress;
        isKnownFace = true;
        notifyListeners();
        break;
      }
    }

    if (!isKnownFace) {
      final newFaceId = "face_${trackedFaces.length + 1}";
      final newTrackedFace = TrackedFace(
        id: newFaceId,
        features: features,
        name: newFaceId, // Default name is the ID
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        lastSeenProvider: providerAddress,
        thumbnail: faceThumbnail, // Store thumbnail directly
      );

      trackedFaces[newFaceId] = newTrackedFace;
      notifyListeners();
    }
  }

  Future<List<List<double>>> _extractFaceFeatures(
      Mat frameBytes, Mat faces) async {
    return await FaceFeaturesExtractionService()
        .extractFaceFeatures(frameBytes, faces);
  }

  /// Takes an image (Mat) and a list of detected faces (Mat), then crops
  /// a single face and encodes it as a JPEG.
  /// Returns the JPEG bytes (Uint8List) of the cropped face or null if cropping fails.
  Future<Uint8List?> _cropSingleFace(
      Mat image, Mat faces, int faceIndex) async {
    if (faceIndex < 0 || faceIndex >= faces.rows) {
      return null; // Invalid face index
    }

    final x = faces.at<double>(faceIndex, 0).toInt();
    final y = faces.at<double>(faceIndex, 1).toInt();
    final w = faces.at<double>(faceIndex, 2).toInt();
    final h = faces.at<double>(faceIndex, 3).toInt();

    // Make sure bounding box is within image boundaries
    final safeW = (x + w) > image.width ? image.width - x : w;
    final safeH = (y + h) > image.height ? image.height - y : h;

    if (safeW <= 0 || safeH <= 0) {
      return null; // Invalid dimensions
    }

    final faceRect = Rect(x, y, safeW, safeH);
    final faceMat = await image.regionAsync(faceRect);

    // Encode the cropped face to JPEG
    final (encSuccess, faceBytes) = await imencodeAsync(".jpg", faceMat);
    faceMat.dispose();

    if (encSuccess) {
      return faceBytes;
    } else {
      return null;
    }
  }

  /// Takes the processed frame and the faces Mat, then crops each face
  /// and encodes it as a JPEG. Stores in [capturedFaces].
  Future<void> _cropAndStoreAllFaces(Mat annotatedFrame, Mat faces) async {
    for (int i = 0; i < faces.rows; i++) {
      final faceBytes = await _cropSingleFace(annotatedFrame, faces, i);

      if (faceBytes != null) {
        capturedFaces.insert(0, faceBytes);
        if (capturedFaces.length > 10) {
          capturedFaces.removeLast();
        }
      }
    }
    notifyListeners(); // Notify after processing all faces
  }

  Uint8List? getLastFrame(String address) => _lastFrames[address];

  @override
  void dispose() {
    _faceFeaturesStreamController.close();
    stopListening();
    super.dispose();
  }
}
