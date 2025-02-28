import 'dart:async';
import 'dart:convert';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/database/faces_repository.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/models/face_match.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/isolate/frame_processor.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class CameraManager extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final FaceComparisonService _faceComparisonService = FaceComparisonService();
  final Map<String, ICameraProvider> activeProviders = {};
  final Map<String, Uint8List> _lastFrames = {};
  final Map<String, Timer> _pollTimers = {};
  final Map<String, int> _providerFps = {};
  final StreamController<List<double>> _faceFeaturesStreamController =
      StreamController.broadcast();
  final List<Uint8List> capturedFaces = [];
  final Map<String, TrackedFace> trackedFaces = {};
  final Uuid _uuid = Uuid();

  // Track active visits (faceId -> visitId)
  final Map<String, String> _activeVisits = {};

  // Database repository
  final FacesRepository _facesRepository = FacesRepository();

  bool _isListening = false;
  late SharedPreferences _prefs;
  final int _fps = 10;
  late int _maxFaces;
  bool _useIsolates = true;
  bool get useIsolates => _useIsolates;
  bool _dataLoaded = false;

  // Pending database operations tracking for batching
  final Set<String> _pendingFaceRefreshes = {};
  bool _batchOperationsScheduled = false;

  Stream<List<double>> get faceFeaturesStream =>
      _faceFeaturesStreamController.stream;

  CameraManager() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _maxFaces = _prefs.getInt('maxFaces') ?? 10; // Default max faces

    // Load tracked faces from database
    await _refreshAllFacesFromDatabase();

    // Load and process active visits
    await _loadActiveVisitsFromDatabase();

    notifyListeners();
  }

  // Load tracked faces from the database - this is now our core refresh method
  Future<void> _refreshAllFacesFromDatabase() async {
    try {
      final loadedFaces = await _facesRepository.loadAllTrackedFaces();
      // Clear and reload all faces
      trackedFaces.clear();
      trackedFaces.addAll(loadedFaces);
      _dataLoaded = true;
      notifyListeners(); // Notify after complete refresh
    } catch (e) {
      debugPrint('Error loading tracked faces from database: $e');
    }
  }

  // Refresh a specific face from the database
  Future<void> _refreshFaceFromDatabase(String faceId) async {
    try {
      final face = await _facesRepository.getTrackedFace(faceId);
      if (face != null) {
        trackedFaces[faceId] = face;
      } else {
        // Face was deleted from database, remove from memory too
        trackedFaces.remove(faceId);
      }
      notifyListeners(); // Always notify after updating a face
    } catch (e) {
      debugPrint('Error refreshing face $faceId from database: $e');
    }
  }

  // Schedule refresh of faces with batching for efficiency
  void _scheduleFaceRefresh(String faceId) {
    _pendingFaceRefreshes.add(faceId);

    if (!_batchOperationsScheduled) {
      _batchOperationsScheduled = true;
      // Use microtask to batch updates in one frame
      Future.microtask(() {
        _processPendingRefreshes();
      });
    }
  }

  // Process all pending face refreshes
  Future<void> _processPendingRefreshes() async {
    if (_pendingFaceRefreshes.isEmpty) {
      _batchOperationsScheduled = false;
      return;
    }

    // If too many faces need refresh, just refresh all
    if (_pendingFaceRefreshes.length > 10) {
      await _refreshAllFacesFromDatabase();
    } else {
      // Otherwise, refresh just the faces that changed
      for (final faceId in _pendingFaceRefreshes) {
        await _refreshFaceFromDatabase(faceId);
      }
    }

    _pendingFaceRefreshes.clear();
    _batchOperationsScheduled = false;
    // No need for notifyListeners here as _refreshFaceFromDatabase already does it
  }

  // Load active visits from the database and update tracking
  Future<void> _loadActiveVisitsFromDatabase() async {
    try {
      final activeVisits = await _facesRepository.getActiveVisits();
      _activeVisits.clear();
      for (var visit in activeVisits) {
        if (visit.faceId != null) {
          _activeVisits[visit.faceId!] = visit.id;
        }
      }
    } catch (e) {
      debugPrint('Error loading active visits from database: $e');
    }
  }

  // Update settings and restart frame polling
  Future<void> updateSettings(int maxFaces) async {
    await _prefs.setInt('maxFaces', maxFaces);
    _maxFaces = maxFaces;
    // Reset dynamic FPS for each provider.
    for (var address in activeProviders.keys) {
      _providerFps[address] = _fps;
    }
    _restartFramePolling();
    notifyListeners();
  }

  // Update the flag (e.g., from a settings dialog)
  Future<void> updateUseIsolates(bool value) async {
    if (_useIsolates == value) return;
    _useIsolates = value;
    notifyListeners();
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    // Make sure tracked faces are loaded
    if (!_dataLoaded) {
      await _refreshAllFacesFromDatabase();
    }

    await _discoveryService.startDiscovery(serviceType: '_camera._tcp');
    _discoveryService.discoveryStream.listen(_onServiceDiscovered);
    _discoveryService.removeStream.listen(_onServiceRemoved);
  }

  Future<void> stopListening() async {
    _isListening = false;
    // Cancel all provider timers
    for (var timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    // Close all active providers
    for (var provider in activeProviders.values) {
      await provider.closeCamera();
    }
    await _discoveryService.stopDiscovery();

    // Close all active visits when shutting down
    await _closeAllActiveVisits();

    activeProviders.clear();
    _lastFrames.clear();
  }

  // Close all active visits in the database
  Future<void> _closeAllActiveVisits() async {
    try {
      final now = DateTime.now();
      for (var entry in _activeVisits.entries) {
        await _facesRepository.updateVisitExit(entry.value, now);
      }
      _activeVisits.clear();
    } catch (e) {
      debugPrint('Error closing active visits: $e');
    }
  }

  Future<void> _onServiceDiscovered(ServiceInfo serviceInfo) async {
    final address = serviceInfo.address;
    final port = serviceInfo.port;

    if (address == null || port == null) return;
    if (activeProviders.containsKey(address)) return;

    final provider = RemoteCameraProvider(
      serverAddress: address,
      serverPort: port,
    );

    final opened = await provider.openCamera();
    if (!opened) return;

    activeProviders[address] = provider;
    // NEW: Save initial FPS and schedule dynamic polling.
    _providerFps[address] = _fps;
    _scheduleNextPolling(provider, address);
    notifyListeners();
  }

  // Schedule the next polling for a provider based on its dynamic FPS.
  void _scheduleNextPolling(ICameraProvider provider, String address) {
    if (!_isListening || !activeProviders.containsKey(address)) return;
    final currentFps = _providerFps[address] ?? _fps;
    final intervalMs = (1000 / currentFps).round();
    _pollTimers[address]?.cancel();
    _pollTimers[address] = Timer(Duration(milliseconds: intervalMs), () async {
      await _pollFramesOnceDynamic(provider, address);
    });
  }

  // Poll a single frame, adjust dynamic FPS and reschedule polling.
  Future<void> _pollFramesOnceDynamic(
      ICameraProvider provider, String address) async {
    final frameStartTime = DateTime.now();
    try {
      final frame = await provider.getFrame();
      if (frame != null && frame.isNotEmpty) {
        final IFrameProcessor processor = _useIsolates
            ? IsolateFrameProcessor()
            : MainIsolateFrameProcessor();
        final result = await processor.processFrame(frame);
        if (result != null) {
          _lastFrames[address] = result['processedFrame'] as Uint8List;
          final List<dynamic> features = result['faceFeatures'];
          final List<dynamic> thumbnails = result['faceThumbnails'];
          for (int i = 0; i < features.length; i++) {
            _faceFeaturesStreamController.add(features[i] as List<double>);
            _compareWithTrackedFaces(
              features[i] as List<double>,
              address,
              thumbnails[i] as Uint8List?,
            );
            if (thumbnails[i] != null) {
              capturedFaces.insert(0, thumbnails[i] as Uint8List);
              if (capturedFaces.length > _maxFaces) {
                capturedFaces.removeLast();
              }
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error polling frames for $address: $e");
    }
    // Calculate frame processing time and adjust dynamic FPS.
    final processingTime =
        DateTime.now().difference(frameStartTime).inMilliseconds;
    int currentFps = _providerFps[address] ?? _fps;
    final expectedInterval = (1000 / currentFps).round();
    if (processingTime > expectedInterval) {
      currentFps = currentFps > 5 ? currentFps - 1 : 5;
    } else if (processingTime < expectedInterval) {
      currentFps = currentFps < _fps ? currentFps + 1 : _fps;
    }
    _providerFps[address] = currentFps;
    _scheduleNextPolling(provider, address);
  }

  // Restart dynamic frame polling with updated FPS values.
  void _restartFramePolling() {
    for (final address in activeProviders.keys) {
      _pollTimers[address]?.cancel();
      _providerFps[address] = _fps; // Reset dynamic FPS to max.
      final provider = activeProviders[address];
      if (provider != null) {
        _scheduleNextPolling(provider, address);
      }
    }
  }

  Future<void> _onServiceRemoved(ServiceInfo serviceInfo) async {
    final address = serviceInfo.address;
    if (address == null) return;
    // Cancel the timer for this provider
    _pollTimers[address]?.cancel();
    _pollTimers.remove(address);

    final provider = activeProviders.remove(address);
    if (provider != null) {
      await provider.closeCamera();
    }

    _lastFrames.remove(address);
    notifyListeners();
  }

  /// Compares extracted face features with tracked faces.
  Future<void> _compareWithTrackedFaces(List<double> features,
      String providerAddress, Uint8List? faceThumbnail) async {
    bool isKnownFace = false;
    String? matchedFaceId;
    final now = DateTime.now();

    // Step 1: Match against existing faces in memory
    for (final entry in trackedFaces.entries) {
      final trackedFace = entry.value;
      final trackedFeatures = trackedFace.features;

      bool isSimilar = _faceComparisonService.areFeaturesSimilar(
        features,
        trackedFeatures,
      );

      // Check merged faces if not similar
      if (!isSimilar && trackedFace.mergedFaces.isNotEmpty) {
        for (final mergedFace in trackedFace.mergedFaces) {
          final mergedFeatures = mergedFace.features;
          if (_faceComparisonService.areFeaturesSimilar(
            features,
            mergedFeatures,
          )) {
            isSimilar = true;
            break;
          }
        }
      }

      // Update last seen time and provider if similar
      if (isSimilar) {
        isKnownFace = true;
        matchedFaceId = trackedFace.id;

        try {
          // Update database first (source of truth)
          await _facesRepository.updateFaceLastSeen(
              trackedFace.id, now, providerAddress);

          // Then refresh from database to ensure consistency
          await _refreshFaceFromDatabase(trackedFace.id);

          // Handle visit tracking
          await _handleFaceVisit(trackedFace.id, providerAddress, now);
        } catch (e) {
          debugPrint('Error updating recognized face: $e');
        }

        break;
      }
    }

    // Step 2: If not recognized, create a new face record
    if (!isKnownFace) {
      try {
        // Generate a truly unique ID using UUID
        final newFaceId = "face_${_uuid.v4()}";

        // Create the new face object
        final newTrackedFace = TrackedFace(
          id: newFaceId,
          features: features,
          name: newFaceId, // Default name is the ID
          firstSeen: now,
          lastSeen: now,
          lastSeenProvider: providerAddress,
          thumbnail: faceThumbnail, // Store thumbnail directly
        );

        // Save to database first (source of truth)
        await _facesRepository.saveTrackedFace(newTrackedFace);

        // Create a new visit record
        await _handleFaceVisit(newFaceId, providerAddress, now);

        // Refresh from database to ensure consistency
        await _refreshFaceFromDatabase(newFaceId);
      } catch (e) {
        debugPrint('Error creating new tracked face: $e');
      }
    }

    // Notify listeners after all operations are complete
    notifyListeners();
  }

  // Handle visit tracking for a face
  Future<void> _handleFaceVisit(
      String faceId, String providerAddress, DateTime timestamp) async {
    try {
      // If there's no active visit for this face, create one
      if (!_activeVisits.containsKey(faceId)) {
        // Create a new visit
        final visitId = "visit_${_uuid.v4()}";
        await _facesRepository.createVisit(
            id: visitId,
            faceId: faceId,
            providerId: providerAddress,
            entryTime: timestamp);
        _activeVisits[faceId] = visitId;
      } else {
        // Otherwise update the last seen time of the existing visit
        await _facesRepository.updateVisitLastSeen(
            _activeVisits[faceId]!, timestamp);
      }
    } catch (e) {
      debugPrint('Error handling visit for face $faceId: $e');
    }
  }

  // Close a visit for a specific face
  Future<void> _closeVisit(String faceId, DateTime exitTime) async {
    final visitId = _activeVisits[faceId];
    if (visitId != null) {
      await _facesRepository.updateVisitExit(visitId, exitTime);
      _activeVisits.remove(faceId);
    }
  }

  // Close visits for faces not seen in the last timeoutMinutes minutes
  Future<void> cleanupInactiveVisits(int timeoutMinutes) async {
    final now = DateTime.now();
    final List<String> facesToClose = [];

    for (var entry in trackedFaces.entries) {
      final face = entry.value;
      if (face.lastSeen != null &&
          _activeVisits.containsKey(face.id) &&
          now.difference(face.lastSeen!).inMinutes > timeoutMinutes) {
        facesToClose.add(face.id);
      }
    }

    for (var faceId in facesToClose) {
      await _closeVisit(faceId, now);
    }

    if (facesToClose.isNotEmpty) {
      notifyListeners();
    }
  }

  Uint8List? getLastFrame(String address) => _lastFrames[address];

  // Getter to retrieve the current FPS for a provider.
  int getProviderFps(String address) => _providerFps[address] ?? _fps;

  // Update face name - updated to use DB as source of truth
  Future<void> updateTrackedFaceName(String faceId, String newName) async {
    if (!trackedFaces.containsKey(faceId)) return;

    try {
      // Update database first
      await _facesRepository.updateFaceName(faceId, newName);

      // Then refresh from database
      await _refreshFaceFromDatabase(faceId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating face name: $e');
    }
  }

  // Merge faces - updated to handle faces that already have merged faces
  Future<void> mergeFaces(String targetId, String sourceId) async {
    if (!trackedFaces.containsKey(targetId) ||
        !trackedFaces.containsKey(sourceId)) {
      return;
    }

    try {
      // Get both faces to check if they have merged faces
      final targetFace = trackedFaces[targetId]!;
      final sourceFace = trackedFaces[sourceId]!;

      // Log the merge operation for debugging
      debugPrint('Merging face $sourceId into $targetId');
      debugPrint(
          'Target face has ${targetFace.mergedFaces.length} merged faces');
      debugPrint(
          'Source face has ${sourceFace.mergedFaces.length} merged faces');

      // First close any active visit for the source face
      if (_activeVisits.containsKey(sourceId)) {
        await _closeVisit(sourceId, DateTime.now());
      }

      // Update database first in a transaction
      // The repository should handle transferring all nested merged faces
      await _facesRepository.mergeFaces(targetId, sourceId);

      // Clear the source face from memory immediately to avoid UI confusion
      trackedFaces.remove(sourceId);

      // Then refresh the target face from database to ensure it has all updates
      // This will include all merged faces from both the source and target
      await _refreshFaceFromDatabase(targetId);

      // No need for notifyListeners here as _refreshFaceFromDatabase already does it
    } catch (e) {
      debugPrint('Error merging faces: $e');
      // If there was an error, do a full refresh to ensure consistent state
      await _refreshAllFacesFromDatabase();
    }
  }

  // Delete a tracked face - updated to use DB as source of truth
  Future<bool> deleteTrackedFace(String faceId) async {
    if (!trackedFaces.containsKey(faceId)) {
      return false;
    }

    try {
      // First close any active visit to maintain data consistency
      if (_activeVisits.containsKey(faceId)) {
        await _closeVisit(faceId, DateTime.now());
      }

      // Perform all database operations
      await _facesRepository.deleteFace(faceId);
      await _facesRepository.deleteVisitsForFace(faceId);

      // Remove from memory after successful database operations
      trackedFaces.remove(faceId);

      // Important: Notify here as we're not calling _refreshFaceFromDatabase
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error deleting tracked face $faceId: $e');
      // If there was an error, do a full refresh to ensure consistent state
      await _refreshAllFacesFromDatabase();
      return false;
    }
  }

  /// Split a merged face - updated to use DB as source of truth
  Future<bool> splitMergedFace(
      String parentId, String mergedFaceId, int mergedFaceIndex) async {
    // Validate input parameters
    if (!trackedFaces.containsKey(parentId) ||
        mergedFaceIndex >= trackedFaces[parentId]!.mergedFaces.length) {
      return false;
    }

    final parentFace = trackedFaces[parentId]!;

    // Safety check to ensure index is valid
    if (mergedFaceIndex < 0 ||
        mergedFaceIndex >= parentFace.mergedFaces.length) {
      return false;
    }

    final mergedFace = parentFace.mergedFaces[mergedFaceIndex];

    try {
      // Database operations first
      await _facesRepository.restoreMergedFace(parentId, mergedFace);

      // Important: Don't update memory directly, instead refresh from database
      // Refresh both affected faces
      await _refreshFaceFromDatabase(parentId);
      await _refreshFaceFromDatabase(mergedFace.id);

      // No need for notifyListeners here as _refreshFaceFromDatabase already does it
      return true;
    } catch (e) {
      debugPrint('Error splitting merged face: $e');
      // If there was an error, do a full refresh to ensure consistent state
      await _refreshAllFacesFromDatabase();
      return false;
    }
  }

  // Get visit statistics for analytics
  Future<Map<String, dynamic>> getVisitStatistics(
      {DateTime? startDate,
      DateTime? endDate,
      String? providerId,
      String? faceId}) async {
    return await _facesRepository.getVisitStatistics(
        startDate: startDate,
        endDate: endDate,
        providerId: providerId,
        faceId: faceId);
  }

  // Get all visits for a face
  Future<List<Map<String, dynamic>>> getVisitsForFace(String faceId) async {
    return await _facesRepository.getVisitDetailsForFace(faceId);
  }

  // Timer to periodically check and close inactive visits
  Timer? _inactiveVisitsTimer;

  void startInactiveVisitsCleanup() {
    // Check every minute for inactive visits (faces not seen for 5 minutes)
    _inactiveVisitsTimer?.cancel();
    _inactiveVisitsTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => cleanupInactiveVisits(5));
  }

  @override
  void dispose() {
    _faceFeaturesStreamController.close();
    _inactiveVisitsTimer?.cancel();
    stopListening();
    super.dispose();
  }

  /// Ensures that face data is loaded before proceeding
  Future<void> ensureDataLoaded() async {
    if (!_dataLoaded) {
      debugPrint('Face data not loaded yet, loading now...');
      await _refreshAllFacesFromDatabase();
    }
  }

  /// Find faces similar to the given face, sorted by similarity score (highest first)
  Future<List<FaceMatch>> findSimilarFaces(String faceId,
      {int limit = 5}) async {
    debugPrint(
        'Finding similar faces for $faceId with limit $limit with tracked faces: ${trackedFaces.length}');

    // Ensure data is loaded before proceeding
    await ensureDataLoaded();

    if (!trackedFaces.containsKey(faceId)) {
      return [];
    }

    final targetFace = trackedFaces[faceId]!;
    final List<FaceMatch> matches = [];

    for (final entry in trackedFaces.entries) {
      // Skip comparing to self
      if (entry.key == faceId) continue;

      final candidateFace = entry.value;
      double highestSimilarityScore = 0;
      double bestCosineDistance = 0;
      double bestNormL2Distance = 0;

      // Calculate similarity with main candidate face
      final (cosineDistance, normL2Distance) =
          _faceComparisonService.getConfidence(
        targetFace.features,
        candidateFace.features,
      );

      // Convert cosine similarity to percentage
      double similarityScore = cosineDistance * 100;

      // Initialize with main face scores
      highestSimilarityScore = similarityScore;
      bestCosineDistance = cosineDistance;
      bestNormL2Distance = normL2Distance;

      // Also check merged faces for the candidate
      for (var mergedFace in candidateFace.mergedFaces) {
        final (mergedCosine, mergedNormL2) =
            _faceComparisonService.getConfidence(
          targetFace.features,
          mergedFace.features,
        );

        double mergedSimilarityScore = mergedCosine * 100;

        // Update if this merged face has higher similarity
        if (mergedSimilarityScore > highestSimilarityScore) {
          highestSimilarityScore = mergedSimilarityScore;
          bestCosineDistance = mergedCosine;
          bestNormL2Distance = mergedNormL2;
        }
      }

      // Add the candidate once with the highest score found
      matches.add(FaceMatch(
        id: candidateFace.id,
        face: candidateFace,
        similarityScore: highestSimilarityScore,
        cosineDistance: bestCosineDistance,
        normL2Distance: bestNormL2Distance,
      ));
    }

    // Sort by similarity score (highest first)
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    // Return top matches up to the limit
    return matches.take(limit).toList();
  }

  // Checks if two faces are likely to be the same person
  Future<bool> areFacesLikelyTheSamePerson(
      String faceId1, String faceId2) async {
    // Ensure data is loaded before proceeding
    await ensureDataLoaded();

    if (!trackedFaces.containsKey(faceId1) ||
        !trackedFaces.containsKey(faceId2)) {
      return false;
    }

    final face1 = trackedFaces[faceId1]!;
    final face2 = trackedFaces[faceId2]!;

    return _faceComparisonService.areFeaturesSimilar(
        face1.features, face2.features);
  }

  // Get similarity score between two faces as a percentage
  Future<double> getFaceSimilarityScore(String faceId1, String faceId2) async {
    // Ensure data is loaded before proceeding
    await ensureDataLoaded();

    if (!trackedFaces.containsKey(faceId1) ||
        !trackedFaces.containsKey(faceId2)) {
      return 0.0;
    }

    final face1 = trackedFaces[faceId1]!;
    final face2 = trackedFaces[faceId2]!;

    final (cosineDistance, _) = _faceComparisonService.getConfidence(
      face1.features,
      face2.features,
    );

    // Convert to percentage
    return cosineDistance * 100;
  }

  /// Returns a list of all available faces for filtering
  Future<List<Map<String, dynamic>>> getAvailableFaces() async {
    // Ensure data is loaded before proceeding
    await ensureDataLoaded();

    final List<Map<String, dynamic>> facesList = [];

    for (final face in trackedFaces.values) {
      // Add face data to the list
      facesList.add({
        'id': face.id,
        'name': face.name,
        'thumbnail': face.thumbnail,
        'lastSeen': face.lastSeen?.toIso8601String(),
        'firstSeen': face.firstSeen?.toIso8601String(),
        'lastSeenProvider': face.lastSeenProvider,
        'visitCount': await _facesRepository.getVisitCountForFace(face.id),
      });
    }

    // Sort by name for easier discovery
    facesList
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return facesList;
  }
}
