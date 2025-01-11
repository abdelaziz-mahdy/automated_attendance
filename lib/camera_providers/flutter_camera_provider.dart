import 'dart:io';
import 'dart:typed_data';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:opencv_dart/opencv_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

class AndroidCameraProvider implements ICameraProvider {
  late CameraController _controller;
  bool _isOpen = false;

  /// Choose which camera index you want, typically 0 for back, 1 for front, etc.
  final int cameraIndex;

  @override
  bool get isOpen => _isOpen;

  Uint8List? _latestFrame;
  AndroidCameraProvider(this.cameraIndex);

  /// Request camera permission on Android; on iOS the camera plugin handles it for you,
  /// but we’ll do this for completeness.
  Future<bool> _getPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }
    return true;
  }

  static Future<List<CameraDescription>> getAvailableCameras() async {
    return await availableCameras();
  }

  @override
  Future<bool> openCamera() async {
    if (!await _getPermission()) {
      return false;
    }

    try {
      // 1. Get the list of available cameras
      final cameras = await getAvailableCameras();

      // 2. Check if the requested index is valid
      if (cameraIndex < 0 || cameraIndex >= cameras.length) {
        print("Invalid camera index: $cameraIndex");
        return false;
      }
      var idx = cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (idx < 0) {
        print("No Back camera found - weird");
        return false;
      }
      // 3. Create a CameraController for the desired camera
      _controller = CameraController(
        cameras[idx],
        ResolutionPreset.medium, // or high, low, etc.
        enableAudio: false, // set to true if you also need audio
      );

      // 4. Initialize the controller
      await _controller.initialize();
      _controller.startImageStream((image) async {
        // Do something with the image
        // e.g. convert to bytes, process, etc.
        CameraImage img = image;
        _latestFrame = await convertCameraImageToMat(
            yBuffer: img.planes[0].bytes,
            uBuffer: img.planes[1].bytes,
            vBuffer: img.planes[2].bytes,
            cameraImageHeight: img.height,
            cameraImageWidth: img.width,
            rotation: img.planes[0].bytesPerRow);
      });
      // If initialization was successful
      _isOpen = true;
      return true;
    } catch (e, s) {
      print("Error opening flutter camera: $e");
      print(s);
      _isOpen = false;
      return false;
    }
  }

  @override
  Future<void> closeCamera() async {
    if (_isOpen) {
      await _controller.dispose();
      _isOpen = false;
    }
  }

  /// Captures a still image as a JPEG, returning its bytes.
  /// This is a one-shot capture, so if you need continuous frames,
  /// consider using [startImageStream()] from the camera package.
  @override
  Future<Uint8List?> getFrame() async {
    if (!_isOpen) return null;

    try {
      return _latestFrame;
    } catch (e) {
      print("Error capturing frame: $e");
      return null;
    }
  }
}

Future<Uint8List> convertCameraImageToMat({
  required Uint8List yBuffer,
  Uint8List? uBuffer,
  Uint8List? vBuffer,
  required int cameraImageHeight,
  required int cameraImageWidth,
  required int rotation, // 0, 90, 180, 270
}) async {
  // 1) Merge the buffers if on Android (NV21 => Y + V + U).
  //    On iOS, we just have yBuffer (often BGRA).
  late Uint8List mergedBytes;
  if (Platform.isAndroid) {
    final totalSize = yBuffer.lengthInBytes +
        (vBuffer?.lengthInBytes ?? 0) +
        (uBuffer?.lengthInBytes ?? 0);

    mergedBytes = Uint8List(totalSize);
    mergedBytes.setAll(0, yBuffer);
    if (vBuffer != null) {
      mergedBytes.setAll(yBuffer.lengthInBytes, vBuffer);
    }
    if (uBuffer != null && vBuffer != null) {
      mergedBytes.setAll(
        yBuffer.lengthInBytes + vBuffer.lengthInBytes,
        uBuffer,
      );
    }
  } else {
    // iOS usually has a single plane with BGRA or similar
    mergedBytes = yBuffer;
  }

  // 2) Create a Mat from the merged bytes. We skip color conversion here.
  //    - Android NV21: (height + height/2) x width, CV_8UC1
  //    - iOS BGRA: height x width, CV_8UC4 (assuming 4 channels)
  Mat mat = Platform.isAndroid
      ? Mat.fromList(
          cameraImageHeight + (cameraImageHeight ~/ 2),
          cameraImageWidth,
          MatType.CV_8UC1, // 1 channel for NV21
          mergedBytes.map((b) => b as num).toList(),
        )
      : Mat.fromList(
          cameraImageHeight,
          cameraImageWidth,
          MatType.CV_8UC4, // 4 channels for BGRA
          mergedBytes.map((b) => b as num).toList(),
        );

  // // 3) Rotate if needed. (Adjust rotation codes to match your environment.)
  // //    For example, you might define:
  // //      90   => ROTATE_90_CLOCKWISE
  // //      180  => ROTATE_180
  // //      270  => ROTATE_90_COUNTERCLOCKWISE
  // if (rotation == 90) {
  //   mat.rotate(RotateFlags.ROTATE_90_CLOCKWISE, inplace: true);
  // } else if (rotation == 180) {
  //   mat.rotate(RotateFlags.ROTATE_180, inplace: true);
  // } else if (rotation == 270) {
  //   mat.rotate(RotateFlags.ROTATE_90_COUNTERCLOCKWISE, inplace: true);
  // }
  mat = cvtColor(mat, COLOR_YUV2BGRA_NV21);
  // Return the final Mat. At this point, no resizing or normalization has been performed.
  // You can now pass this Mat into your native functions if you want to do color
  // conversion or run inference in C++.
  final result = imencode(".jpg", mat);
  final success = result.$1;
  final bytes = result.$2;
  return bytes;
}
