import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'database.dart';

/// Provides a singleton instance of the faces database
class DatabaseProvider {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;
  DatabaseProvider._internal();

  FacesDatabase? _database;

  Future<FacesDatabase> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<FacesDatabase> _initDatabase() async {
    // Make sure that the sqlite3 library can be loaded
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    // Get a location for storing the database
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'faces.db'));

    return FacesDatabase(NativeDatabase(file));
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
