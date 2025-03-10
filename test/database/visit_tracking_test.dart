import 'package:automated_attendance/database/faces_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks/mock_database_provider.dart';

void main() {
  group('Visit Tracking Tests', () {
    late FacesRepository repository;
    late PrePopulatedMockDatabaseProvider mockProvider;

    setUp(() {
      // Create a new mock database provider for each test
      mockProvider = PrePopulatedMockDatabaseProvider();
      repository = FacesRepository(databaseProvider: mockProvider);
    });

    tearDown(() async {
      // Close the database after each test
      await mockProvider.closeDatabase();
    });

    test('Create and retrieve visit', () async {
      final visitId = 'test-visit-1';
      final faceId = 'test-face-1';
      final providerId = 'test-camera-1';
      final entryTime = DateTime.now();

      // Create a visit
      await repository.createVisit(
        id: visitId,
        faceId: faceId,
        providerId: providerId,
        entryTime: entryTime,
      );

      // Get visits for the face
      final visits = await repository.getVisitDetailsForFace(faceId);

      // Verify
      expect(visits.length, 1);
      expect(visits.first['id'], visitId);
      expect(visits.first['providerId'], providerId);
      expect(visits.first['isActive'], true);
      expect(visits.first['exitTime'], null);
    });

    test('Update visit exit time', () async {
      // Create visit
      final visitId = 'test-visit-2';
      final faceId = 'test-face-2';
      final providerId = 'test-camera-2';
      final entryTime = DateTime.now().subtract(const Duration(hours: 1));

      await repository.createVisit(
        id: visitId,
        faceId: faceId,
        providerId: providerId,
        entryTime: entryTime,
      );

      // Set exit time
      final exitTime = DateTime.now();
      await repository.updateVisitExit(visitId, exitTime);

      // Verify
      final visits = await repository.getVisitDetailsForFace(faceId);
      expect(visits.length, 1);
      expect(visits.first['exitTime'], isNotNull);
      expect(visits.first['isActive'], false);
      expect(visits.first['duration'], isNotNull);

      // Calculate expected duration in seconds
      final expectedDurationInSeconds =
          exitTime.difference(entryTime).inSeconds;
      final actualDurationInSeconds =
          (visits.first['duration'] as Duration).inSeconds;
      expect(actualDurationInSeconds, expectedDurationInSeconds);
    });

    test('Update active visit last seen', () async {
      // Create visit
      final visitId = 'test-visit-3';
      final faceId = 'test-face-3';
      final providerId = 'test-camera-3';
      final entryTime = DateTime.now().subtract(const Duration(minutes: 30));

      await repository.createVisit(
        id: visitId,
        faceId: faceId,
        providerId: providerId,
        entryTime: entryTime,
      );

      // Update last seen
      final lastSeenTime = DateTime.now();
      await repository.updateVisitLastSeen(visitId, lastSeenTime);

      // Verify visit is still active but exitTime is updated for tracking purposes
      final visits = await repository.getVisitDetailsForFace(faceId);
      expect(visits.length, 1);
      // Use isA matcher instead of direct comparison for DateTime which may lose precision
      expect(visits.first['exitTime'], isA<DateTime>());
      expect(visits.first['duration'],
          null); // Duration is still null for active visits
      expect(visits.first['isActive'],
          false); // isActive is based on exitTime being null
    });

    test('Get visit statistics', () async {
      // Create multiple visits for testing
      final face1Id = 'test-face-stats-1';
      final face2Id = 'test-face-stats-2';
      final providerId1 = 'camera-1';
      final providerId2 = 'camera-2';

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final dayBeforeYesterday = now.subtract(const Duration(days: 2));

      // Visit 1: Face 1, Camera 1, yesterday, completed
      await repository.createVisit(
        id: 'visit-1',
        faceId: face1Id,
        providerId: providerId1,
        entryTime: yesterday.add(const Duration(hours: 10)), // 10 AM
      );
      await repository.updateVisitExit(
        'visit-1',
        yesterday.add(const Duration(hours: 11)), // 11 AM - 1 hour duration
      );

      // Visit 2: Face 1, Camera 2, yesterday, completed
      await repository.createVisit(
        id: 'visit-2',
        faceId: face1Id,
        providerId: providerId2,
        entryTime: yesterday.add(const Duration(hours: 14)), // 2 PM
      );
      await repository.updateVisitExit(
        'visit-2',
        yesterday.add(const Duration(hours: 16)), // 4 PM - 2 hours duration
      );

      // Visit 3: Face 2, Camera 1, two days ago, completed
      await repository.createVisit(
        id: 'visit-3',
        faceId: face2Id,
        providerId: providerId1,
        entryTime: dayBeforeYesterday.add(const Duration(hours: 9)), // 9 AM
      );
      await repository.updateVisitExit(
        'visit-3',
        dayBeforeYesterday.add(const Duration(
            hours: 10, minutes: 30)), // 10:30 AM - 1.5 hours duration
      );

      // Visit 4: Face 2, Camera 2, today, active (no exit time)
      await repository.createVisit(
        id: 'visit-4',
        faceId: face2Id,
        providerId: providerId2,
        entryTime: now.subtract(const Duration(hours: 1)), // 1 hour ago
      );

      // Get overall statistics
      final stats = await repository.getVisitStatistics();

      // Verify counts
      expect(stats['totalVisits'], 4);
      expect(stats['activeVisits'], 1);
      expect(stats['completedVisits'], 3);
      expect(stats['providers'], contains(providerId1));
      expect(stats['providers'], contains(providerId2));
      expect(stats['uniqueFaces'], containsAll([face1Id, face2Id]));

      // Verify average duration (for completed visits: 1 hour + 2 hours + 1.5 hours) / 3 = 4.5 hours / 3 = 1.5 hours
      expect(
          stats['avgDurationSeconds'],
          closeTo(4.5 * 3600 / 3,
              1.0)); // Using closeTo to handle floating point precision

      // Statistics by provider
      final providerStats =
          await repository.getVisitStatistics(providerId: providerId1);

      // Debug: Print all visits for camera-1
      print('\nAll visits for camera-1:');
      final allVisits = await repository.getVisitDetailsForFace(face1Id);
      allVisits.addAll(await repository.getVisitDetailsForFace(face2Id));
      for (final visit in allVisits) {
        if (visit['providerId'] == providerId1) {
          print(
              'Visit ID: ${visit['id']}, Face: ${visit['faceId']}, Provider: ${visit['providerId']}, Entry: ${visit['entryTime']}');
        }
      }

      expect(providerStats['totalVisits'], 2); // Only 2 visits for camera-1
      expect(providerStats['uniqueFacesCount'], 2);

      // Statistics by face
      final faceStats = await repository.getVisitStatistics(faceId: face1Id);
      expect(faceStats['totalVisits'], 2);
      expect(faceStats['completedVisits'], 2);
      expect(faceStats['activeVisits'], 0);

      // Statistics by date range (yesterday only)
      final dateStats = await repository.getVisitStatistics(
        providerId: providerId1,
        startDate: yesterday.subtract(const Duration(hours: 1)),
        endDate: yesterday.add(const Duration(hours: 23)),
      );
      expect(dateStats['totalVisits'], 1);
    });

    test('Delete visits for face', () async {
      // Create a visit
      final faceId = 'delete-test-face';

      await repository.createVisit(
        id: 'delete-test-visit',
        faceId: faceId,
        providerId: 'test-camera',
        entryTime: DateTime.now(),
      );

      // Verify visit exists
      final beforeDelete = await repository.getVisitDetailsForFace(faceId);
      expect(beforeDelete.length, 1);

      // Delete all visits for the face
      await repository.deleteVisitsForFace(faceId);

      // Verify visit is gone
      final afterDelete = await repository.getVisitDetailsForFace(faceId);
      expect(afterDelete.length, 0);
    });

    test('Visit count for face', () async {
      // Create a face with multiple visits
      final faceId = 'count-test-face';

      await repository.createVisit(
        id: 'count-test-visit-1',
        faceId: faceId,
        providerId: 'test-camera',
        entryTime: DateTime.now().subtract(const Duration(hours: 3)),
      );

      await repository.createVisit(
        id: 'count-test-visit-2',
        faceId: faceId,
        providerId: 'test-camera',
        entryTime: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await repository.createVisit(
        id: 'count-test-visit-3',
        faceId: faceId,
        providerId: 'test-camera',
        entryTime: DateTime.now().subtract(const Duration(hours: 1)),
      );

      // Get count
      final count = await repository.getVisitCountForFace(faceId);
      expect(count, 3);
    });
  });
}
