import 'dart:async';

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
    
    // Decode the input bytes into an OpenCV Mat
    final (frame) = await cv.imdecodeAsync(inputBytes, cv.IMREAD_COLOR);
    if (frame.isEmpty) {
      print('Failed to decode image!');
      return null;
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
        print('Failed to encode image!');
      }
      return null;
    }

    // Return the result as a class instance
    return FaceProcessingResult(
      processedFrame: encodedBytes,
      processedFrameMat: processedFrame,
      faces: faces,
    );
  }
}
