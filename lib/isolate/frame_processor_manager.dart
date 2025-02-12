// camera_manager.dart

import 'dart:async';
import 'dart:isolate';
import 'package:automated_attendance/isolate/frame_processor_isolate.dart';
import 'package:automated_attendance/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FrameProcessorManagerIsolate {
  static final FrameProcessorManagerIsolate _instance =
      FrameProcessorManagerIsolate._internal();
  factory FrameProcessorManagerIsolate() => _instance;
  FrameProcessorManagerIsolate._internal();

  SendPort? _sendPort;
  bool _isSpawning = false;
  final Completer<SendPort> _sendPortCompleter = Completer<SendPort>();

  /// Returns the SendPort for the long-running isolate.
  Future<SendPort> get sendPort async {
    if (_sendPort != null) return _sendPort!;
    if (!_isSpawning) {
      _isSpawning = true;
      await _spawnIsolate();
    }
    return _sendPortCompleter.future;
  }

// In frame_processor_manager.dart
  Future<void> _spawnIsolate() async {
    WidgetsFlutterBinding.ensureInitialized();
    final receivePort = ReceivePort();

    // Copy assets from the main isolate (using rootBundle) to a temporary directory.
    final faceDetectionModelPath =
        await copyAssetFileToTmp("assets/face_detection_yunet_2023mar.onnx");
    final faceFeaturesExtractionModelPath =
        await copyAssetFileToTmp("assets/face_recognition_sface_2021dec.onnx");

    // Bundle the model paths into a Map.
    final modelPaths = {
      'faceDetectionModelPath': faceDetectionModelPath,
      'faceFeaturesExtractionModelPath': faceFeaturesExtractionModelPath,
    };

    // Pass the modelPaths along with the SendPort and RootIsolateToken.
    await Isolate.spawn(
      frameProcessorIsolateLongRunningEntry,
      [receivePort.sendPort, ServicesBinding.rootIsolateToken, modelPaths],
    );

    _sendPort = await receivePort.first as SendPort;
    _sendPortCompleter.complete(_sendPort);
    receivePort.close();
  }

  /// Process a frame via the long-running isolate.
  Future<Map<String, dynamic>?> processFrame(Uint8List frameBytes) async {
    final sp = await sendPort;
    final responsePort = ReceivePort();
    sp.send([frameBytes, responsePort.sendPort]);
    final result = await responsePort.first;
    responsePort.close();
    return result as Map<String, dynamic>?;
  }
}
