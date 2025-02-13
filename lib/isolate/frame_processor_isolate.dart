import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:flutter/foundation.dart';
import 'frame_processor_sync.dart' as sync;

final isolateToken = ServicesBinding.rootIsolateToken!;

void frameProcessorIsolateLongRunningEntry(List<dynamic> params) {
  SendPort initialReplyTo = params[0];
  RootIsolateToken isolateToken = params[1];
  Map<String, String> modelPaths = params[2] as Map<String, String>;

  BackgroundIsolateBinaryMessenger.ensureInitialized(isolateToken);

  FaceExtractionService().initialize(modelPaths['faceDetectionModelPath']!);
  FaceFeaturesExtractionService()
      .initialize(modelPaths['faceFeaturesExtractionModelPath']!);
  FaceComparisonService()
      .initialize(modelPaths['faceFeaturesExtractionModelPath']!);

  final port = ReceivePort();
  initialReplyTo.send(port.sendPort);

  port.listen((message) {
    if (message is List && message.length == 2) {
      final Uint8List frameBytes = message[0];
      final SendPort replyPort = message[1];
      try {
        Stopwatch stopwatch = Stopwatch()..start();
        final result = sync.processFrame(frameBytes);
        print('Isolate processing time: ${stopwatch.elapsedMilliseconds} ms');
        replyPort.send(result);
      } catch (e, s) {
        if (kDebugMode) {
          print(
              'Isolate Error processing frame: $e\nStackTrace: $s\n###########################################');
        }
        replyPort.send(null);
      }
    }
  });
}
