import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_learning/features/flashcards/data/flashcard_repository.dart';
import 'package:smart_learning/features/flashcards/models/flashcard.dart';
import 'package:smart_learning/main.dart';
import 'package:smart_learning/features/flashcards/data/flashcard_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlashcardDatabase.instance = FlashcardDatabase(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await FlashcardDatabase.instance.database;
  });
  tearDown(() async => FlashcardDatabase.instance.close());
  testWidgets('Mobile layout and PDF dialog fit a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(354, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await settleDatabaseUi(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Créer depuis un PDF'));
    await settleDatabaseUi(tester);
    expect(find.text('Créer avec Claude Sonnet 5.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Annuler'));
    await settleDatabaseUi(tester);
    await tester.ensureVisible(find.text('Essayer le paquet exemple'));
    await tester.tap(find.text('Essayer le paquet exemple'));
    await settleDatabaseUi(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Example deck, reveal, rating and persisted progress', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await settleDatabaseUi(tester);
    expect(find.text('Flashcards intelligentes'), findsOneWidget);
    await tester.ensureVisible(find.text('Essayer le paquet exemple'));
    await tester.tap(find.text('Essayer le paquet exemple'));
    await settleDatabaseUi(tester);
    await tester.ensureVisible(find.text('Commencer la révision'));
    await tester.tap(find.text('Commencer la révision'));
    await settleDatabaseUi(tester);
    expect(find.text('Bien'), findsNothing);
    expect(find.text('Explain more with AI'), findsNothing);
    await tester.tap(find.text('Afficher la réponse'));
    await settleDatabaseUi(tester);
    expect(find.text('VERSO · RÉPONSE'), findsOneWidget);
    expect(find.text('Explain more with AI'), findsOneWidget);
    await tester.ensureVisible(find.text('Bien'));
    await tester.tap(find.text('Bien'));
    await settleDatabaseUi(tester);
    expect(find.text('CARTE 2 SUR 6'), findsOneWidget);
    expect(find.text('Explain more with AI'), findsNothing);
    final saved = (await tester.runAsync(() => FlashcardRepository().load()))!;
    expect(saved.single.cards.first.reviews, 1);
    expect(saved.single.cards.first.interval, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Manual cards can enter and leave focused review before due', (
    tester,
  ) async {
    Future<void> tap(String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settleDatabaseUi(tester);
    }

    await tester.pumpWidget(const MyApp());
    await settleDatabaseUi(tester);
    expect(find.text('Cartes à retravailler · 0'), findsOneWidget);
    await tap('Créer manuellement');
    await tester.enterText(find.byType(TextFormField).at(0), 'Mon paquet');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Question personnelle',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Réponse personnelle',
    );
    await tap('Créer le paquet');
    expect(find.text('Question personnelle'), findsOneWidget);
    final repo = FlashcardRepository();
    final manual = (await tester.runAsync(repo.load))!.single;
    expect(manual.mode, 'manual');
    expect(manual.cards.single.answer, 'Réponse personnelle');
    await tester.pageBack();
    await settleDatabaseUi(tester);
    await tap('Commencer la révision');
    await tap('Afficher la réponse');
    await tap('Difficile');
    await tap('Retour à mes paquets');
    expect(find.text('Cartes à retravailler · 1'), findsOneWidget);
    await tap('Réviser cette carte');
    expect(find.text('CARTE 1 SUR 1'), findsOneWidget);
    await tap('Afficher la réponse');
    expect(find.text('Explain more with AI'), findsOneWidget);
    await tap('Bien');
    expect(
      find.text('1 carte(s) retrouvée(s) • 0 à retravailler'),
      findsOneWidget,
    );
    await tap('Retour à mes paquets');
    expect(find.text('Cartes à retravailler · 0'), findsOneWidget);
    final saved = (await tester.runAsync(repo.load))!.single.cards.single;
    expect(saved.lastGrade, ReviewGrade.good);
    expect(saved.reviews, 2);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'Reviews grow intervals; forgetting resets learning and lowers ease',
    () {
      final now = DateTime(2026, 10, 14);
      final c = Flashcard(id: '1', question: 'Q', answer: 'A', due: now);
      c.review(ReviewGrade.good, now);
      expect(c.due, now.add(const Duration(days: 1)));
      c.review(ReviewGrade.good, c.due);
      expect(c.interval, 6);
      c.review(ReviewGrade.good, c.due);
      expect(c.interval, 15);
      final before = c.due;
      c.review(ReviewGrade.again, before);
      expect(c.due, before.add(const Duration(minutes: 10)));
      expect(c.mastery, 0);
      expect(c.lapses, 1);
      expect(c.ease, lessThan(2.5));
      expect(c.isDue(c.due), isTrue);
      expect(c.isDue(c.due.subtract(const Duration(seconds: 1))), isFalse);
    },
  );
  test('Easy schedules later than hard; ease and intervals are bounded', () {
    final c = Flashcard(
      id: '1',
      question: 'Q',
      answer: 'A',
      due: DateTime(2026),
    );
    expect(
      c.nextDelay(ReviewGrade.easy),
      greaterThan(c.nextDelay(ReviewGrade.hard)),
    );
    for (var i = 0; i < 30; i++) {
      c.review(ReviewGrade.again, c.due);
    }
    expect(c.ease, 1.3);
    for (var i = 0; i < 50; i++) {
      c.review(ReviewGrade.easy, c.due);
    }
    expect(c.interval, lessThanOrEqualTo(3650));
    expect(c.mastery, 100);
    expect(Flashcard.fromJson(c.toJson()).due, c.due);
  });
  test(
    'Empty stored library stays empty, and decks survive repository reload',
    () async {
      final repo = FlashcardRepository();
      expect(await repo.load(), isEmpty);
      final deck = repo.demo();
      await repo.save([deck]);
      expect((await repo.load()).single.cards.length, 6);
      await repo.save([]);
      expect(await repo.load(), isEmpty);
    },
  );
}

// SQLite performs real asynchronous I/O; let it finish outside the fake test clock.
Future<void> settleDatabaseUi(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}
