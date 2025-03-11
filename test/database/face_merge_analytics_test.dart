import 'package:automated_attendance/database/faces_repository.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks/mock_database_provider.dart';

void main() {
  group('Face Merge Analytics Tests', () {
    late FacesRepository repository;
    late PrePopulatedMockDatabaseProvider mockProvider;

    setUp(() {
      mockProvider = PrePopulatedMockDatabaseProvider();
      repository = FacesRepository(databaseProvider: mockProvider);
    });

    tearDown(() async {
      await mockProvider.closeDatabase();
    });

    test('Merging faces consolidates visit statistics', () async {
      // Create two faces
      final targetFaceId = 'merge-target-face';
      final sourceFaceId = 'merge-source-face';

      final targetFace = TrackedFace(
        id: targetFaceId,
        features: List.generate(128, (i) => 0.1 * i), // Dummy features
        name: 'Target Face',
        firstSeen: DateTime.now().subtract(const Duration(days: 10)),
        lastSeen: DateTime.now().subtract(const Duration(days: 2)),
        lastSeenProvider: 'camera-1',
        thumbnail: null,
        mergedFaces: [],
      );

      final sourceFace = TrackedFace(
        id: sourceFaceId,
        features: List.generate(128, (i) => 0.2 * i), // Dummy features
        name: 'Source Face',
        firstSeen: DateTime.now().subtract(const Duration(days: 5)),
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
        lastSeenProvider: 'camera-2',
        thumbnail: null,
        mergedFaces: [],
      );

      // Save both faces
      await repository.saveTrackedFace(targetFace);
      await repository.saveTrackedFace(sourceFace);

      // Create visits for both faces
      // Target Face: 3 visits
      await repository.createVisit(
        id: 'target-visit-1',
        faceId: targetFaceId,
        providerId: 'camera-1',
        entryTime: DateTime.now().subtract(const Duration(days: 8)),
      );
      await repository.updateVisitExit(
        'target-visit-1',
        DateTime.now()
            .subtract(const Duration(days: 8))
            .add(const Duration(hours: 1)),
      );

      await repository.createVisit(
        id: 'target-visit-2',
        faceId: targetFaceId,
        providerId: 'camera-1',
        entryTime: DateTime.now().subtract(const Duration(days: 5)),
      );
      await repository.updateVisitExit(
        'target-visit-2',
        DateTime.now()
            .subtract(const Duration(days: 5))
            .add(const Duration(hours: 2)),
      );

      await repository.createVisit(
        id: 'target-visit-3',
        faceId: targetFaceId,
        providerId: 'camera-2',
        entryTime: DateTime.now().subtract(const Duration(days: 2)),
      );
      await repository.updateVisitExit(
        'target-visit-3',
        DateTime.now()
            .subtract(const Duration(days: 2))
            .add(const Duration(hours: 1, minutes: 30)),
      );

      // Source Face: 2 visits
      await repository.createVisit(
        id: 'source-visit-1',
        faceId: sourceFaceId,
        providerId: 'camera-2',
        entryTime: DateTime.now().subtract(const Duration(days: 4)),
      );
      await repository.updateVisitExit(
        'source-visit-1',
        DateTime.now()
            .subtract(const Duration(days: 4))
            .add(const Duration(hours: 1)),
      );

      await repository.createVisit(
        id: 'source-visit-2',
        faceId: sourceFaceId,
        providerId: 'camera-3',
        entryTime: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repository.updateVisitExit(
        'source-visit-2',
        DateTime.now()
            .subtract(const Duration(days: 1))
            .add(const Duration(minutes: 45)),
      );

      // Get initial statistics for both faces
      final targetStatsBeforeMerge =
          await repository.getVisitStatistics(faceId: targetFaceId);
      final sourceStatsBeforeMerge =
          await repository.getVisitStatistics(faceId: sourceFaceId);

      expect(targetStatsBeforeMerge['totalVisits'], 3);
      expect(sourceStatsBeforeMerge['totalVisits'], 2);

      // Now merge the source face into the target face
      await repository.mergeFaces(targetFaceId, sourceFaceId);

      // Get statistics after merge for target face
      final targetStatsAfterMerge =
          await repository.getVisitStatistics(faceId: targetFaceId);

      // Target face should now have all 5 visits
      expect(targetStatsAfterMerge['totalVisits'], 5);

      // The source face ID should no longer be a tracked face
      final sourceFaceAfterMerge =
          await repository.getTrackedFace(sourceFaceId);
      expect(sourceFaceAfterMerge, isNull);

      // Source face visits should now be attributed to target face
      final allTargetVisits =
          await repository.getVisitDetailsForFace(targetFaceId);
      expect(allTargetVisits.length, 5);

      // Verify that visits from source face are now attributed to target face
      bool foundSourceVisit1 = false;
      bool foundSourceVisit2 = false;

      for (final visit in allTargetVisits) {
        if (visit['id'] == 'source-visit-1') {
          foundSourceVisit1 = true;
          // Check that the face ID was updated to the target face ID
          expect(visit['faceId'], targetFaceId);
        } else if (visit['id'] == 'source-visit-2') {
          foundSourceVisit2 = true;
          // Check that the face ID was updated to the target face ID
          expect(visit['faceId'], targetFaceId);
        }
      }

      expect(foundSourceVisit1, true);
      expect(foundSourceVisit2, true);

      // Verify stats computation includes merged visits
      expect(targetStatsAfterMerge['providers'], contains('camera-1'));
      expect(targetStatsAfterMerge['providers'], contains('camera-2'));
      expect(targetStatsAfterMerge['providers'], contains('camera-3'));
    });

    test('Analytics by date range includes merged faces', () async {
      // Create two faces
      final targetFaceId = 'date-target-face';
      final sourceFaceId = 'date-source-face';

      final targetFace = TrackedFace(
        id: targetFaceId,
        features: List.generate(128, (i) => 0.1 * i), // Dummy features
        name: 'Date Target Face',
        firstSeen: DateTime.now().subtract(const Duration(days: 10)),
        lastSeen: DateTime.now().subtract(const Duration(days: 2)),
        lastSeenProvider: 'camera-1',
        thumbnail: null,
        mergedFaces: [],
      );

      final sourceFace = TrackedFace(
        id: sourceFaceId,
        features: List.generate(128, (i) => 0.2 * i), // Dummy features
        name: 'Date Source Face',
        firstSeen: DateTime.now().subtract(const Duration(days: 15)),
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
        lastSeenProvider: 'camera-2',
        thumbnail: null,
        mergedFaces: [],
      );
      await repository.saveTrackedFace(targetFace);
      await repository.saveTrackedFace(sourceFace);

      // Create visits with specific dates for testing date range filtering

      // Target face: 3 visits on days 10, 7, and 3
      final day10 = DateTime.now().subtract(const Duration(days: 10));
      final day7 = DateTime.now().subtract(const Duration(days: 7));
      final day3 = DateTime.now().subtract(const Duration(days: 3));

      await repository.createVisit(
        id: 'target-day10',
        faceId: targetFaceId,
        providerId: 'camera-1',
        entryTime: day10,
      );
      await repository.updateVisitExit(
        'target-day10',
        day10.add(const Duration(hours: 1)),
      );

      await repository.createVisit(
        id: 'target-day7',
        faceId: targetFaceId,
        providerId: 'camera-1',
        entryTime: day7,
      );
      await repository.updateVisitExit(
        'target-day7',
        day7.add(const Duration(hours: 1)),
      );

      await repository.createVisit(
        id: 'target-day3',
        faceId: targetFaceId,
        providerId: 'camera-1',
        entryTime: day3,
      );
      await repository.updateVisitExit(
        'target-day3',
        day3.add(const Duration(hours: 1)),
      );

      // Source face: 2 visits on days 15 and 5
      final day15 = DateTime.now().subtract(const Duration(days: 15));
      final day5 = DateTime.now().subtract(const Duration(days: 5));

      await repository.createVisit(
        id: 'source-day15',
        faceId: sourceFaceId,
        providerId: 'camera-2',
        entryTime: day15,
      );
      await repository.updateVisitExit(
        'source-day15',
        day15.add(const Duration(hours: 1)),
      );

      await repository.createVisit(
        id: 'source-day5',
        faceId: sourceFaceId,
        providerId: 'camera-2',
        entryTime: day5,
      );
      await repository.updateVisitExit(
        'source-day5',
        day5.add(const Duration(hours: 1)),
      );

      // Merge faces
      await repository.mergeFaces(targetFaceId, sourceFaceId);

      // Now test date range filtering

      // Filter for days 6-10 (should include 2 target visits + 1 source visit)
      final midRangeStats = await repository.getVisitStatistics(
        faceId: targetFaceId,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().subtract(const Duration(days: 5)),
      );

      expect(midRangeStats['totalVisits'], 3);

      // Filter for days 1-5 (should include 1 target visit)
      final recentStats = await repository.getVisitStatistics(
        faceId: targetFaceId,
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        endDate: DateTime.now(),
      );

      expect(recentStats['totalVisits'], 2); // 1 from target + 1 from source

      // Filter for days 11-15 (should include 1 source visit)
      final oldStats = await repository.getVisitStatistics(
        faceId: targetFaceId,
        startDate: DateTime.now().subtract(const Duration(days: 15)),
        endDate: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(oldStats['totalVisits'], 2); // 1 from target + 1 from source

      // Filter by camera provider after merging
      final camera2Stats = await repository.getVisitStatistics(
        faceId: targetFaceId,
        providerId: 'camera-2',
      );

      expect(
          camera2Stats['totalVisits'], 2); // Both source visits used camera-2
    });
  });
}
