import 'dart:convert';

import 'package:automated_attendance/database/database.dart';
import 'package:automated_attendance/database/database_provider.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Repository to handle tracked faces persistence using Drift database
class FacesRepository {
  final IDatabaseProvider _databaseProvider;
  final Uuid _uuid = Uuid();

  /// Constructor that allows dependency injection of database provider
  FacesRepository({IDatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? DatabaseProvider();

  /// Loads all tracked faces from the database
  Future<Map<String, TrackedFace>> loadAllTrackedFaces() async {
    final database = await _databaseProvider.database;
    final trackedFacesMap = <String, TrackedFace>{};

    // Load all tracked faces
    final dbFaces = await database.getAllTrackedFaces();
    for (final dbFace in dbFaces) {
      // Convert blob to List<double> features
      final List<double> features = _blobToFeatures(dbFace.features);

      // Create the tracked face model
      final trackedFace = TrackedFace(
        id: dbFace.id,
        features: features,
        name: dbFace.name ?? dbFace.id,
        firstSeen: dbFace.firstSeen,
        lastSeen: dbFace.lastSeen,
        lastSeenProvider: dbFace.lastSeenProvider,
        thumbnail: dbFace.thumbnail,
      );

      // Load merged faces for this tracked face
      final mergedDbFaces = await database.getMergedFacesForTarget(dbFace.id);
      for (final mergedDbFace in mergedDbFaces) {
        final List<double> mergedFeatures =
            _blobToFeatures(mergedDbFace.features);

        final mergedFace = TrackedFace(
          id: mergedDbFace.sourceId,
          features: mergedFeatures,
          name: trackedFace.name, // Inherit the name from target face
          firstSeen: mergedDbFace.firstSeen,
          lastSeen: mergedDbFace.lastSeen,
          lastSeenProvider: '', // Not storing this info for merged faces
          thumbnail: mergedDbFace.thumbnail,
        );

        trackedFace.mergedFaces.add(mergedFace);
      }

      trackedFacesMap[dbFace.id] = trackedFace;
    }

    return trackedFacesMap;
  }

  /// Save a tracked face to the database
  Future<void> saveTrackedFace(TrackedFace face) async {
    final database = await _databaseProvider.database;

    // Convert features to blob
    final blob = _featuresToBlob(face.features);

    // Create companion object for insertion/update
    final companion = DBTrackedFacesCompanion(
      id: Value(face.id),
      name: Value(face.name),
      features: Value(blob),
      thumbnail: Value(face.thumbnail),
      firstSeen: Value(face.firstSeen),
      lastSeen: Value(face.lastSeen),
      lastSeenProvider: Value(face.lastSeenProvider),
    );

    // Check if face already exists
    final existingFace = await database.getTrackedFaceById(face.id);
    if (existingFace == null) {
      await database.insertTrackedFace(companion);
    } else {
      await database.updateTrackedFace(companion);
    }

    // Remove any existing merged faces for this target (will readd them below)
    await removeMergedFacesForTarget(face.id);

    // Save merged faces as well
    for (final mergedFace in face.mergedFaces) {
      await saveMergedFace(mergedFace, face.id);
    }
  }

  /// Remove all merged faces associated with a target ID
  Future<void> removeMergedFacesForTarget(String targetId) async {
    final database = await _databaseProvider.database;
    // Delete existing merged faces for this target
    final mergedFaces = await database.getMergedFacesForTarget(targetId);
    for (final mergedFace in mergedFaces) {
      await database.deleteMergedFace(mergedFace.sourceId);
    }
  }

  /// Save a merged face to the database
  Future<void> saveMergedFace(TrackedFace mergedFace, String targetId) async {
    final database = await _databaseProvider.database;

    // Convert features to blob
    final blob = _featuresToBlob(mergedFace.features);

    // Create companion object for insertion
    final companion = DBMergedFacesCompanion(
      id: Value(_uuid.v4()), // Generate a unique ID for the relationship
      targetId: Value(targetId),
      sourceId: Value(mergedFace.id),
      features: Value(blob),
      thumbnail: Value(mergedFace.thumbnail),
      firstSeen: Value(mergedFace.firstSeen),
      lastSeen: Value(mergedFace.lastSeen),
    );

    await database.insertMergedFace(companion);
  }

  /// Merge two faces in the database
  Future<void> mergeFaces(String targetId, String sourceId) async {
    final database = await _databaseProvider.database;

    // Get the source face
    final sourceFace = await database.getTrackedFaceById(sourceId);
    if (sourceFace == null) return;

    // Update visits for the merged face to point to the target face FIRST
    // This ensures visits are properly attributed before we delete the source face
    await updateVisitsForMergedFace(sourceId, targetId);

    // Get all merged faces of the source face
    final sourceMergedFaces = await database.getMergedFacesForTarget(sourceId);

    // Transfer all merged faces from source to target
    for (final mergedFace in sourceMergedFaces) {
      // Create a new merged face entry pointing to the target
      final transferCompanion = DBMergedFacesCompanion(
        id: Value(_uuid.v4()),
        targetId: Value(targetId), // Now points to the new target
        sourceId: Value(mergedFace.sourceId), // Keep original source ID
        features: Value(mergedFace.features),
        thumbnail: Value(mergedFace.thumbnail),
        firstSeen: Value(mergedFace.firstSeen),
        lastSeen: Value(mergedFace.lastSeen),
      );

      await database.insertMergedFace(transferCompanion);
    }

    // Save the source face itself as a merged face under the target
    final companion = DBMergedFacesCompanion(
      id: Value(_uuid.v4()),
      targetId: Value(targetId),
      sourceId: Value(sourceId),
      features: Value(sourceFace.features),
      thumbnail: Value(sourceFace.thumbnail),
      firstSeen: Value(sourceFace.firstSeen),
      lastSeen: Value(sourceFace.lastSeen),
    );

    await database.insertMergedFace(companion);

    // Delete all merged faces associated with the source face
    await removeMergedFacesForTarget(sourceId);

    // Delete the source face from tracked faces
    await database.deleteTrackedFace(sourceId);
  }

  /// Update the name of a face
  Future<void> updateFaceName(String faceId, String newName) async {
    final database = await _databaseProvider.database;
    final face = await database.getTrackedFaceById(faceId);
    if (face == null) return;

    final companion = DBTrackedFacesCompanion(
      id: Value(faceId),
      name: Value(newName),
      features: Value(face.features),
      thumbnail: Value(face.thumbnail),
      firstSeen: Value(face.firstSeen),
      lastSeen: Value(face.lastSeen),
      lastSeenProvider: Value(face.lastSeenProvider),
    );

    await database.updateTrackedFace(companion);
  }

  /// Delete a tracked face and all its merged faces
  Future<void> deleteFace(String faceId) async {
    final database = await _databaseProvider.database;

    // Delete all merged faces for this target
    await removeMergedFacesForTarget(faceId);

    // Delete the face itself
    await database.deleteTrackedFace(faceId);
  }

  /// Restore a merged face as a separate tracked face
  Future<void> restoreMergedFace(
      String targetId, TrackedFace mergedFace) async {
    final database = await _databaseProvider.database;

    // Convert features to blob
    final blob = _featuresToBlob(mergedFace.features);

    // Create companion object for insertion as a new tracked face
    final trackedFaceCompanion = DBTrackedFacesCompanion(
      id: Value(mergedFace.id),
      name: Value(mergedFace.name),
      features: Value(blob),
      thumbnail: Value(mergedFace.thumbnail),
      firstSeen: Value(mergedFace.firstSeen),
      lastSeen: Value(mergedFace.lastSeen),
      lastSeenProvider: Value(mergedFace.lastSeenProvider),
    );

    // Insert as a new tracked face
    await database.insertTrackedFace(trackedFaceCompanion);

    // Delete from merged faces
    await database.deleteMergedFace(mergedFace.id);
  }

  // Helper methods to convert between List<double> and Blob
  Uint8List _featuresToBlob(List<double> features) {
    final byteData = features.map((e) => e.toString()).join(',');
    return Uint8List.fromList(utf8.encode(byteData));
  }

  List<double> _blobToFeatures(Uint8List blob) {
    final str = utf8.decode(blob);
    return str.split(',').map((e) => double.parse(e)).toList();
  }

  // Visit tracking methods

  /// Create a new visit record
  Future<void> createVisit(
      {required String id,
      required String faceId,
      required String providerId,
      required DateTime entryTime}) async {
    final database = await _databaseProvider.database;

    final companion = DBVisitsCompanion(
      id: Value(id),
      faceId: Value(faceId),
      providerId: Value(providerId),
      entryTime: Value(entryTime),
      // exitTime is null initially
      // durationSeconds is null initially
    );

    await database.insertVisit(companion);
  }

  /// Update the last seen time of an active visit
  Future<void> updateVisitLastSeen(String visitId, DateTime timestamp) async {
    final database = await _databaseProvider.database;
    // Get the current visit
    final visits = await (database.select(database.dBVisits)
          ..where((tbl) => tbl.id.equals(visitId)))
        .get();
    if (visits.isEmpty) return;
    final visit = visits.first;

    final companion = DBVisitsCompanion(
      id: Value(visitId),
      faceId: Value(visit.faceId),
      providerId: Value(visit.providerId),
      entryTime: Value(visit.entryTime),
      exitTime: Value(
          timestamp), // Set exitTime but leave durationSeconds null to keep visit active
    );
    await database.updateVisit(companion);
  }

  /// Update a visit with exit time and calculate duration
  Future<void> updateVisitExit(String visitId, DateTime exitTime) async {
    final database = await _databaseProvider.database;

    // Get the current visit
    final visits = await (database.select(database.dBVisits)
          ..where((tbl) => tbl.id.equals(visitId)))
        .get();

    if (visits.isEmpty) return;

    final visit = visits.first;

    // Calculate duration in seconds
    final durationSeconds = exitTime.difference(visit.entryTime).inSeconds;

    final companion = DBVisitsCompanion(
      id: Value(visitId),
      faceId: Value(visit.faceId),
      providerId: Value(visit.providerId),
      entryTime: Value(visit.entryTime),
      exitTime: Value(exitTime),
      durationSeconds: Value(durationSeconds),
    );

    await database.updateVisit(companion);
  }

  /// Get all active visits (no exit time)
  Future<List<DBVisit>> getActiveVisits() async {
    final database = await _databaseProvider.database;
    return await database.getActiveVisits();
  }

  /// Delete all visits for a face
  Future<void> deleteVisitsForFace(String faceId) async {
    final database = await _databaseProvider.database;
    await database.deleteVisitsForFace(faceId);
  }

  /// Update visits for a merged face to point to the target face
  Future<void> updateVisitsForMergedFace(
      String sourceId, String targetId) async {
    final database = await _databaseProvider.database;

    final visits = await (database.select(database.dBVisits)
          ..where((tbl) => tbl.faceId.equals(sourceId)))
        .get();

    for (var visit in visits) {
      final companion = DBVisitsCompanion(
        id: Value(visit.id),
        faceId: Value(targetId), // Change to target face ID
        providerId: Value(visit.providerId),
        entryTime: Value(visit.entryTime),
        exitTime: Value(visit.exitTime),
        durationSeconds: Value(visit.durationSeconds),
      );

      await database.updateVisit(companion);
    }
  }

  /// Get visit statistics for analytics
  Future<Map<String, dynamic>> getVisitStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? providerId,
    String? faceId,
  }) async {
    final database = await _databaseProvider.database;

    // Build base query with all filters
    var query = database.select(database.dBVisits);

    if (providerId != null) {
      query = query..where((tbl) => tbl.providerId.equals(providerId));
    }

    if (faceId != null) {
      query = query..where((tbl) => tbl.faceId.equals(faceId));
    }

    if (startDate != null) {
      query = query
        ..where((tbl) => tbl.entryTime.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query = query
        ..where((tbl) => tbl.entryTime.isSmallerOrEqualValue(endDate));
    }

    // Get filtered visits
    final visits = await query.get();

    // Initialize statistics map
    final Map<String, dynamic> stats = {
      'totalVisits': 0,
      'activeVisits': 0,
      'completedVisits': 0,
      'avgDurationSeconds': 0.0,
      'providers': <String>{},
      'uniqueFaces': <String>{},
      'visitsByDay': <String, int>{},
      'visitsByHour': <int, int>{},
    };

    // Count only valid visits
    final validVisits = visits
        .where((v) =>
            v.faceId != null &&
            (v.faceId?.isNotEmpty ?? false) &&
            v.providerId.isNotEmpty)
        .toList();

    stats['totalVisits'] = validVisits.length;
    stats['activeVisits'] =
        validVisits.where((v) => v.durationSeconds == null).length;
    stats['completedVisits'] =
        validVisits.where((v) => v.durationSeconds != null).length;

    // Collect unique providers and faces
    for (var visit in validVisits) {
      stats['providers'].add(visit.providerId);
      stats['uniqueFaces'].add(visit.faceId!);

      // Track by day and hour
      final day = formatDate(visit.entryTime);
      stats['visitsByDay'][day] = (stats['visitsByDay'][day] ?? 0) + 1;
      stats['visitsByHour'][visit.entryTime.hour] =
          (stats['visitsByHour'][visit.entryTime.hour] ?? 0) + 1;
    }

    // Calculate average duration for completed visits
    final completedVisits = validVisits.where((v) => v.durationSeconds != null);
    if (completedVisits.isNotEmpty) {
      final totalDuration = completedVisits.fold<int>(
          0, (sum, visit) => sum + (visit.durationSeconds ?? 0));
      stats['avgDurationSeconds'] = totalDuration / completedVisits.length;
    }

    stats['providerCount'] = (stats['providers'] as Set<String>).length;
    stats['uniqueFacesCount'] = (stats['uniqueFaces'] as Set<String>).length;

    return stats;
  }

  /// Get detailed visit history for a specific face
  Future<List<Map<String, dynamic>>> getVisitDetailsForFace(
      String faceId) async {
    final database = await _databaseProvider.database;

    final visits = await (database.select(database.dBVisits)
          ..where((tbl) => tbl.faceId.equals(faceId))
          ..orderBy([(t) => OrderingTerm.desc(t.entryTime)]))
        .get();

    // Convert to a more detailed format
    return visits.map((visit) {
      return {
        'id': visit.id,
        'faceId': visit.faceId, // Add faceId to the result for debugging
        'providerId': visit.providerId,
        'entryTime': visit.entryTime,
        'exitTime': visit.exitTime,
        'duration': visit.durationSeconds != null
            ? Duration(seconds: visit.durationSeconds!)
            : null,
        'isActive': visit.exitTime == null,
        'date': formatDate(visit.entryTime),
        'entryHour': visit.entryTime.hour,
        'exitHour': visit.exitTime?.hour,
      };
    }).toList();
  }

  // Helper to format date as YYYY-MM-DD
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Gets a single tracked face by ID
  Future<TrackedFace?> getTrackedFace(String faceId) async {
    final database = await _databaseProvider.database;

    // Get the tracked face from database
    final dbFace = await database.getTrackedFaceById(faceId);
    if (dbFace == null) {
      return null;
    }

    // Convert blob to List<double> features
    final List<double> features = _blobToFeatures(dbFace.features);

    // Create the tracked face model
    final trackedFace = TrackedFace(
      id: dbFace.id,
      features: features,
      name: dbFace.name ?? dbFace.id,
      firstSeen: dbFace.firstSeen,
      lastSeen: dbFace.lastSeen,
      lastSeenProvider: dbFace.lastSeenProvider,
      thumbnail: dbFace.thumbnail,
    );

    // Load merged faces for this tracked face
    final mergedDbFaces = await database.getMergedFacesForTarget(dbFace.id);
    for (final mergedDbFace in mergedDbFaces) {
      final List<double> mergedFeatures =
          _blobToFeatures(mergedDbFace.features);

      final mergedFace = TrackedFace(
        id: mergedDbFace.sourceId,
        features: mergedFeatures,
        name: trackedFace.name, // Inherit the name from target face
        firstSeen: mergedDbFace.firstSeen,
        lastSeen: mergedDbFace.lastSeen,
        lastSeenProvider: '', // Not storing this info for merged faces
        thumbnail: mergedDbFace.thumbnail,
      );

      trackedFace.mergedFaces.add(mergedFace);
    }

    return trackedFace;
  }

  /// Update a face's last seen time and provider
  Future<void> updateFaceLastSeen(
      String faceId, DateTime timestamp, String providerId) async {
    final database = await _databaseProvider.database;
    final face = await database.getTrackedFaceById(faceId);
    if (face == null) return;

    final companion = DBTrackedFacesCompanion(
      id: Value(faceId),
      name: Value(face.name),
      features: Value(face.features),
      thumbnail: Value(face.thumbnail),
      firstSeen: Value(
          face.firstSeen ?? timestamp), // Use timestamp if firstSeen is null
      lastSeen: Value(timestamp),
      lastSeenProvider: Value(providerId),
    );

    await database.updateTrackedFace(companion);
  }

  /// Get the number of visits for a specific face
  Future<int> getVisitCountForFace(String faceId) async {
    final database = await _databaseProvider.database;

    final query = database.select(database.dBVisits)
      ..where((tbl) => tbl.faceId.equals(faceId));

    final visits = await query.get();
    return visits.length;
  }

  /// Get list of expected attendees
  Future<List<String>> getExpectedAttendees() async {
    final database = await _databaseProvider.database;
    return await database.getExpectedAttendees();
  }

  /// Add a face to expected attendees
  Future<void> addExpectedAttendee(String faceId) async {
    final database = await _databaseProvider.database;
    await database.addExpectedAttendee(faceId);
  }

  /// Remove a face from expected attendees
  Future<void> removeExpectedAttendee(String faceId) async {
    final database = await _databaseProvider.database;
    await database.removeExpectedAttendee(faceId);
  }
}
