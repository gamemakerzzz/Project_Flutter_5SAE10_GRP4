import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase(String directory, {String migrations = 'migrations'}) {
    Directory(directory).createSync(recursive: true);
    db = sqlite3.open(p.join(directory, 'studymate.db'));
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA busy_timeout=5000');
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 2) {
      throw StateError('Database schema is newer than this server.');
    }
    if (version == 0) {
      transaction(() {
        db.execute(
          File(p.join(migrations, '001_initial.sql')).readAsStringSync(),
        );
        db.execute('PRAGMA user_version=1');
      });
    }
    if (version < 2) {
      transaction(() {
        db.execute(
          File(p.join(migrations, '002_embeddings.sql')).readAsStringSync(),
        );
        db.execute('PRAGMA user_version=2');
      });
    }
    try {
      db.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(content, content='document_chunks', content_rowid='rowid')",
      );
      db.execute(
        "CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON document_chunks BEGIN INSERT INTO chunk_fts(rowid,content) VALUES(new.rowid,new.content); END",
      );
      db.execute(
        "CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON document_chunks BEGIN INSERT INTO chunk_fts(chunk_fts,rowid,content) VALUES('delete',old.rowid,old.content); END",
      );
      db.execute("INSERT INTO chunk_fts(chunk_fts) VALUES('rebuild')");
      fts = true;
    } on SqliteException {
      fts = false;
    }
  }
  late final Database db;
  bool fts = false;
  T transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => db.close();
}
