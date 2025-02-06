import 'dart:io';
import 'dart:typed_data';
import 'package:automated_attendance/camera_providers/flutter_camera_provider.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:permission_handler/permission_handler.dart';
import 'i_camera_provider.dart';

class LocalCameraProvider implements ICameraProvider {
  final int cameraIndex;
  late cv.VideoCapture _vc;
  bool _isOpen = false;

  LocalCameraProvider(this.cameraIndex);
  int? cameraRotation;
  @override
  bool get isOpen => _isOpen;
  Future<bool> getPermission() async {
    if (Platform.isAndroid) {
      return (await Permission.camera.request()).isGranted;
    } else {
      return true;
    }
  }

  @override
  Future<bool> openCamera() async {
    if (!await getPermission()) {
      return false;
    }
    try {
      _vc = await cv.VideoCaptureAsync.fromDeviceAsync(cameraIndex);
      if (Platform.isAndroid) {
        cameraRotation =
            (await MobileCameraProvider.getAvailableCameras())[cameraIndex]
                .sensorOrientation;
      }
      if (_vc.isOpened) {
        _isOpen = true;
        return true;
      }
    } catch (e) {
      print("Error opening local camera: $e");
    }
    _isOpen = false;
    return false;
  }

  @override
  Future<void> closeCamera() async {
    if (_isOpen) {
      _vc.release();
      _isOpen = false;
    }
  }

  @override
  Future<Uint8List?> getFrame() async {
    if (!_isOpen) return null;

    var (success, frame) = await _vc.readAsync();
    if (!success) return null;

    if (Platform.isAndroid) {
      frame = await cv.cvtColorAsync(frame, cv.COLOR_YUV2BGRA_NV21);
      if (cameraRotation == 90) {
        frame = await cv.rotateAsync(frame, cv.ROTATE_90_CLOCKWISE);
      } else if (cameraRotation == 270) {
        frame = await cv.rotateAsync(frame, cv.ROTATE_90_COUNTERCLOCKWISE);
      }
    }
    final (encSuccess, encodedFrame) = await cv.imencodeAsync('.jpg', frame);
    frame.dispose();
    if (!encSuccess) return null;
    return encodedFrame;
  }
}
