// camera_manager.dart

import 'dart:async';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/services/face_processing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart';

class CameraManager extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();

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
            for (var feature in features) {
              _faceFeaturesStreamController.add(feature);
            }
          }

          // 3) Crop out each detected face as a thumbnail
          _cropFacesAndStore(
              processedFrame.processedFrameMat, processedFrame.faces);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error polling frames for $address: $e");
    }
  }

  Future<List<List<double>>> _extractFaceFeatures(
      Mat frameBytes, Mat faces) async {
    return await FaceFeaturesExtractionService()
        .extractFaceFeatures(frameBytes, faces);
  }

  /// NEW: Takes the processed frame and the faces Mat, then crops each face
  /// and encodes it as a JPEG. Stores in [capturedFaces].
  Future<void> _cropFacesAndStore(Mat annotatedFrame, Mat faces) async {
    for (int i = 0; i < faces.rows; i++) {
      final x = faces.at<double>(i, 0).toInt();
      final y = faces.at<double>(i, 1).toInt();
      final w = faces.at<double>(i, 2).toInt();
      final h = faces.at<double>(i, 3).toInt();

      // Make sure bounding box is within image boundaries
      final safeW =
          (x + w) > annotatedFrame.width ? annotatedFrame.width - x : w;
      final safeH =
          (y + h) > annotatedFrame.height ? annotatedFrame.height - y : h;

      if (safeW <= 0 || safeH <= 0) {
        continue;
      }

      final faceRect = Rect(x, y, safeW, safeH);
      final faceMat = await annotatedFrame.regionAsync(faceRect);

      // Encode the cropped face to JPEG
      final (encSuccess, faceBytes) = imencode(".jpg", faceMat);
      faceMat.dispose();

      if (encSuccess) {
        capturedFaces.insert(0, faceBytes);
      }
    }
    notifyListeners();
  }

  Uint8List? getLastFrame(String address) => _lastFrames[address];

  @override
  void dispose() {
    _faceFeaturesStreamController.close();
    stopListening();
    super.dispose();
  }
}
