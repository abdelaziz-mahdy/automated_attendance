// camera_manager.dart

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

class ProviderIsolateHandler {
  final String providerId;
  final Isolate isolate;
  final SendPort sendPort;

  ProviderIsolateHandler({
    required this.providerId,
    required this.isolate,
    required this.sendPort,
  });

  /// Sends the given frame bytes to the isolate and waits for the result.
  Future<Map<String, dynamic>?> processFrame(Uint8List frameBytes) async {
    final responsePort = ReceivePort();
    // Send a message: [frameBytes, replyPort]
    sendPort.send([frameBytes, responsePort.sendPort]);
    final result = await responsePort.first;
    responsePort.close();
    return result as Map<String, dynamic>?;
  }

  /// Kill the isolate when no longer needed.
  void dispose() {
    isolate.kill(priority: Isolate.immediate);
  }
}
