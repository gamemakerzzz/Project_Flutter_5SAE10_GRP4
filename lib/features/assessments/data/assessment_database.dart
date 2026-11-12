import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/assessment.dart';

abstract interface class AssessmentStore {
  Future<List<AssessmentResult>> loadAttempts();
  Future<void> saveAttempt(AssessmentResult result);
  Future<void> close();
}

/// Local SQLite storage for attempts. It intentionally stores no API keys.
class AssessmentDatabase implements AssessmentStore {
  AssessmentDatabase({this.factory});

  final DatabaseFactory? factory;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final activeFactory = factory ?? databaseFactory;
    final databasesPath = await activeFactory.getDatabasesPath();
    _database = await activeFactory.openDatabase(
      path.join(databasesPath, 'smart_learning_assessments.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE attempts (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            score INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        '''),
      ),
    );
    return _database!;
  }

  @override
  Future<List<AssessmentResult>> loadAttempts() async {
    final database = await _db;
    final rows = await database.query('attempts', orderBy: 'created_at DESC');
    return rows
        .map(
          (row) => AssessmentResult.fromJson(
            Map<String, dynamic>.from(jsonDecode(row['payload']! as String) as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveAttempt(AssessmentResult result) async {
    final database = await _db;
    await database.insert('attempts', {
      'id': result.id,
      'created_at': result.date.toIso8601String(),
      'score': result.percentage,
      'payload': jsonEncode(result.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

/// Used by widget/unit tests. Production screens use [AssessmentDatabase].
class InMemoryAssessmentStore implements AssessmentStore {
  final List<AssessmentResult> _attempts = [];

  @override
  Future<List<AssessmentResult>> loadAttempts() async => List.of(_attempts);

  @override
  Future<void> saveAttempt(AssessmentResult result) async {
    _attempts.removeWhere((attempt) => attempt.id == result.id);
    _attempts.insert(0, result);
  }

  @override
  Future<void> close() async {}
}
