import 'package:automated_attendance_app/services/camera_service.dart';
import 'package:flutter/material.dart';

class CameraModel extends ChangeNotifier {
  final CameraService _cameraService;
  List<int> _cameraIndices = [];
  bool _isLoading = false;

  CameraModel(this._cameraService);

  List<int> get cameraIndices => _cameraIndices;
  bool get isLoading => _isLoading;

  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();

    _cameraIndices = await _cameraService.getAvailableCameras();

    _isLoading = false;
    notifyListeners();
  }
}
