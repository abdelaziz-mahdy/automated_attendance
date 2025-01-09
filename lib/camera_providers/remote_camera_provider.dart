import 'dart:io';
import 'package:flutter/foundation.dart';
import 'i_camera_provider.dart';

class RemoteCameraProvider implements ICameraProvider {
  final String serverAddress; // e.g. "192.168.1.10"
  final int serverPort; // e.g. 12345
  bool _isOpen = false;

  RemoteCameraProvider({required this.serverAddress, required this.serverPort});

  @override
  bool get isOpen => _isOpen;

  @override
  Future<bool> openCamera() async {
    // For a remote camera, "openCamera" might just mean a test request
    // to ensure we can connect. If successful, set _isOpen = true.
    final testUrl = Uri.parse('http://$serverAddress:$serverPort/test');
    try {
      final response =
          await HttpClient().getUrl(testUrl).then((req) => req.close());
      if (response.statusCode == 200) {
        _isOpen = true;
        return true;
      }
    } catch (e) {
      print("Error opening remote camera: $e");
    }
    return false;
  }

  @override
  Future<void> closeCamera() async {
    // No actual "close" needed for remote, but we set our local flag
    _isOpen = false;
  }

  @override
  Future<Uint8List?> getFrame() async {
    if (!_isOpen) return null;

    final url = Uri.parse('http://$serverAddress:$serverPort/get_image');
    try {
      final requestTime = DateTime.now();
      final response =
          await HttpClient().getUrl(url).then((req) => req.close());
      final bytes = await consolidateHttpClientResponseBytes(response);
      final endTime = DateTime.now();
      print(
          "Remote frame request took: ${endTime.difference(requestTime).inMilliseconds} ms");
      return bytes;
    } catch (e) {
      print("Error retrieving remote frame: $e");
      return null;
    }
  }

  @override
  get availableCameras => throw UnimplementedError();
}
