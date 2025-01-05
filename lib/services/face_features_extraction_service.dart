import 'package:cameras_viewer/models/sendable_rect.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceFeaturesExtractionService {
  static final FaceFeaturesExtractionService _instance =
      FaceFeaturesExtractionService._privateConstructor();
  late cv.FaceRecognizerSF? _recognizer;

  FaceFeaturesExtractionService._privateConstructor();

  factory FaceFeaturesExtractionService() {
    return _instance;
  }

  void initialize(String modelPath) {
    _recognizer ??= cv.FaceRecognizerSF.fromFile(modelPath, "");
  }

  List<List<double>> extractFaceFeatures(
    cv.Mat image,
    cv.Mat faces,
  ) {
    List<List<double>> faceFeatures = [];
    final faceBoundaries = List.generate(faces.rows, (i) {
      final x = faces.at<double>(i, 0).toInt();
      final y = faces.at<double>(i, 1).toInt();
      final width = faces.at<double>(i, 2).toInt();
      final height = faces.at<double>(i, 3).toInt();
      final correctedWidth =
          (x + width) > image.width ? image.width - x : width;
      final correctedHeight =
          (y + height) > image.height ? image.height - y : height;
      final rawDetection =
          List.generate(faces.width, (index) => faces.at<double>(i, index));
      return SendableRect(
        x: x,
        y: y,
        width: correctedWidth,
        height: correctedHeight,
        rawDetection: rawDetection,
        // originalImagePath: imagePath,
      );
    });

    for (var rect in faceBoundaries) {
      try {
        final faceBox = cv.Mat.fromList(1, rect.rawDetection.length,
            cv.MatType.CV_32FC1, rect.rawDetection);

        final alignedFace = _recognizer!.alignCrop(image, faceBox);
        final featureMat = _recognizer!.feature(alignedFace);
        final feature = List<double>.generate(
          featureMat.width,
          (index) => featureMat.at<double>(0, index),
        );
        faceFeatures.add(feature);

        alignedFace.dispose();
        faceBox.dispose();
      } catch (e) {
        print("Error extracting face feature: $e");
      }
    }
    return faceFeatures;
  }
}
