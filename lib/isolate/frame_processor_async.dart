import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:automated_attendance/services/face_processing_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';

/// Common processing logic: decode the frame, detect faces, annotate,
/// extract features, and crop thumbnails.
Future<Map<String, dynamic>?> processFrameAsync(Uint8List frameBytes) async {
  // 1. Process the frame (decode, detect faces, annotate, etc.)
  final processingResult =
      await FaceProcessingService.processFrameAsync(frameBytes);
  if (processingResult == null) return null;

  // 2. Extract face features.
  final features =
      await FaceFeaturesExtractionService().extractFaceFeaturesAsync(
    processingResult.processedFrameMat,
    processingResult.faces,
  );

  // 3. Crop a thumbnail for each detected face.
  List<Uint8List?> thumbnails = [];
  for (int i = 0; i < processingResult.faces.rows; i++) {
    final thumb = await cropFaceThumbnailAsync(
        processingResult.decodedFrame, processingResult.faces, i);
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
Future<Uint8List?> cropFaceThumbnailAsync(
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
