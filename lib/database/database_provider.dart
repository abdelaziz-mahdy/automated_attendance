import 'dart:io';
import 'dart:async'; // Added for Completer
import 'package:automated_attendance/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Provides access to the database instance
class DatabaseProvider {
  // Singleton instance
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;
  DatabaseProvider._internal();

  // Database instance
  FacesDatabase? _database;

  // Completer to handle concurrent initialization requests
  Completer<FacesDatabase>? _dbCompleter;

  // Get database instance
  Future<FacesDatabase> get database async {
    if (_database != null) return _database!;

    // If already initializing, return the future from the completer
    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    // Create a new completer and start initialization
    _dbCompleter = Completer<FacesDatabase>();
    try {
      _database = await _initDatabase();
      _dbCompleter!.complete(_database);
      return _database!;
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null;
      rethrow;
    }
  }

  // Initialize database
  Future<FacesDatabase> _initDatabase() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'faces.sqlite'));
    return FacesDatabase(NativeDatabase(file));
  }

  // Close database
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _dbCompleter = null;
    }
  }
}
