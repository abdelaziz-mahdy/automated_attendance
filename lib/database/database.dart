import 'package:drift/drift.dart';
part 'database.g.dart';

// This annotation tells drift to prepare a database class that uses both tables
@DriftDatabase(
    tables: [DBTrackedFaces, DBMergedFaces, DBVisits, DBExpectedAttendees])
class FacesDatabase extends _$FacesDatabase {
  // We tell the database where to store the data with this constructor
  FacesDatabase(super.e);

  // You should bump this number whenever you change or add a table definition
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) {
        return m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add the new visits table
          await m.createTable(dBVisits);
        }
        if (from < 3) {
          await m.createTable(dBExpectedAttendees);
        }
      },
    );
  }

  // Helper methods to query the database
  Future<List<DBTrackedFace>> getAllTrackedFaces() {
    return select(dBTrackedFaces).get();
  }

  Future<DBTrackedFace?> getTrackedFaceById(String id) {
    return (select(dBTrackedFaces)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertTrackedFace(DBTrackedFacesCompanion face) {
    return into(dBTrackedFaces).insert(face);
  }

  Future<bool> updateTrackedFace(DBTrackedFacesCompanion face) {
    return update(dBTrackedFaces).replace(face);
  }

  Future<int> deleteTrackedFace(String id) {
    return (delete(dBTrackedFaces)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Methods for merged faces
  Future<List<DBMergedFace>> getMergedFacesForTarget(String targetId) {
    return (select(dBMergedFaces)
          ..where((tbl) => tbl.targetId.equals(targetId)))
        .get();
  }

  Future<int> insertMergedFace(DBMergedFacesCompanion mergedFace) {
    return into(dBMergedFaces).insert(mergedFace);
  }

  Future<int> deleteMergedFace(String sourceId) {
    return (delete(dBMergedFaces)
          ..where((tbl) => tbl.sourceId.equals(sourceId)))
        .go();
  }

  // Visits methods
  Future<List<DBVisit>> getVisits() => select(dBVisits).get();

  Future<List<DBVisit>> getVisitsForFace(String faceId) =>
      (select(dBVisits)..where((tbl) => tbl.faceId.equals(faceId))).get();

  Future<List<DBVisit>> getActiveVisits() =>
      (select(dBVisits)..where((tbl) => tbl.durationSeconds.isNull())).get();

  Future<int> insertVisit(DBVisitsCompanion visit) =>
      into(dBVisits).insert(visit);

  Future<bool> updateVisit(DBVisitsCompanion visit) =>
      update(dBVisits).replace(visit);

  Future<int> deleteVisitsForFace(String faceId) =>
      (delete(dBVisits)..where((tbl) => tbl.faceId.equals(faceId))).go();

  Future<List<DBVisit>> getVisitsInDateRange(DateTime start, DateTime end) =>
      (select(dBVisits)
            ..where((tbl) => tbl.entryTime.isBiggerThanValue(start))
            ..where((tbl) => tbl.entryTime.isSmallerOrEqualValue(end)))
          .get();

  // Query for visits by provider
  Future<List<DBVisit>> getVisitsByProvider(String providerId) =>
      (select(dBVisits)..where((tbl) => tbl.providerId.equals(providerId)))
          .get();

  // Methods for expected attendees
  Future<List<String>> getExpectedAttendees() {
    return select(dBExpectedAttendees).map((row) => row.faceId).get();
  }

  Future<void> addExpectedAttendee(String faceId) {
    return into(dBExpectedAttendees).insert(
      DBExpectedAttendeesCompanion.insert(faceId: faceId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeExpectedAttendee(String faceId) {
    return (delete(dBExpectedAttendees)
          ..where((tbl) => tbl.faceId.equals(faceId)))
        .go();
  }
}

// The TrackedFaces table definition
@TableIndex(name: 'face_name_idx', columns: {#name})
class DBTrackedFaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  BlobColumn get features => blob()();
  BlobColumn get thumbnail => blob().nullable()();
  DateTimeColumn get firstSeen => dateTime().nullable()();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  TextColumn get lastSeenProvider => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// The MergedFaces table definition to maintain relationships between merged faces
@TableIndex(name: 'target_id_idx', columns: {#targetId})
@TableIndex(name: 'source_id_idx', columns: {#sourceId})
class DBMergedFaces extends Table {
  TextColumn get id => text()();
  TextColumn get targetId => text().references(DBTrackedFaces, #id)();
  TextColumn get sourceId => text()();

  /// features are list of doubles
  BlobColumn get features => blob()();
  BlobColumn get thumbnail => blob().nullable()();
  DateTimeColumn get firstSeen => dateTime().nullable()();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// New table to track individual visits/appearances
@DataClassName('DBVisit')
class DBVisits extends Table {
  TextColumn get id => text()(); // Visit ID
  TextColumn get faceId => text().nullable()(); // Reference to tracked face
  DateTimeColumn get entryTime => dateTime()(); // When the face entered
  DateTimeColumn get exitTime =>
      dateTime().nullable()(); // When the face exited (null if still present)
  TextColumn get providerId => text()(); // Provider that detected the face
  IntColumn get durationSeconds =>
      integer().nullable()(); // Duration in seconds (calculated on exit)

  @override
  Set<Column> get primaryKey => {id};
}

// New table to track expected attendees
@DataClassName('DBExpectedAttendee')
class DBExpectedAttendees extends Table {
  TextColumn get faceId => text().references(DBTrackedFaces, #id)();

  @override
  Set<Column> get primaryKey => {faceId};
}
