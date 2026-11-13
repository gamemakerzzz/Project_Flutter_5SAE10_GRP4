import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// One local database for the student-facing app.
///
/// It stores courses, imported PDFs, extracted passages, and quiz attempts.
/// Authentication secrets and API keys are deliberately never stored here.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'smart_learning.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            subject TEXT NOT NULL,
            description TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE course_documents (
            id TEXT PRIMARY KEY,
            course_id TEXT NOT NULL,
            name TEXT NOT NULL,
            size INTEGER NOT NULL,
            status TEXT NOT NULL,
            uploaded_at TEXT NOT NULL,
            pages INTEGER,
            error TEXT,
            bytes BLOB NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE course_chunks (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            document_name TEXT NOT NULL,
            page INTEGER NOT NULL,
            excerpt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE attempts (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            course_id TEXT,
            score INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX attempts_course_date ON attempts(course_id, created_at DESC)',
        );
        await db.execute('CREATE INDEX chunks_course ON course_chunks(course_id)');
      },
    );
    return _database!;
  }
}
