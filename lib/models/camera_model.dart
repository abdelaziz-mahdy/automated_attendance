import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/services/camera_service.dart';
import 'package:flutter/material.dart';

class CameraModel extends ChangeNotifier {
  final CameraService _cameraService;
  final DiscoveryService _discoveryService;

  List<int> _cameraIndices = [];
  List<ServiceInfo> _serverCameras = [];
  bool _isLoading = false;

  CameraModel(this._cameraService, this._discoveryService);

  List<int> get cameraIndices => _cameraIndices;
  List<ServiceInfo> get serverCameras => _serverCameras;
  bool get isLoading => _isLoading;

  Future<void> fetchCameras(String source) async {
    _isLoading = true;
    notifyListeners();

    if (source == 'local') {
      _cameraIndices = await _cameraService.getAvailableCameras();
    } else if (source == 'server') {
      await _discoveryService.startDiscovery(
          serviceType: '_camera._tcp', port: 12345);
      _serverCameras = _discoveryService.activeServices;
    }

    _isLoading = false;
    notifyListeners();
  }
}
