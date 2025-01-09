import 'dart:io';
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:permission_handler/permission_handler.dart';
import 'i_camera_provider.dart';

class LocalCameraProvider implements ICameraProvider {
  final int cameraIndex;
  late cv.VideoCapture _vc;
  bool _isOpen = false;

  LocalCameraProvider(this.cameraIndex);

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

    final (success, frame) = await _vc.readAsync();
    if (!success) return null;

    final (encSuccess, encodedFrame) = await cv.imencodeAsync('.jpg', frame);
    frame.dispose();
    if (!encSuccess) return null;
    return encodedFrame;
  }
}
