import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/models/face_match.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/services/face_management_service.dart';

/// The main provider that coordinates all UI state and service interactions
class UIStateController with ChangeNotifier {
  late final FaceManagementService _faceManagementService;
  late final CameraManager _cameraManager;
  Timer? _inactiveVisitsTimer;

  UIStateController() {
    _initializeServices();
  }

  void _initializeServices() {
    // Initialize face management service first
    _faceManagementService = FaceManagementService()
      ..onStateChanged = _onFaceManagementStateChanged;

    // Initialize camera manager with face management service
    _cameraManager = CameraManager(_faceManagementService)
      ..onStateChanged = _onCameraStateChanged
      // Connect face features detection to face management
      ..onFaceFeaturesDetected = (features, providerAddress, thumbnail) {
        _faceManagementService.processFace(
            features, providerAddress, thumbnail);
      };
  }

  void _onCameraStateChanged() {
    notifyListeners();
  }

  void _onFaceManagementStateChanged() {
    notifyListeners();
  }

  // Public accessors that delegate to the appropriate service
  Map<String, TrackedFace> get trackedFaces =>
      _faceManagementService.trackedFaces;
  List<Uint8List> get capturedFaces => _cameraManager.capturedFaces;
  Map<String, ICameraProvider> get activeProviders =>
      _cameraManager.activeProviders;
  bool get useIsolates => _cameraManager.useIsolates;

  // Start all necessary services and monitoring
  Future<void> start() async {
    await _cameraManager.startListening();
    startInactiveVisitsCleanup();
  }

  // Clean up resources
  Future<void> stop() async {
    await _cameraManager.stopListening();
    _inactiveVisitsTimer?.cancel();
  }

  // Get the last frame from a specific camera provider
  Uint8List? getLastFrame(String address) =>
      _cameraManager.getLastFrame(address);

  // Get current FPS for a provider
  int getProviderFps(String address) => _cameraManager.getProviderFps(address);

  // Face management operations delegating to FaceManagementService
  Future<void> updateTrackedFaceName(String faceId, String newName) =>
      _faceManagementService.updateTrackedFaceName(faceId, newName);

  Future<void> mergeFaces(String targetId, String sourceId) =>
      _faceManagementService.mergeFaces(targetId, sourceId);

  Future<bool> deleteTrackedFace(String faceId) =>
      _faceManagementService.deleteTrackedFace(faceId);

  Future<bool> splitMergedFace(
          String parentId, String mergedFaceId, int mergedFaceIndex) =>
      _faceManagementService.splitMergedFace(
          parentId, mergedFaceId, mergedFaceIndex);

  // Statistics and analytics operations
  Future<Map<String, dynamic>> getVisitStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? providerId,
    String? faceId,
  }) =>
      _faceManagementService.getVisitStatistics(
        startDate: startDate,
        endDate: endDate,
        providerId: providerId,
        faceId: faceId,
      );

  Future<List<Map<String, dynamic>>> getVisitsForFace(String faceId) =>
      _faceManagementService.getVisitsForFace(faceId);

  Future<List<FaceMatch>> findSimilarFaces(String faceId, {int limit = 5}) =>
      _faceManagementService.findSimilarFaces(faceId, limit: limit);

  Future<bool> areFacesLikelyTheSamePerson(String faceId1, String faceId2) =>
      _faceManagementService.areFacesLikelyTheSamePerson(faceId1, faceId2);

  Future<double> getFaceSimilarityScore(String faceId1, String faceId2) =>
      _faceManagementService.getFaceSimilarityScore(faceId1, faceId2);

  Future<List<Map<String, dynamic>>> getAvailableFaces() =>
      _faceManagementService.getAvailableFaces();

  // Settings operations delegating to CameraManager
  Future<void> updateSettings(int maxFaces) =>
      _cameraManager.updateSettings(maxFaces);

  Future<void> updateUseIsolates(bool value) =>
      _cameraManager.updateUseIsolates(value);

  // Maintenance operations
  void startInactiveVisitsCleanup() {
    _inactiveVisitsTimer?.cancel();
    _inactiveVisitsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _faceManagementService.cleanupInactiveVisits(5),
    );
  }

  @override
  void dispose() {
    _inactiveVisitsTimer?.cancel();
    _cameraManager.dispose();
    _faceManagementService.dispose();
    stop();
    super.dispose();
  }
}
