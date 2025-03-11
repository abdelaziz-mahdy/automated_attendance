import 'package:automated_attendance/database/database.dart';
import 'package:automated_attendance/database/database_provider.dart';
import 'package:drift/native.dart';

/// Mock database provider for testing purposes
class MockDatabaseProvider implements IDatabaseProvider {
  FacesDatabase? _database;
  bool _closed = false;

  @override
  Future<FacesDatabase> get database async {
    if (_database != null) return _database!;

    // Create an in-memory database for testing
    _database = FacesDatabase(
      NativeDatabase.memory(),
    );
    return _database!;
  }

  @override
  Future<void> closeDatabase() async {
    if (_database != null && !_closed) {
      await _database!.close();
      _closed = true;
      _database = null;
    }
  }
}

/// Mock database provider that can be pre-populated with data
class PrePopulatedMockDatabaseProvider extends MockDatabaseProvider {
  final List<DBTrackedFace> trackedFaces;
  final List<DBMergedFace> mergedFaces;
  final List<DBVisit> visits;

  PrePopulatedMockDatabaseProvider({
    this.trackedFaces = const [],
    this.mergedFaces = const [],
    this.visits = const [],
  });

  @override
  Future<FacesDatabase> get database async {
    final db = await super.database;

    // Pre-populate with provided data
    for (final face in trackedFaces) {
      await db.into(db.dBTrackedFaces).insert(face);
    }

    for (final mergedFace in mergedFaces) {
      await db.into(db.dBMergedFaces).insert(mergedFace);
    }

    for (final visit in visits) {
      await db.into(db.dBVisits).insert(visit);
    }

    return db;
  }
}
