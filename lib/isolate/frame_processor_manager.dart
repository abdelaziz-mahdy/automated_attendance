// camera_manager.dart

import 'dart:async';
import 'dart:isolate';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FrameProcessorManager {
  static final FrameProcessorManager _instance =
      FrameProcessorManager._internal();
  factory FrameProcessorManager() => _instance;
  FrameProcessorManager._internal();

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

  Future<void> _spawnIsolate() async {
    WidgetsFlutterBinding.ensureInitialized();
    final receivePort = ReceivePort();
    // Spawn the long-running isolate using frameProcessorIsolateEntry as the entry.
    await Isolate.spawn(frameProcessorIsolateLongRunningEntry,
        [receivePort.sendPort, ServicesBinding.rootIsolateToken]);
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
