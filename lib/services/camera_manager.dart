import 'dart:async';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/isolate/frame_processor.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// lib/isolate/frame_processor_isolate.dart
// For compute()
// lib/isolate/frame_processor_manager.dart

/// This is the long-running isolate’s entry point.
/// It first sends back its SendPort so that the main isolate can communicate with it,
/// then listens for incoming messages.

class CameraManager extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final FaceComparisonService _faceComparisonService = FaceComparisonService();
  final Map<String, ICameraProvider> activeProviders = {};
  final Map<String, Uint8List> _lastFrames = {};
  final Map<String, Timer> _pollTimers = {};
  final Map<String, int> _providerFps = {};
  final StreamController<List<double>> _faceFeaturesStreamController =
      StreamController.broadcast();
  final List<Uint8List> capturedFaces = [];
  final Map<String, TrackedFace> trackedFaces = {};

  bool _isListening = false;
  late SharedPreferences _prefs;
  late int _fps;
  late int _maxFaces;
  bool _useIsolates = true;
  bool get useIsolates => _useIsolates;

  Stream<List<double>> get faceFeaturesStream =>
      _faceFeaturesStreamController.stream;

  CameraManager() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _fps = _prefs.getInt('fps') ?? 10; // Default FPS
    _maxFaces = _prefs.getInt('maxFaces') ?? 10; // Default max faces
    notifyListeners();
  }

  // Update settings and restart frame polling
  Future<void> updateSettings(int fps, int maxFaces) async {
    await _prefs.setInt('fps', fps);
    await _prefs.setInt('maxFaces', maxFaces);
    _fps = fps;
    _maxFaces = maxFaces;
    // Reset dynamic FPS for each provider.
    for (var address in activeProviders.keys) {
      _providerFps[address] = _fps;
    }
    _restartFramePolling();
    notifyListeners();
  }

// Update the flag (e.g., from a settings dialog)
  Future<void> updateUseIsolates(bool value) async {
    if (_useIsolates == value) return;
    _useIsolates = value;

    notifyListeners();
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    await _discoveryService.startDiscovery(serviceType: '_camera._tcp');
    _discoveryService.discoveryStream.listen(_onServiceDiscovered);
    _discoveryService.removeStream.listen(_onServiceRemoved);
  }

  Future<void> stopListening() async {
    _isListening = false;
    // Cancel all provider timers
    for (var timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    // Close all active providers
    for (var provider in activeProviders.values) {
      await provider.closeCamera();
    }
    await _discoveryService.stopDiscovery();

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
    // NEW: Save initial FPS and schedule dynamic polling.
    _providerFps[address] = _fps;
    _scheduleNextPolling(provider, address);
    notifyListeners();
  }

  // NEW: Schedule the next polling for a provider based on its dynamic FPS.
  void _scheduleNextPolling(ICameraProvider provider, String address) {
    if (!_isListening || !activeProviders.containsKey(address)) return;
    final currentFps = _providerFps[address] ?? _fps;
    final intervalMs = (1000 / currentFps).round();
    _pollTimers[address]?.cancel();
    _pollTimers[address] = Timer(Duration(milliseconds: intervalMs), () async {
      await _pollFramesOnceDynamic(provider, address);
    });
  }

  // NEW: Poll a single frame, adjust dynamic FPS and reschedule polling.
  Future<void> _pollFramesOnceDynamic(
      ICameraProvider provider, String address) async {
    final frameStartTime = DateTime.now();
    try {
      final frame = await provider.getFrame();
      if (frame != null && frame.isNotEmpty) {
        final IFrameProcessor processor = _useIsolates
            ? IsolateFrameProcessor()
            : MainIsolateFrameProcessor();
        final result = await processor.processFrame(frame);
        if (result != null) {
          _lastFrames[address] = result['processedFrame'] as Uint8List;
          final List<dynamic> features = result['faceFeatures'];
          final List<dynamic> thumbnails = result['faceThumbnails'];
          for (int i = 0; i < features.length; i++) {
            _faceFeaturesStreamController.add(features[i] as List<double>);
            _compareWithTrackedFaces(
              features[i] as List<double>,
              address,
              thumbnails[i] as Uint8List?,
            );
            if (thumbnails[i] != null) {
              capturedFaces.insert(0, thumbnails[i] as Uint8List);
              if (capturedFaces.length > _maxFaces) {
                capturedFaces.removeLast();
              }
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error polling frames for $address: $e");
    }
    // Calculate frame processing time and adjust dynamic FPS.
    final processingTime =
        DateTime.now().difference(frameStartTime).inMilliseconds;
    int currentFps = _providerFps[address] ?? _fps;
    final expectedInterval = (1000 / currentFps).round();
    if (processingTime > expectedInterval) {
      currentFps = currentFps > 5 ? currentFps - 5 : 5;
    } else {
      currentFps = currentFps < _fps ? currentFps + 1 : _fps;
    }
    _providerFps[address] = currentFps;
    _scheduleNextPolling(provider, address);
  }

  // Modified: Restart dynamic frame polling with updated FPS values.
  void _restartFramePolling() {
    for (final address in activeProviders.keys) {
      _pollTimers[address]?.cancel();
      _providerFps[address] = _fps; // Reset dynamic FPS to max.
      final provider = activeProviders[address];
      if (provider != null) {
        _scheduleNextPolling(provider, address);
      }
    }
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

  /// Compares extracted face features with tracked faces.
  void _compareWithTrackedFaces(
      List<double> features, String providerAddress, Uint8List? faceThumbnail) {
    bool isKnownFace = false;

    for (final entry in trackedFaces.entries) {
      // final trackedId = entry.key;
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

  Uint8List? getLastFrame(String address) => _lastFrames[address];

  // NEW: Getter to retrieve the current FPS for a provider.
  int getProviderFps(String address) => _providerFps[address] ?? _fps;

  void updateTrackedFaceName(String faceId, String newName) {
    if (trackedFaces.containsKey(faceId)) {
      trackedFaces[faceId]!.setName(newName);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _faceFeaturesStreamController.close();
    stopListening();
    super.dispose();
  }
}
