import 'package:opencv_dart/opencv_dart.dart' as cv;

class LocalCameraPicker {
  static List<Map<String, dynamic>> get availableCameras {
    final List<Map<String, dynamic>> cameraInfoList = [];

    // Adjust the upper bound as needed if you suspect more cameras
    for (int i = 0; i < 10; i++) {
      final capture = cv.VideoCapture.fromDevice(i);
      // Check if camera opened successfully
      if (capture.isOpened) {
        // Retrieve camera properties
        final width = capture.get(cv.CAP_PROP_FRAME_WIDTH);
        final height = capture.get(cv.CAP_PROP_FRAME_HEIGHT);
        final fps = capture.get(cv.CAP_PROP_FPS);
        // Close the camera to free resources
        capture.release();

        cameraInfoList.add({
          'name': 'Camera $i',
          'index': i,
          'width': width,
          'height': height,
          'fps': fps,
        });
      }
    }

    return cameraInfoList;
  }

  /// Sort cameras by "quality": (width * height) descending, then FPS descending.
  static List<Map<String, dynamic>> get sortedCamerasByQuality {
    // Make a copy so we don't mutate the original list
    final List<Map<String, dynamic>> sortedList = List.from(availableCameras);

    sortedList.sort((a, b) {
      // Compare total resolution (width*height) first
      final resolutionA = (a['width'] as double) * (a['height'] as double);
      final resolutionB = (b['width'] as double) * (b['height'] as double);
      final resolutionCompare = resolutionB.compareTo(resolutionA);

      if (resolutionCompare != 0) {
        return resolutionCompare; // higher resolution first
      } else {
        // If resolution is the same, compare FPS
        final fpsA = a['fps'] as double;
        final fpsB = b['fps'] as double;
        return fpsB.compareTo(fpsA); // higher FPS first
      }
    });

    return sortedList;
  }

  /// Returns the index of the best camera (highest resolution and FPS).
  static int get highestCameraIndex {
    final sorted = sortedCamerasByQuality;
    if (sorted.isNotEmpty) {
      // Since sortedCamerasByQuality puts highest quality at the front,
      // the first element has the "best" camera.
      return sorted.first['index'] as int;
    }
    // If no cameras are found
    return -1;
  }
}
