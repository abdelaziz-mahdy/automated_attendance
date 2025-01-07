import 'package:opencv_dart/opencv_dart.dart' as cv;

class CameraService {
  Future<List<int>> getAvailableCameras() async {
    List<int> availableCameras = [];
    for (int index = 0; index < 10; index++) {
      try {
        final vc = cv.VideoCapture.fromDevice(index);
        if (vc.isOpened) {
          availableCameras.add(index);
          vc.release();
          print("camera index $index is available");
        } else {
          print("camera index $index is not available");
        }
      } catch (e) {
        // Break if no more cameras
        print("request camera index $index failed with error: $e");
        break;
      }
    }
    return availableCameras;
  }
}
