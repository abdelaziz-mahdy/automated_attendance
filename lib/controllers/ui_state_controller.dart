import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/models/face_match.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/services/face_management_service.dart';
import 'package:automated_attendance/services/settings_service.dart';

/// The main provider that coordinates all UI state and service interactions
class UIStateController with ChangeNotifier {
  late final FaceManagementService _faceManagementService;
  late final CameraManager _cameraManager;
  late final SettingsService _settingsService;
  Timer? _inactiveVisitsTimer;

  // Callbacks
  Function(int)? onAnalyticsIntervalChanged;
  Function()? onAttendanceUpdated;

  // Expected attendance list
  final List<String> _expectedAttendees = [];
  bool _attendanceLoaded = false;

  UIStateController() {
    // Initialize face management service
    _faceManagementService = FaceManagementService()
      ..onStateChanged = _onFaceManagementStateChanged;

    // Initialize camera manager with face management service
    _cameraManager = CameraManager(_faceManagementService)
      ..onStateChanged = _onCameraStateChanged
      ..onFaceFeaturesDetected = (features, providerAddress, thumbnail) {
        _faceManagementService.processFace(
            features, providerAddress, thumbnail);
      };
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize settings service first
    _settingsService = SettingsService();
    await _settingsService.initialize();

    // Apply settings to camera manager
    await _cameraManager.updateSettings(_settingsService.maxFaces);
    await _cameraManager.updateUseIsolates(_settingsService.useIsolates);

    // Load expected attendees
    await _loadExpectedAttendees();
  }

  // Load expected attendees from storage
  Future<void> _loadExpectedAttendees() async {
    final expectedList = _settingsService.expectedAttendees;
    _expectedAttendees.clear();
    _expectedAttendees.addAll(expectedList);
    _attendanceLoaded = true;
  }

  // Save expected attendees to storage
  Future<void> _saveExpectedAttendees() async {
    await _settingsService.setExpectedAttendees(_expectedAttendees);
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

  // Settings getters
  bool get useIsolates => _settingsService.useIsolates;
  int get analyticsUpdateInterval => _settingsService.analyticsUpdateInterval;
  int get maxFaces => _settingsService.maxFaces;

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

  // Settings operations using SettingsService and updating components
  Future<void> updateSettings(int maxFaces) async {
    await _settingsService.setMaxFaces(maxFaces);
    await _cameraManager.updateSettings(maxFaces);
    notifyListeners();
  }

  Future<void> updateUseIsolates(bool value) async {
    await _settingsService.setUseIsolates(value);
    await _cameraManager.updateUseIsolates(value);
    notifyListeners();
  }

  // Update analytics interval
  Future<void> updateAnalyticsInterval(int interval) async {
    await _settingsService.setAnalyticsUpdateInterval(interval);

    // Call the callback if it exists
    if (onAnalyticsIntervalChanged != null) {
      onAnalyticsIntervalChanged!(interval);
    }

    notifyListeners();
  }

  // Maintenance operations
  void startInactiveVisitsCleanup() {
    _inactiveVisitsTimer?.cancel();
    _inactiveVisitsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _faceManagementService.cleanupInactiveVisits(5),
    );
  }

  // Attendance tracking methods

  // Get today's attendance data
  Future<Map<String, dynamic>> getTodayAttendance() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all available faces
    final availableFaces = await getAvailableFaces();

    // Get visit statistics for today
    final stats = await getVisitStatistics(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    // Process attendance data
    final presentFaces = <Map<String, dynamic>>[];
    final absentFaces = <Map<String, dynamic>>[];

    for (var face in availableFaces) {
      // Get detailed visit info for this face today
      final visits = await _faceManagementService.getVisitsForFace(face['id']);
      final todayVisits = visits.where((visit) {
        final entryTime = visit['entryTime'] as DateTime?;
        return entryTime != null &&
            entryTime.isAfter(startOfDay) &&
            entryTime.isBefore(endOfDay);
      }).toList();

      // Add arrival time to face data
      if (todayVisits.isNotEmpty) {
        // Sort by entry time to get earliest
        todayVisits.sort((a, b) {
          return (a['entryTime'] as DateTime)
              .compareTo(b['entryTime'] as DateTime);
        });
        face['arrivalTime'] = todayVisits.first['entryTime'];
        face['visits'] = todayVisits;
        presentFaces.add(face);
      } else if (_expectedAttendees.contains(face['id'])) {
        absentFaces.add(face);
      }
    }

    // Sort present faces by arrival time
    presentFaces.sort((a, b) =>
        (a['arrivalTime'] as DateTime).compareTo(b['arrivalTime'] as DateTime));

    return {
      'present': presentFaces,
      'absent': absentFaces,
      'expectedCount': _expectedAttendees.length,
      'presentCount': presentFaces.length,
      'attendance_rate': _expectedAttendees.isEmpty
          ? 0
          : (presentFaces.length / _expectedAttendees.length * 100)
              .toStringAsFixed(1),
    };
  }

  // Mark a person as expected for attendance
  Future<void> markPersonAsExpected(String faceId) async {
    if (!_expectedAttendees.contains(faceId)) {
      _expectedAttendees.add(faceId);
      await _saveExpectedAttendees();
      onAttendanceUpdated?.call();
      notifyListeners();
    }
  }

  // Remove a person from expected attendance
  Future<void> unmarkPersonAsExpected(String faceId) async {
    if (_expectedAttendees.contains(faceId)) {
      _expectedAttendees.remove(faceId);
      await _saveExpectedAttendees();
      onAttendanceUpdated?.call();
      notifyListeners();
    }
  }

  // Check if a person is expected for attendance
  bool isPersonExpected(String faceId) {
    return _expectedAttendees.contains(faceId);
  }

  // Get list of expected attendees
  List<String> get expectedAttendees => List.from(_expectedAttendees);

  @override
  void dispose() {
    _inactiveVisitsTimer?.cancel();
    _cameraManager.dispose();
    _faceManagementService.dispose();
    stop();
    super.dispose();
  }
}
