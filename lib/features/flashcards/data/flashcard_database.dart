import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/flashcard.dart';
import 'database_factory.dart';

/// Relational SQLite storage. SharedPreferences is read only for one-time migration.
class FlashcardDatabase {
  FlashcardDatabase({this.factory, this.databasePath});
  static FlashcardDatabase instance = FlashcardDatabase();
  static const legacyKey = 'smart_learning.flashcards.v1';
  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open().catchError((Object e) {
    _opening = null;
    throw e;
  });

  Future<Database> _open() async {
    final selectedFactory = factory ?? flashcardDatabaseFactory();
    final db = await selectedFactory.openDatabase(
      databasePath ??
          path.join(
            await selectedFactory.getDatabasesPath(),
            'smart_learning_flashcards.db',
          ),
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE cards ADD COLUMN last_grade TEXT');
          }
        },
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            '''CREATE TABLE decks (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL,
            mode TEXT NOT NULL, color INTEGER NOT NULL, position INTEGER NOT NULL)''',
          );
          await db.execute('''CREATE TABLE cards (
            id TEXT PRIMARY KEY, deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
            question TEXT NOT NULL, answer TEXT NOT NULL, page INTEGER,
            due TEXT NOT NULL, interval INTEGER NOT NULL, ease REAL NOT NULL,
            repetitions INTEGER NOT NULL, reviews INTEGER NOT NULL, lapses INTEGER NOT NULL,
            last_grade TEXT, position INTEGER NOT NULL)''');
          await db.execute('CREATE INDEX cards_due_idx ON cards(due)');
          await db.execute(
            'CREATE INDEX cards_deck_idx ON cards(deck_id, position)',
          );
        },
      ),
    );
    try {
      await _migrate(db);
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> _migrate(Database db) async {
    if ((await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['legacy_migrated'],
    )).isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(legacyKey);
    // Parse before any write: malformed legacy data is preserved for recovery.
    final oldDecks = raw == null
        ? <Deck>[]
        : (jsonDecode(raw) as List).map((j) => Deck.fromJson(j)).toList();
    await db.transaction((txn) async {
      if ((await txn.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['legacy_migrated'],
      )).isNotEmpty) {
        return;
      }
      if ((await txn.query('decks', limit: 1)).isEmpty) {
        await _write(txn, oldDecks);
      }
      await txn.insert('metadata', {'key': 'legacy_migrated', 'value': '1'});
    });
    // Keep the old key as a recovery copy; marker prevents deleted decks returning.
  }

  Future<List<Deck>> load() async {
    final db = await database;
    return db.transaction((txn) async {
      final decks = await txn.query('decks', orderBy: 'position');
      final cards = await txn.query('cards', orderBy: 'position');
      return [
        for (final row in decks)
          Deck.fromJson({
            ...row,
            'cards': cards.where((c) => c['deck_id'] == row['id']).toList(),
          }),
      ];
    });
  }

  Future<void> save(List<Deck> decks) async {
    final db = await database;
    await db.transaction((txn) => _write(txn, decks));
  }

  Future<void> _write(DatabaseExecutor txn, List<Deck> decks) async {
    await txn.delete('cards');
    await txn.delete('decks');
    final batch = txn.batch();
    for (var d = 0; d < decks.length; d++) {
      final deck = decks[d];
      batch.insert('decks', {
        'id': deck.id,
        'title': deck.title,
        'source': deck.source,
        'mode': deck.mode,
        'color': deck.color,
        'position': d,
      });
      for (var c = 0; c < deck.cards.length; c++) {
        batch.insert('cards', {
          ...deck.cards[c].toJson(),
          'deck_id': deck.id,
          'position': c,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) await (await pending).close();
    _opening = null;
  }
}
