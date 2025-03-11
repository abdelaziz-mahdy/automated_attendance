import 'package:automated_attendance/database/faces_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks/mock_database_provider.dart';

void main() {
  group('Analytics Tests', () {
    late FacesRepository repository;
    late PrePopulatedMockDatabaseProvider mockProvider;

    setUp(() {
      mockProvider = PrePopulatedMockDatabaseProvider();
      repository = FacesRepository(databaseProvider: mockProvider);
    });

    tearDown(() async {
      await mockProvider.closeDatabase();
    });

    // Helper to add predefined data for testing analytics
    Future<void> setupTestData() async {
      // Create 3 faces
      final face1Id = 'analytics-face-1'; // Regular visitor (many visits)
      final face2Id = 'analytics-face-2'; // Occasional visitor (few visits)
      final face3Id = 'analytics-face-3'; // New visitor (single visit)

      // 2 cameras
      final camera1Id = 'analytics-camera-1'; // Main entrance
      final camera2Id = 'analytics-camera-2'; // Secondary entrance

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Face 1 - Regular visitor
      // - Morning visits on 3 days
      for (int day = 1; day <= 3; day++) {
        final visitDate = today.subtract(Duration(days: day));

        // Morning visit
        await repository.createVisit(
          id: 'face1-day$day-morning',
          faceId: face1Id,
          providerId: camera1Id,
          entryTime: DateTime(
              visitDate.year, visitDate.month, visitDate.day, 9, 0), // 9:00 AM
        );
        await repository.updateVisitExit(
          'face1-day$day-morning',
          DateTime(visitDate.year, visitDate.month, visitDate.day, 10,
              0), // 10:00 AM - 1 hour duration
        );

        // Afternoon visit
        await repository.createVisit(
          id: 'face1-day$day-afternoon',
          faceId: face1Id,
          providerId: camera2Id,
          entryTime: DateTime(
              visitDate.year, visitDate.month, visitDate.day, 14, 0), // 2:00 PM
        );
        await repository.updateVisitExit(
          'face1-day$day-afternoon',
          DateTime(visitDate.year, visitDate.month, visitDate.day, 15,
              30), // 3:30 PM - 1.5 hours duration
        );
      }

      // Face 2 - Occasional visitor
      // - Two visits on different days
      // Visit 1
      await repository.createVisit(
        id: 'face2-visit1',
        faceId: face2Id,
        providerId: camera1Id,
        entryTime: DateTime(today.year, today.month, today.day - 5, 11,
            0), // 11:00 AM, 5 days ago
      );
      await repository.updateVisitExit(
        'face2-visit1',
        DateTime(today.year, today.month, today.day - 5, 12,
            30), // 12:30 PM - 1.5 hours duration
      );

      // Visit 2
      await repository.createVisit(
        id: 'face2-visit2',
        faceId: face2Id,
        providerId: camera2Id,
        entryTime: DateTime(today.year, today.month, today.day - 2, 16,
            0), // 4:00 PM, 2 days ago
      );
      await repository.updateVisitExit(
        'face2-visit2',
        DateTime(today.year, today.month, today.day - 2, 16,
            45), // 4:45 PM - 45 minutes duration
      );

      // Face 3 - New visitor
      // - Single visit today (still active)
      await repository.createVisit(
        id: 'face3-visit1',
        faceId: face3Id,
        providerId: camera1Id,
        entryTime: DateTime(
            today.year, today.month, today.day, 8, 30), // 8:30 AM today
      );
    }

    test('Daily visit distribution analysis', () async {
      // Setup test data
      await setupTestData();

      // Get overall statistics
      final stats = await repository.getVisitStatistics();

      // Verify visit counts
      expect(stats['totalVisits'],
          9); // 6 visits from face1, 2 from face2, 1 from face3
      expect(stats['activeVisits'], 1); // face3 still active
      expect(stats['completedVisits'], 8); // all others complete

      // Verify daily distribution
      final visitsByDay = stats['visitsByDay'] as Map<String, int>;
      expect(visitsByDay.length, 5); // Data spans 5 different days

      // Check that today has at least 1 visit (face3's active visit)
      final todayFormatted = repository.formatDate(DateTime.now());
      expect(visitsByDay[todayFormatted], 1);

      // Check that day-3 has 2 visits (face1 morning and afternoon)
      final day3 = DateTime.now().subtract(const Duration(days: 3));
      final day3Formatted = repository.formatDate(day3);
      expect(visitsByDay[day3Formatted], 2);
    });

    test('Hourly visit distribution analysis', () async {
      // Setup test data
      await setupTestData();

      // Get statistics
      final stats = await repository.getVisitStatistics();

      // Check hourly distribution
      final visitsByHour = stats['visitsByHour'] as Map<int, int>;

      // 9 AM (hour 9) should have 3 visits (face1 morning visits for 3 days)
      expect(visitsByHour[9], 3);

      // 2 PM (hour 14) should have 3 visits (face1 afternoon visits for 3 days)
      expect(visitsByHour[14], 3);

      // 8 AM (hour 8) should have 1 visit (face3 today)
      expect(visitsByHour[8], 1);

      // 4 PM (hour 16) should have 1 visit (face2 visit2)
      expect(visitsByHour[16], 1);
    });

    test('Average duration calculation', () async {
      // Setup test data
      await setupTestData();

      // Get statistics
      final stats = await repository.getVisitStatistics();

      // Calculate expected average duration
      // Face1: 3 days * (1 hour + 1.5 hours) = 7.5 hours
      // Face2: 1.5 hours + 45 minutes = 2.25 hours
      // Total: 9.75 hours for 7 completed visits = 1.39 hours average
      // In seconds: 1.39 * 3600 = 5004 seconds
      expect(stats['avgDurationSeconds'],
          closeTo(4387.5, 10)); // Allow some rounding error
    });

    test('Unique visitors count', () async {
      // Setup test data
      await setupTestData();

      // Get statistics
      final stats = await repository.getVisitStatistics();

      // Verify unique face count
      expect(stats['uniqueFacesCount'], 3); // 3 different faces

      // Verify providers count
      expect(stats['providerCount'], 2); // 2 different cameras
    });

    test('Filter statistics by camera provider', () async {
      // Setup test data
      await setupTestData();

      // Get statistics for camera 1
      final camera1Stats =
          await repository.getVisitStatistics(providerId: 'analytics-camera-1');

      // Camera 1 should have 5 visits
      // - 3 morning visits from face1
      // - 1 visit from face2
      // - 1 visit from face3
      expect(camera1Stats['totalVisits'], 5);
      expect(camera1Stats['activeVisits'], 1); // face3 is still active
      expect(camera1Stats['completedVisits'], 4);

      // Check average duration (only completed visits)
      // Face1: 3 * 1 hour = 3 hours
      // Face2: 1.5 hours
      // Total: 4.5 hours for 4 visits = 1.125 hours average
      // In seconds: 1.125 * 3600 = 4050 seconds
      expect(camera1Stats['avgDurationSeconds'], closeTo(4050, 10));
    });

    test('Filter statistics by date range', () async {
      // Setup test data
      await setupTestData();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Get statistics for yesterday and today
      final recentStats = await repository.getVisitStatistics(
        startDate: yesterday,
        endDate: today.add(const Duration(days: 1)),
      );

      // Should have 3 visits:
      // - 2 visits from face1 on yesterday
      // - 1 visit from face3 today
      expect(recentStats['totalVisits'], 3);
      expect(recentStats['uniqueFacesCount'], 2); // face1 and face3
    });

    test('Filter statistics by face ID', () async {
      // Setup test data
      await setupTestData();

      // Get statistics for face1
      final face1Stats =
          await repository.getVisitStatistics(faceId: 'analytics-face-1');

      // Face1 should have 6 visits (3 days, 2 visits per day)
      expect(face1Stats['totalVisits'], 6);
      expect(face1Stats['completedVisits'], 6); // All completed
      expect(face1Stats['activeVisits'], 0); // None active

      // Check providers used by face1
      final providers = face1Stats['providers'] as Set<String>;
      expect(providers.length, 2); // Used both cameras
      expect(providers, contains('analytics-camera-1'));
      expect(providers, contains('analytics-camera-2'));

      // Check average duration
      // 3 days * (1 hour + 1.5 hours) = 7.5 hours total
      // 7.5 hours / 6 visits = 1.25 hours average
      // In seconds: 1.25 * 3600 = 4500
      expect(face1Stats['avgDurationSeconds'], closeTo(4500, 10));
    });

    test('Get detailed visit history for face', () async {
      // Setup test data
      await setupTestData();

      // Get detailed history for face1
      final face1Visits =
          await repository.getVisitDetailsForFace('analytics-face-1');

      // Should have 6 visits
      expect(face1Visits.length, 6);

      // Check details of visits
      for (final visit in face1Visits) {
        // Each visit should have these fields
        expect(visit.containsKey('id'), true);
        expect(visit.containsKey('providerId'), true);
        expect(visit.containsKey('entryTime'), true);
        expect(visit.containsKey('exitTime'), true);
        expect(visit.containsKey('duration'), true);
        expect(visit.containsKey('isActive'), true);

        // All face1 visits should be complete
        expect(visit['isActive'], false);
        expect(visit['duration'], isA<Duration>());
      }

      // Visits should be ordered by entry time (descending)
      final entryTimes =
          face1Visits.map((visit) => visit['entryTime'] as DateTime).toList();
      for (int i = 0; i < entryTimes.length - 1; i++) {
        expect(entryTimes[i].isAfter(entryTimes[i + 1]), true);
      }
    });

    test('Visit count by provider', () async {
      // Setup test data
      await setupTestData();

      // Get statistics
      final stats = await repository.getVisitStatistics();

      final providers = stats['providers'] as Set<String>;
      expect(providers.length, 2);

      // Check distribution (this would be used for charts)
      // Count visits from camera1
      int camera1Count = 0;
      int camera2Count = 0;

      final db = await mockProvider.database;
      final visits = await db.select(db.dBVisits).get();

      for (final visit in visits) {
        if (visit.providerId == 'analytics-camera-1') {
          camera1Count++;
        } else if (visit.providerId == 'analytics-camera-2') {
          camera2Count++;
        }
      }

      // Camera 1 should have 5 visits, Camera 2 should have 3 visits
      expect(camera1Count, 5);
      expect(camera2Count, 4);
    });
  });
}
