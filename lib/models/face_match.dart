import 'package:automated_attendance/models/tracked_face.dart';

/// Represents a face match with a similarity score
class FaceMatch {
  final String id;
  final TrackedFace face;
  final double similarityScore; // 0-100 percentage
  final double cosineDistance;
  final double normL2Distance;

  FaceMatch({
    required this.id,
    required this.face,
    required this.similarityScore,
    required this.cosineDistance,
    required this.normL2Distance,
  });
}
