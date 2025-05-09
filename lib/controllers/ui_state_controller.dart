import 'dart:async';

import 'package:automated_attendance/database/faces_repository.dart';
import 'package:automated_attendance/isolate/frame_processor.dart';
import 'package:automated_attendance/models/captured_face.dart';
import 'package:automated_attendance/services/visit_tracking_service.dart';
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
  late final VisitTrackingService _visitTrackingService;
  Timer? _inactiveVisitsTimer;

  // Callbacks
  Function(int)? onAnalyticsIntervalChanged;
  Function()? onAttendanceUpdated;

  // Expected attendance list (cached from database)
  final List<String> _expectedAttendees = [];
  bool _attendanceLoaded = false;

  UIStateController() {
    // Initialize face management service
    _faceManagementService = FaceManagementService()
      ..onStateChanged = _onFaceManagementStateChanged;

    // Initialize visit tracking service
    _visitTrackingService = VisitTrackingService(FacesRepository());

    // Initialize camera manager with face management service
    _cameraManager = CameraManager(_faceManagementService)
      ..onStateChanged = _onCameraStateChanged
      ..onFaceFeaturesDetected = (features, providerAddress, thumbnail) async {
        // Process face and return recognition results
        final faceResult = await _faceManagementService.processFace(
            features, providerAddress, thumbnail);

        // If face recognized, update visit tracking
        if (faceResult != null && faceResult['faceId'] != null) {
          final faceId = faceResult['faceId'] as String;
          final person = _faceManagementService.trackedFaces[faceId];

          if (person != null) {
            // Handle visit in dedicated service
            await _visitTrackingService.handleVisit(
                faceId, providerAddress, person);
          }
        }

        // Return the recognition results so CameraManager can create CapturedFace
        return faceResult;
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

  // Load expected attendees from database
  Future<void> _loadExpectedAttendees() async {
    final expectedList = await _faceManagementService.getExpectedAttendees();
    _expectedAttendees.clear();
    _expectedAttendees.addAll(expectedList);
    _attendanceLoaded = true;
  }

  // Save expected attendees using database
  Future<void> _saveExpectedAttendees() async {
    // No need to save all attendees at once - the database handles individual additions/removals
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
  List<CapturedFace> get capturedFaces => _cameraManager.capturedFaces;
  Map<String, ICameraProvider> get activeProviders =>
      _cameraManager.activeProviders;

  // Settings getters
  bool get useIsolates => _settingsService.useIsolates;
  int get analyticsUpdateInterval => _settingsService.analyticsUpdateInterval;
  int get maxFaces => _settingsService.maxFaces;

  // Start all necessary services and monitoring
  Future<void> start() async {
    await _cameraManager.startListening();
    // No need for separate inactive visits timer as visit service handles it
  }

  // Clean up resources
  Future<void> stop() async {
    await _cameraManager.stopListening();
    await _visitTrackingService.closeAllVisits();
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
      const Duration(seconds: 1), // Check every second instead of every minute
      (_) => _faceManagementService.cleanupInactiveVisits(5,
          useSeconds: true), // Use seconds instead of minutes
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
    
    // Create a set of all valid face IDs (both main and merged faces)
    final Set<String> allValidFaceIds = {};
    
    // Add main face IDs
    for (var face in availableFaces) {
      allValidFaceIds.add(face['id'] as String);
    }
    
    // Add merged face IDs
    for (var trackedFace in trackedFaces.values) {
      for (var mergedFace in trackedFace.mergedFaces) {
        allValidFaceIds.add(mergedFace.id);
      }
    }
    
    // Filter expected attendees to only include those that exist in our database
    final Set<String> validExpectedFaceIds = _expectedAttendees
        .where((faceId) => allValidFaceIds.contains(faceId))
        .toSet();
    
    // Get visit statistics for today
    final stats = await getVisitStatistics(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    // Process attendance data
    final presentFaces = <Map<String, dynamic>>[];
    final absentFaces = <Map<String, dynamic>>[];

    // Track unique faces for attendance calculation - only use valid expected attendees
    final uniquePresentExpectedFaceIds = <String>{};

    for (var face in availableFaces) {
      final faceId = face['id'] as String;
      
      // Get detailed visit info for this face today
      final visits = await _faceManagementService.getVisitsForFace(faceId);
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

        // Track if this present face was an expected face
        if (validExpectedFaceIds.contains(faceId)) {
          uniquePresentExpectedFaceIds.add(faceId);
        }
      } else if (validExpectedFaceIds.contains(faceId)) {
        // Only add to absent faces if it's a valid expected attendee
        absentFaces.add(face);
      }
    }

    // Sort present faces by arrival time
    presentFaces.sort((a, b) =>
        (a['arrivalTime'] as DateTime).compareTo(b['arrivalTime'] as DateTime));

    // Calculate attendance based on unique faces - using only valid expected attendees
    final uniqueExpectedCount = validExpectedFaceIds.length;
    final uniquePresentCount = uniquePresentExpectedFaceIds.length;
    final attendanceRate = uniqueExpectedCount > 0
        ? (uniquePresentCount / uniqueExpectedCount * 100).toStringAsFixed(1)
        : '0';

    return {
      'present': presentFaces,
      'absent': absentFaces,
      'expectedCount': uniqueExpectedCount,
      'presentCount': uniquePresentCount,
      'attendance_rate': attendanceRate,
    };
  }

  // Mark a person as expected for attendance
  Future<void> markPersonAsExpected(String faceId) async {
    if (!_expectedAttendees.contains(faceId)) {
      await _faceManagementService.addExpectedAttendee(faceId);
      _expectedAttendees.add(faceId);
      onAttendanceUpdated?.call();
      notifyListeners();
    }
  }

  // Remove a person from expected attendance
  Future<void> unmarkPersonAsExpected(String faceId) async {
    if (_expectedAttendees.contains(faceId)) {
      await _faceManagementService.removeExpectedAttendee(faceId);
      _expectedAttendees.remove(faceId);
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

  /// Import a face image and register it with a person name
  Future<bool> importFaceImage({
    required Uint8List imageBytes,
    required String personName,
    String? filePath,
  }) async {
    try {
      // Decode the image
      final IFrameProcessor processor =
          useIsolates ? IsolateFrameProcessor() : MainIsolateFrameProcessor();

      // Process the image to detect faces
      final result = await processor.processFrame(imageBytes);
      if (result == null) {
        debugPrint('Failed to process image: ${filePath ?? "unknown"}');
        return false;
      }

      // Check if any faces were detected
      final List<dynamic> features = result['faceFeatures'];
      final List<dynamic> thumbnails = result['faceThumbnails'];

      if (features.isEmpty) {
        debugPrint('No faces detected in image: ${filePath ?? "unknown"}');
        return false;
      }

      // Use the first detected face
      await _faceManagementService.importFace(
        features: features[0] as List<double>,
        personName: personName,
        faceThumbnail: thumbnails[0] as Uint8List?,
      );

      // Notify listeners to update UI
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error importing face image: $e');
      return false;
    }
  }

  /// Refresh tracked faces from the database
  Future<void> refreshTrackedFaces() async {
    try {
      await _faceManagementService.ensureDataLoaded();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing tracked faces: $e');
    }
  }

  // Update the name of a captured face
  void updateCapturedFaceName(String faceId, String name) {
    for (var face in _cameraManager.capturedFaces) {
      if (face.faceId == faceId) {
        face.name = name;
      }
    }
    notifyListeners();
  }

  // Expose the visit stream to widgets
  Stream<List<ActiveVisit>> get activeVisitsStream =>
      _visitTrackingService.activeVisitsStream;

  @override
  void dispose() {
    _inactiveVisitsTimer?.cancel();
    _cameraManager.dispose();
    _faceManagementService.dispose();
    _visitTrackingService.dispose();
    stop();
    super.dispose();
  }
}
