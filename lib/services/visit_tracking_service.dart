import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/database/faces_repository.dart';
import 'package:uuid/uuid.dart';

class ActiveVisit {
  final String visitId;
  final String faceId;
  final TrackedFace person;
  final DateTime entryTime;
  final String cameraId;
  DateTime lastSeenTime;

  // Calculate duration relative to now (live)
  Duration get duration => DateTime.now().difference(entryTime);

  // Check if this visit is active (seen in last 10 seconds)
  bool get isActive => DateTime.now().difference(lastSeenTime).inSeconds < 10;

  ActiveVisit({
    required this.visitId,
    required this.faceId,
    required this.person,
    required this.entryTime,
    required this.cameraId,
    required this.lastSeenTime,
  });
}

/// Service dedicated to tracking and managing visits with proper lifecycle management
class VisitTrackingService {
  final FacesRepository _repository;
  final Uuid _uuid = Uuid();

  // In-memory cache of active visits
  final Map<String, ActiveVisit> _activeVisits = {};

  // Stream controller for reactive updates
  final _visitStreamController =
      StreamController<List<ActiveVisit>>.broadcast();
  Stream<List<ActiveVisit>> get activeVisitsStream =>
      _visitStreamController.stream;

  // Timer for automatic cleanup
  Timer? _cleanupTimer;

  VisitTrackingService(this._repository) {
    _initService();
  }

  void _initService() {
    // Load existing active visits
    _loadActiveVisits();

    // Set up cleanup timer (every 2 seconds)
    _cleanupTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _cleanupInactiveVisits());
  }

  Future<void> _loadActiveVisits() async {
    try {
      // Load active visits from database
      final dbVisits = await _repository.getActiveVisits();

      // Clear current cache
      _activeVisits.clear();

      // Process each visit
      for (var visit in dbVisits) {
        if (visit.faceId == null) continue;

        // Get visit details
        final visitDetails = await _repository.getVisitDetails(visit.id);
        if (visitDetails == null) continue;

        // Get person details
        final person = await _repository.getTrackedFace(visit.faceId!);
        if (person == null) continue;

        // Create active visit object
        final activeVisit = ActiveVisit(
          visitId: visit.id,
          faceId: visit.faceId!,
          person: person,
          entryTime: visitDetails.entryTime,
          cameraId: visitDetails.providerId,
          lastSeenTime: visitDetails.exitTime ?? visitDetails.entryTime,
        );

        // Add to cache
        _activeVisits[visit.faceId!] = activeVisit;
      }

      // Notify listeners
      _notifyVisitChanges();
    } catch (e) {
      debugPrint('Error loading active visits: $e');
    }
  }

  /// Handle visit for a detected face
  /// Creates new visit or updates existing one
  Future<void> handleVisit(
      String faceId, String cameraId, TrackedFace person) async {
    try {
      final now = DateTime.now();

      if (_activeVisits.containsKey(faceId)) {
        // Existing visit - update last seen time
        final visit = _activeVisits[faceId]!;
        visit.lastSeenTime = now;

        // Update in database
        await _repository.updateVisitLastSeen(visit.visitId, now);
      } else {
        // Create new visit
        final visitId = "visit_${_uuid.v4()}";

        // Create in database
        await _repository.createVisit(
          id: visitId,
          faceId: faceId,
          providerId: cameraId,
          entryTime: now,
        );

        // Add to cache
        _activeVisits[faceId] = ActiveVisit(
          visitId: visitId,
          faceId: faceId,
          person: person,
          entryTime: now,
          cameraId: cameraId,
          lastSeenTime: now,
        );
      }

      // Notify changes
      _notifyVisitChanges();
    } catch (e) {
      debugPrint('Error handling visit for face $faceId: $e');
    }
  }

  /// Close visit for a face
  Future<void> closeVisit(String faceId) async {
    try {
      if (!_activeVisits.containsKey(faceId)) return;

      final visit = _activeVisits[faceId]!;
      final now = DateTime.now();

      // Update in database
      await _repository.updateVisitExit(
        visit.visitId,
        now,
      );

      // Remove from cache
      _activeVisits.remove(faceId);

      // Notify changes
      _notifyVisitChanges();
    } catch (e) {
      debugPrint('Error closing visit for face $faceId: $e');
    }
  }

  /// Close all active visits
  Future<void> closeAllVisits() async {
    try {
      final now = DateTime.now();
      final faceIds = _activeVisits.keys.toList();

      for (var faceId in faceIds) {
        await closeVisit(faceId);
      }
    } catch (e) {
      debugPrint('Error closing all visits: $e');
    }
  }

  /// Clean up inactive visits based on last seen time
  Future<void> _cleanupInactiveVisits() async {
    try {
      final now = DateTime.now();
      final faceIdsToClose = <String>[];

      // Find visits to close
      for (var entry in _activeVisits.entries) {
        final visit = entry.value;
        final inactiveTime = now.difference(visit.lastSeenTime).inSeconds;

        // Close if inactive for more than 5 seconds
        if (inactiveTime > 5) {
          faceIdsToClose.add(entry.key);
        }
      }

      // Close each inactive visit
      for (var faceId in faceIdsToClose) {
        await closeVisit(faceId);
      }
    } catch (e) {
      debugPrint('Error cleaning up inactive visits: $e');
    }
  }

  /// Get current active visits
  List<ActiveVisit> getActiveVisits() {
    // Return as sorted list (most recent first)
    final visits = _activeVisits.values.toList();
    visits.sort((a, b) => b.entryTime.compareTo(a.entryTime));
    return visits;
  }

  /// Notify listeners of visit changes
  void _notifyVisitChanges() {
    _visitStreamController.add(getActiveVisits());
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _visitStreamController.close();
  }
}
