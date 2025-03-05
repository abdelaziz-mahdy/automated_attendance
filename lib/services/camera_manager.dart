import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/isolate/frame_processor.dart';
import 'package:automated_attendance/services/face_management_service.dart';

typedef CameraManagerCallback = void Function();
typedef FaceFeaturesCallback = void Function(
    List<double> features, String providerAddress, Uint8List? thumbnail);

/// Service responsible for discovery, connecting to, and managing camera providers.
/// Handles frame polling, processing, and dynamic FPS adjustments.
class CameraManager {
  final DiscoveryService _discoveryService = DiscoveryService();
  final FaceManagementService _faceManagementService;

  final Map<String, ICameraProvider> activeProviders = {};
  final Map<String, Uint8List> _lastFrames = {};
  final Map<String, Timer> _pollTimers = {};
  final Map<String, int> _providerFps = {};
  final List<Uint8List> capturedFaces = [];

  bool _isListening = false;
  late SharedPreferences _prefs;
  final int _fps = 10; // Default FPS for polling
  late int _maxFaces;
  bool _useIsolates = true;

  bool get useIsolates => _useIsolates;

  // Callbacks for state changes
  CameraManagerCallback? onStateChanged;
  FaceFeaturesCallback? onFaceFeaturesDetected;

  CameraManager(this._faceManagementService) {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _maxFaces = _prefs.getInt('maxFaces') ?? 10; // Default max faces
  }

  // Update settings and restart frame polling
  Future<void> updateSettings(int maxFaces) async {
    await _prefs.setInt('maxFaces', maxFaces);
    _maxFaces = maxFaces;
    // Reset dynamic FPS for each provider.
    for (var address in activeProviders.keys) {
      _providerFps[address] = _fps;
    }
    _restartFramePolling();
    _notifyStateChanged();
  }

  // Update the isolate usage flag
  Future<void> updateUseIsolates(bool value) async {
    if (_useIsolates == value) return;
    _useIsolates = value;
    _notifyStateChanged();
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

    // Close all active visits when shutting down
    await _faceManagementService.closeAllActiveVisits();

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
    // Save initial FPS and schedule dynamic polling.
    _providerFps[address] = _fps;
    _scheduleNextPolling(provider, address);
    _notifyStateChanged();
  }

  // Schedule the next polling for a provider based on its dynamic FPS
  void _scheduleNextPolling(ICameraProvider provider, String address) {
    if (!_isListening || !activeProviders.containsKey(address)) return;

    final currentFps = _providerFps[address] ?? _fps;
    final intervalMs = (1000 / currentFps).round();

    _pollTimers[address]?.cancel();
    _pollTimers[address] = Timer(Duration(milliseconds: intervalMs), () async {
      await _pollFramesOnceDynamic(provider, address);
    });
  }

  // Poll a single frame, adjust dynamic FPS and reschedule polling
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

          // Process each detected face
          for (int i = 0; i < features.length; i++) {
            // Notify about detected face features
            onFaceFeaturesDetected?.call(
              features[i] as List<double>,
              address,
              thumbnails[i] as Uint8List?,
            );

            // Store captured face thumbnails
            if (thumbnails[i] != null) {
              capturedFaces.insert(0, thumbnails[i] as Uint8List);
              if (capturedFaces.length > _maxFaces) {
                capturedFaces.removeLast();
              }
            }
          }
        }
      }
      _notifyStateChanged();
    } catch (e) {
      debugPrint("Error polling frames for $address: $e");
    }

    // Calculate frame processing time and adjust dynamic FPS
    final processingTime =
        DateTime.now().difference(frameStartTime).inMilliseconds;
    int currentFps = _providerFps[address] ?? _fps;
    final expectedInterval = (1000 / currentFps).round();

    // Adjust FPS based on processing time
    if (processingTime > expectedInterval) {
      currentFps = currentFps > 5 ? currentFps - 1 : 5;
    } else if (processingTime < expectedInterval) {
      currentFps = currentFps < _fps ? currentFps + 1 : _fps;
    }

    _providerFps[address] = currentFps;
    _scheduleNextPolling(provider, address);
  }

  // Restart frame polling with updated settings
  void _restartFramePolling() {
    for (final address in activeProviders.keys) {
      _pollTimers[address]?.cancel();
      _providerFps[address] = _fps; // Reset dynamic FPS to max
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

    // Close and remove the provider
    final provider = activeProviders.remove(address);
    if (provider != null) {
      await provider.closeCamera();
    }

    _lastFrames.remove(address);
    _notifyStateChanged();
  }

  // Get the latest frame for a provider
  Uint8List? getLastFrame(String address) => _lastFrames[address];

  // Get the current FPS for a provider
  int getProviderFps(String address) => _providerFps[address] ?? _fps;

  void _notifyStateChanged() {
    onStateChanged?.call();
  }

  void dispose() {
    stopListening();
  }
}
