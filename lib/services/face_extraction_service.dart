import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceExtractionService {
  static final FaceExtractionService _instance =
      FaceExtractionService._privateConstructor();
  cv.FaceDetectorYN? _faceDetector;

  FaceExtractionService._privateConstructor();

  factory FaceExtractionService() {
    return _instance;
  }

  void initialize(String modelPath) {
    _faceDetector ??= cv.FaceDetectorYN.fromFile(
      modelPath,
      "",
      (320, 320),
    );
  }

  cv.Mat extractFacesBoundaries(cv.Mat image) {
    if (_faceDetector == null) {
      throw Exception("Face detector not initialized!");
    }
    _faceDetector!.setInputSize((image.width, image.height));
    final faces = _faceDetector!.detect(image);
    return faces;
  }
}
