import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceProcessingResult {
  final Uint8List processedFrame; // Processed image as a JPEG byte array
  final cv.Mat processedFrameMat; // Processed image as an OpenCV Mat
  final cv.Mat faces; // List of detected face boundaries

  FaceProcessingResult({
    required this.processedFrame,
    required this.faces,
    required this.processedFrameMat,
  });
}

class FaceProcessingService {
  /// Processes the input image by detecting faces, drawing boundaries,
  /// and returning a `FaceProcessingResult` containing the processed frame
  /// and detected face boundaries.
  static Future<FaceProcessingResult?> processFrame(
      Uint8List inputBytes) async {
    final receivePort = ReceivePort();
    Isolate.spawn(_processFrameInIsolate,
        [inputBytes, receivePort.sendPort]);
    return await receivePort.first;
  }
}

/// Top-level function to be used as the isolate entry point
Future<void> _processFrameInIsolate(List<dynamic> args) async {
  final Uint8List inputBytes = args[0];
  final SendPort sendPort = args[1];

  // Decode the input bytes into an OpenCV Mat
  final (frame) = await cv.imdecodeAsync(inputBytes, cv.IMREAD_COLOR);
  if (frame.isEmpty) {
    if (kDebugMode) {
      print('Failed to decode image in isolate!');
    }
    sendPort.send(null);
    return;
  }

  // Detect faces in the frame
  final faces = FaceExtractionService().extractFacesBoundaries(frame);

  // Visualize detected faces on the frame
  final processedFrame =
      FaceFeaturesExtractionService().visualizeFaceDetect(frame, faces);

  // Encode the processed frame back into JPEG format
  final (encodeSuccess, encodedBytes) =
      await cv.imencodeAsync('.jpg', processedFrame);

  if (!encodeSuccess) {
    if (kDebugMode) {
      print('Failed to encode image in isolate!');
    }
    sendPort.send(null);
    return;
  }

  // Return the result as a class instance
  final result = FaceProcessingResult(
    processedFrame: encodedBytes,
    processedFrameMat: processedFrame,
    faces: faces,
  );
  sendPort.send(result);
}
