// camera_manager.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/isolate/frame_processor_manager.dart';
import 'package:automated_attendance/main.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/services/face_processing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
// lib/isolate/frame_processor_isolate.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;
// For compute()
// lib/isolate/frame_processor_manager.dart

/// This is the long-running isolate’s entry point.
/// It first sends back its SendPort so that the main isolate can communicate with it,
/// then listens for incoming messages.
// RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
final isolateToken = ServicesBinding.rootIsolateToken!;

void frameProcessorIsolateLongRunningEntry(List<dynamic> params) {
  SendPort initialReplyTo = params[0];
  RootIsolateToken isolateToken = params[1];
  // Retrieve the model paths map.
  Map<String, String> modelPaths = params[2] as Map<String, String>;

  // Initialize the binary messenger for isolates.
  BackgroundIsolateBinaryMessenger.ensureInitialized(isolateToken);

  // Initialize your models using the file paths.
  FaceExtractionService().initialize(modelPaths['faceDetectionModelPath']!);
  FaceFeaturesExtractionService().initialize(modelPaths['faceFeaturesExtractionModelPath']!);
  FaceComparisonService().initialize(modelPaths['faceFeaturesExtractionModelPath']!);

  final port = ReceivePort();
  // Send the SendPort of this isolate back to the main isolate.
  initialReplyTo.send(port.sendPort);

  port.listen((message) async {
    // Expect message as [frameBytes, replyPort].
    if (message is List && message.length == 2) {
      final Uint8List frameBytes = message[0];
      final SendPort replyPort = message[1];
      try {
        Stopwatch stopwatch = Stopwatch()..start();
        final result = await frameProcessorIsolateEntry(frameBytes);
        print('Isolate processing time: ${stopwatch.elapsedMilliseconds} ms');
        replyPort.send(result);
      } catch (e, s) {
        if (kDebugMode) {
          print('''
Isolate Error processing frame: $e 
StackTrace: $s
###########################################
''');
        }
        replyPort.send(null);
      }
    }
  });
}

/// Common processing logic: decode the frame, detect faces, annotate,
/// extract features, and crop thumbnails.
Future<Map<String, dynamic>?> _processFrameCommon(Uint8List frameBytes) async {
  // 1. Process the frame (decode, detect faces, annotate, etc.)
  final processingResult = await FaceProcessingService.processFrame(frameBytes);
  if (processingResult == null) return null;

  // 2. Extract face features.
  final features = await FaceFeaturesExtractionService().extractFaceFeatures(
    processingResult.processedFrameMat,
    processingResult.faces,
  );

  // 3. Crop a thumbnail for each detected face.
  List<Uint8List?> thumbnails = [];
  for (int i = 0; i < processingResult.faces.rows; i++) {
    final thumb = await _cropFaceThumbnail(
        processingResult.processedFrameMat, processingResult.faces, i);
    thumbnails.add(thumb);
  }

  // Return only transferable data.
  return {
    'processedFrame': processingResult.processedFrame, // JPEG bytes.
    'faceFeatures': features, // List<List<double>>.
    'faceThumbnails': thumbnails, // List<Uint8List?>.
  };
}

/// Helper: Crop a face thumbnail from the detected faces.
Future<Uint8List?> _cropFaceThumbnail(
    cv.Mat image, cv.Mat faces, int faceIndex) async {
  if (faceIndex < 0 || faceIndex >= faces.rows) return null;
  final x = faces.at<double>(faceIndex, 0).toInt();
  final y = faces.at<double>(faceIndex, 1).toInt();
  final w = faces.at<double>(faceIndex, 2).toInt();
  final h = faces.at<double>(faceIndex, 3).toInt();

  final safeW = (x + w) > image.width ? image.width - x : w;
  final safeH = (y + h) > image.height ? image.height - y : h;
  if (safeW <= 0 || safeH <= 0) return null;

  final faceRect = cv.Rect(x, y, safeW, safeH);
  final faceMat = await image.regionAsync(faceRect);
  final result = await cv.imencodeAsync('.jpg', faceMat);
  faceMat.dispose();

  if (result.$1) {
    return result.$2;
  }
  return null;
}

/// This is the isolate’s entry point. It must be a top-level or static function.
/// It calls the common processing logic.
Future<Map<String, dynamic>?> frameProcessorIsolateEntry(
    Uint8List frameBytes) async {
  return await _processFrameCommon(frameBytes);
}

/// Processes the given frame using either the long-running isolate or directly,
/// based on the [useIsolate] flag.
Future<Map<String, dynamic>?> processFrameGeneric(
  Uint8List frameBytes,
  bool useIsolate,
) async {
  if (useIsolate) {
    // Use the long-running isolate.
    return await FrameProcessorManager().processFrame(frameBytes);
  } else {
    // Process directly on the main thread.
    return await frameProcessorIsolateEntry(frameBytes);
  }
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

  // Settings variables
  late SharedPreferences _prefs;
  late int _fps;
  late int _maxFaces;
  // Flag to toggle processing mode. Default true (using isolates).
  bool _useIsolates = true;
  bool get useIsolates => _useIsolates;
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

    _startPollingForProvider(provider, address);
    notifyListeners();
  }

  void _startPollingForProvider(ICameraProvider provider, String address) {
    // Cancel any existing timer for this provider
    _pollTimers[address]?.cancel();

    final pollInterval = Duration(milliseconds: (1000 / _fps).round());
    _pollTimers[address] = Timer.periodic(pollInterval, (timer) {
      // If the provider is removed or manager is not listening, cancel the timer.
      if (!_isListening || !activeProviders.containsKey(address)) {
        timer.cancel();
        _pollTimers.remove(address);
        return;
      }
      _pollFramesOnce(provider, address);
    });
  }

  // Restarts the frame polling with updated FPS value
  void _restartFramePolling() {
    for (final address in activeProviders.keys) {
      final provider = activeProviders[address];
      if (provider != null) {
        _startPollingForProvider(provider, address);
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

  /// Modify _pollFramesOnce to send the frame to the isolate.
  Future<void> _pollFramesOnce(ICameraProvider provider, String address) async {
    try {
      final frame = await provider.getFrame();
      if (frame != null && frame.isNotEmpty) {
        // Use the same processing function regardless of mode.
        final result = await processFrameGeneric(frame, _useIsolates);

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

  Uint8List? getLastFrame(String address) => _lastFrames[address];

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
