import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/models/face_match.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager_service.dart';
import 'package:automated_attendance/services/face_management_service.dart';

/// Controller that coordinates between the services and UI
/// Acts as a facade to simplify UI interactions with the underlying services
class UIStateController extends ChangeNotifier {
  final FaceManagementService _faceManagementService;
  final CameraManagerService _cameraManagerService;
  Timer? _inactiveVisitsTimer;

  UIStateController(this._faceManagementService, this._cameraManagerService);

  // Public access to tracked faces and captured faces for UI components
  Map<String, TrackedFace> get trackedFaces =>
      _faceManagementService.trackedFaces;
  List<Uint8List> get capturedFaces => _cameraManagerService.capturedFaces;
  Map<String, ICameraProvider> get activeProviders =>
      _cameraManagerService.activeProviders;
  Stream<List<double>> get faceFeaturesStream =>
      _cameraManagerService.faceFeaturesStream;
  bool get useIsolates => _cameraManagerService.useIsolates;

  // Start all necessary services and monitoring
  void start() {
    _cameraManagerService.startListening();
    startInactiveVisitsCleanup();
  }

  // Clean up resources
  void stop() {
    _cameraManagerService.stopListening();
    _inactiveVisitsTimer?.cancel();
  }

  // Get the last frame from a specific camera provider
  Uint8List? getLastFrame(String address) =>
      _cameraManagerService.getLastFrame(address);

  // Get current FPS for a provider
  int getProviderFps(String address) =>
      _cameraManagerService.getProviderFps(address);

  // Update face name
  Future<void> updateTrackedFaceName(String faceId, String newName) async {
    await _faceManagementService.updateTrackedFaceName(faceId, newName);
  }

  // Merge faces
  Future<void> mergeFaces(String targetId, String sourceId) async {
    await _faceManagementService.mergeFaces(targetId, sourceId);
  }

  // Delete a tracked face
  Future<bool> deleteTrackedFace(String faceId) async {
    return await _faceManagementService.deleteTrackedFace(faceId);
  }

  // Split a merged face
  Future<bool> splitMergedFace(
      String parentId, String mergedFaceId, int mergedFaceIndex) async {
    return await _faceManagementService.splitMergedFace(
        parentId, mergedFaceId, mergedFaceIndex);
  }

  // Get visit statistics
  Future<Map<String, dynamic>> getVisitStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? providerId,
    String? faceId,
  }) async {
    return await _faceManagementService.getVisitStatistics(
      startDate: startDate,
      endDate: endDate,
      providerId: providerId,
      faceId: faceId,
    );
  }

  // Get visits for a specific face
  Future<List<Map<String, dynamic>>> getVisitsForFace(String faceId) async {
    return await _faceManagementService.getVisitsForFace(faceId);
  }

  // Find similar faces
  Future<List<FaceMatch>> findSimilarFaces(String faceId,
      {int limit = 5}) async {
    return await _faceManagementService.findSimilarFaces(faceId, limit: limit);
  }

  // Check if two faces are likely the same person
  Future<bool> areFacesLikelyTheSamePerson(
      String faceId1, String faceId2) async {
    return await _faceManagementService.areFacesLikelyTheSamePerson(
        faceId1, faceId2);
  }

  // Get similarity score between two faces
  Future<double> getFaceSimilarityScore(String faceId1, String faceId2) async {
    return await _faceManagementService.getFaceSimilarityScore(
        faceId1, faceId2);
  }

  // Get all available faces for filtering
  Future<List<Map<String, dynamic>>> getAvailableFaces() async {
    return await _faceManagementService.getAvailableFaces();
  }

  // Update settings
  Future<void> updateSettings(int maxFaces) async {
    await _cameraManagerService.updateSettings(maxFaces);
  }

  // Update isolate usage setting
  Future<void> updateUseIsolates(bool value) async {
    await _cameraManagerService.updateUseIsolates(value);
  }

  // Start periodic cleanup of inactive visits
  void startInactiveVisitsCleanup() {
    _inactiveVisitsTimer?.cancel();
    _inactiveVisitsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _faceManagementService
          .cleanupInactiveVisits(5), // Check for visits inactive for 5 minutes
    );
  }

  @override
  void dispose() {
    _inactiveVisitsTimer?.cancel();
    stop();
    super.dispose();
  }
}
