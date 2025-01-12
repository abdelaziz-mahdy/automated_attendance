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

  final StreamController<List<double>> _faceFeaturesStreamController =
      StreamController.broadcast();

  Stream<List<double>> get faceFeaturesStream =>
      _faceFeaturesStreamController.stream;

  bool _isListening = false;

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    await _discoveryService.startDiscovery(serviceType: '_camera._tcp');

    // Handle discovered services
    _discoveryService.discoveryStream.listen(_onServiceDiscovered);
    _discoveryService.removeStream.listen(_onServiceRemoved);
  }

  Future<void> stopListening() async {
    _isListening = false;

    await _discoveryService.stopDiscovery();
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

    // Start polling frames in the background
    _pollFrames(provider, address);

    notifyListeners();
  }

  Future<void> _onServiceRemoved(ServiceInfo serviceInfo) async {
    final address = serviceInfo.address;

    if (address == null) return;

    final provider = activeProviders.remove(address);
    if (provider != null) {
      await provider.closeCamera();
    }

    _lastFrames.remove(address);
    notifyListeners();
  }

  Future<void> _pollFrames(ICameraProvider provider, String address) async {
    while (activeProviders.containsKey(address)) {
      try {
        final frame = await provider.getFrame();
        if (frame != null) {
          // Process frame for face features
          final processedFrame =
              await FaceProcessingService.processFrame(frame);
          _lastFrames[address] = processedFrame!.processedFrame;

          if (processedFrame != null) {
            final features = await _extractFaceFeatures(
                processedFrame.processedFrameMat, processedFrame.faces);
            if (features.isNotEmpty) {
              for (var feature in features) {
                _faceFeaturesStreamController.add(feature);
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error polling frames for $address: $e");
      }

      /// fps = 10
      int fps = 10;
      notifyListeners();
      await Future.delayed(Duration(milliseconds: (1000 / fps).round()));
    }
  }

  Future<List<List<double>>> _extractFaceFeatures(
      Mat frameBytes, Mat faces) async {
    return await FaceFeaturesExtractionService()
        .extractFaceFeatures(frameBytes, faces);
  }

  Uint8List? getLastFrame(String address) => _lastFrames[address];

  @override
  void dispose() {
    _faceFeaturesStreamController.close();
    stopListening();
    super.dispose();
  }
}
