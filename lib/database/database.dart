import 'dart:typed_data';
import 'package:drift/drift.dart';
part 'database.g.dart';

// This annotation tells drift to prepare a database class that uses both tables
@DriftDatabase(tables: [DBTrackedFaces, DBMergedFaces])
class FacesDatabase extends _$FacesDatabase {
  // We tell the database where to store the data with this constructor
  FacesDatabase(QueryExecutor e) : super(e);

  // You should bump this number whenever you change or add a table definition
  @override
  int get schemaVersion => 1;

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
}

// The TrackedFaces table definition
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

  // Additional indices for faster queries
  @override
  List<Index> get indexes => [
        Index('target_id_idx', targetId),
        Index('source_id_idx', sourceId),
      ];
}
