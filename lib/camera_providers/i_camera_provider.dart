import 'dart:typed_data';

abstract class ICameraProvider {
  Future<bool> openCamera();
  Future<void> closeCamera();
  Future<Uint8List?> getFrame();
  bool get isOpen;
}
