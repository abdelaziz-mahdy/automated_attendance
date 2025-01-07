import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceComparisonService {
  static final FaceComparisonService _instance =
      FaceComparisonService._privateConstructor();
  cv.FaceRecognizerSF? _recognizer;

  FaceComparisonService._privateConstructor();

  factory FaceComparisonService() {
    return _instance;
  }

  void initialize(String modelPath) {
    _recognizer ??= cv.FaceRecognizerSF.fromFile(modelPath, "");
  }

  bool areFeaturesSimilar(
    List<double> feature1,
    List<double> feature2, {
    double cosineThreshold = 0.38,
    double normL2Threshold = 1.12,
  }) {
    final cosineDistance = _calculateCosineDistance(feature1, feature2);
    final normL2Distance = _calculateNormL2Distance(feature1, feature2);

    return cosineDistance >= cosineThreshold &&
        normL2Distance <= normL2Threshold;
  }

  (double cosineDistance, double normL2Distance) getConfidence(
    List<double> feature1,
    List<double> feature2,
  ) {
    final cosineDistance = _calculateCosineDistance(feature1, feature2);
    final normL2Distance = _calculateNormL2Distance(feature1, feature2);
    return (cosineDistance, normL2Distance);
  }

  double _calculateCosineDistance(
    List<double> feature1,
    List<double> feature2,
  ) {
    final mat1 =
        cv.Mat.fromList(1, feature1.length, cv.MatType.CV_32FC1, feature1);
    final mat2 =
        cv.Mat.fromList(1, feature2.length, cv.MatType.CV_32FC1, feature2);
    final cosineDistance =
        _recognizer!.match(mat1, mat2, disType: cv.FaceRecognizerSF.FR_COSINE);

    mat1.dispose();
    mat2.dispose();
    return cosineDistance;
  }

  double _calculateNormL2Distance(
    List<double> feature1,
    List<double> feature2,
  ) {
    final mat1 =
        cv.Mat.fromList(1, feature1.length, cv.MatType.CV_32FC1, feature1);
    final mat2 =
        cv.Mat.fromList(1, feature2.length, cv.MatType.CV_32FC1, feature2);
    final normL2Distance =
        _recognizer!.match(mat1, mat2, disType: cv.FaceRecognizerSF.FR_NORM_L2);

    mat1.dispose();
    mat2.dispose();
    return normL2Distance;
  }
}
