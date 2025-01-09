import 'dart:async';
import 'dart:typed_data';

import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceProcessingService {
  /// Processes the input image by detecting faces, drawing boundaries,
  /// and returning the re-encoded JPEG.
  static Future<Uint8List?> processFrame(Uint8List inputBytes) async {
    // 1) Decode the input bytes into an OpenCV Mat
    final (frame) = await cv.imdecodeAsync(inputBytes, cv.IMREAD_COLOR);
    // if (!decodedSuccess) {
    //   // Handle decode error as needed (throw, return null, etc.)
    //   print('Failed to decode image!');
    //   return null;
    // }

    // 2) Extract faces
    final faces = FaceExtractionService().extractFacesBoundaries(frame);

    // 3) Visualize face detection
    final processedFrame =
        FaceFeaturesExtractionService().visualizeFaceDetect(frame, faces);

    // 4) Re-encode the processed frame back to JPEG
    final (encodeSuccess, encodedBytes) =
        await cv.imencodeAsync('.jpg', processedFrame);
    if (!encodeSuccess) {
      print('Failed to encode image!');
      return null;
    }

    return encodedBytes;
  }
}
