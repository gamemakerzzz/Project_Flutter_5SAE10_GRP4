import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_learning/features/flashcards/data/flashcard_database.dart';
import 'package:smart_learning/features/flashcards/data/flashcard_repository.dart';
import 'package:smart_learning/features/flashcards/models/flashcard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String dbPath;
  late FlashcardDatabase store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'flashcards-sqlite-test-',
    );
    dbPath = '${directory.path}/cards.db';
    store = FlashcardDatabase(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: dbPath,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'SQLite persists generated decks and review schedules across connections',
    () async {
      final repo = FlashcardRepository(database: store);
      final deck = repo.demo();
      deck.cards.first.review(ReviewGrade.easy, DateTime(2026, 11, 12));
      await repo.save([deck]);
      final db = await store.database;
      expect((await db.query('decks')).length, 1);
      expect((await db.query('cards')).length, 6);
      await store.close();
      final restored = await repo.load();
      expect(restored.single.cards.first.due, deck.cards.first.due);
      expect(restored.single.cards.first.reviews, 1);
      expect(restored.single.cards.first.interval, 4);
      expect(restored.single.cards.first.question, deck.cards.first.question);
    },
  );

  test('Version 1 upgrades without losing cards or guessing grades', () async {
    final deck = FlashcardRepository(database: store).demo();
    deck.cards.first.review(ReviewGrade.hard, DateTime(2026, 11, 12));
    await store.save([deck]);
    final db = await store.database;
    await db.execute('ALTER TABLE cards DROP COLUMN last_grade');
    await db.setVersion(1);
    await store.close();

    final restored = (await store.load()).single;
    expect(restored.cards.length, deck.cards.length);
    final card = restored.cards.first;
    expect(card.due, deck.cards.first.due);
    expect(card.lastGrade, isNull);
    expect(card.reviews, 1);
    card.review(ReviewGrade.hard, DateTime(2026, 11, 13));
    await store.save([restored]);
    await store.close();
    expect((await store.load()).single.cards.first.needsPractice, isTrue);
  });

  test('Legacy decks migrate once and deleted decks do not reappear', () async {
    final deck = FlashcardRepository(database: store).demo();
    SharedPreferences.setMockInitialValues({
      FlashcardDatabase.legacyKey: jsonEncode([deck.toJson()]),
    });
    expect((await store.load()).single.id, deck.id);
    await store.save([]);
    await store.close();
    expect(await store.load(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        FlashcardDatabase.legacyKey,
      ),
      isNotNull,
    );
  });

  test('Failed write rolls back the whole deck and card transaction', () async {
    final deck = FlashcardRepository(database: store).demo();
    await store.save([deck]);
    final original = deck.cards.first.question;
    deck.cards.first.question = 'Changed';
    deck.cards.add(
      deck.cards.first,
    ); // Duplicate primary key must reject the transaction.
    await expectLater(store.save([deck]), throwsA(isA<DatabaseException>()));
    final saved = await store.load();
    expect(saved.single.cards.length, 6);
    expect(saved.single.cards.first.question, original);
  });

  test('Corrupt legacy data is retained and can be recovered without database loss', () async {
    SharedPreferences.setMockInitialValues({
      FlashcardDatabase.legacyKey: '{broken',
    });
    await expectLater(store.load(), throwsFormatException);
    expect(
      (await SharedPreferences.getInstance()).getString(
        FlashcardDatabase.legacyKey,
      ),
      '{broken',
    );
    SharedPreferences.setMockInitialValues({FlashcardDatabase.legacyKey: '[]'});
    expect(await store.load(), isEmpty);
  });
}
