import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studymate_backend/src/database/database.dart';
import 'package:studymate_backend/src/http/api_error.dart';
import 'package:studymate_backend/src/repositories/store.dart';
import 'package:studymate_backend/src/services/rag_contracts.dart';
import 'package:studymate_backend/src/services/rag_service.dart';

// Deterministic vectors test orchestration, not model quality. See bin/verify_rag.dart
// for the opt-in test using real Ollama embeddings and generated answers.
class TestProvider implements RagProvider {
  @override
  String embeddingKey = 'test-model-v1';
  @override
  String get chatModel => 'test-chat';
  int documentEmbeds = 0, generations = 0;
  bool unavailable = false;
  Completer<void>? holdEmbedding, holdAnswer;
  Json? answer;
  @override
  Future<void> checkReady() async {
    if (unavailable) {
      throw const ApiError(503, 'AI_UNAVAILABLE', 'Model missing');
    }
  }

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool query,
  }) async {
    if (!query) {
      documentEmbeds += texts.length;
      await holdEmbedding?.future;
    }
    return texts
        .map((t) => t.contains('planets') ? <double>[0, 1] : <double>[1, 0])
        .toList();
  }

  @override
  Future<Json> generate(String question, List<Json> sources) async {
    generations++;
    await holdAnswer?.future;
    return answer ??
        {
          'supported': true,
          'answer': 'A model learns from labeled examples [1].',
          'citations': [
            {'source': 1, 'quote': 'learns from labeled examples'},
          ],
        };
  }

  @override
  void close() {}
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late Store store;
  late TestProvider provider;
  late RagService rag;
  void seed(String user, String course, String doc, String chunk, String text) {
    store.execute('INSERT OR IGNORE INTO users VALUES(?,?,?,?,?,?,?,?)', [
      user,
      'Student',
      '$user@example.com',
      'hash',
      'L3',
      'AI',
      'now',
      'now',
    ]);
    store.execute('INSERT INTO courses VALUES(?,?,?,?,?,?,?)', [
      course,
      user,
      'ML',
      'AI',
      '',
      'now',
      'now',
    ]);
    store.execute('INSERT INTO documents VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)', [
      doc,
      course,
      'lecture.pdf',
      '$doc.pdf',
      '$doc.pdf',
      'application/pdf',
      42,
      doc,
      'ready',
      1,
      null,
      'now',
      'now',
    ]);
    store.execute('INSERT INTO document_chunks VALUES(?,?,?,?,?,?)', [
      chunk,
      doc,
      1,
      0,
      text,
      'now',
    ]);
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('studymate-rag-test-');
    db = AppDatabase(temp.path);
    store = Store(db);
    provider = TestProvider();
    rag = RagService(store, provider);
    seed(
      'alice',
      'course-a',
      'doc-a',
      'chunk-a',
      'Supervised learning learns from labeled examples.',
    );
    seed(
      'bob',
      'course-b',
      'doc-b',
      'chunk-b',
      'Private material learns from labeled examples.',
    );
  });
  tearDown(() async {
    await rag.close();
    db.close();
    temp.deleteSync(recursive: true);
  });
  Future<void> index() async {
    rag.enqueue('alice', 'course-a');
    await rag.tail;
    expect(rag.status('alice', 'course-a')['state'], 'ready');
  }

  Matcher code(String code) =>
      isA<ApiError>().having((e) => e.code, 'code', code);

  test('semantic ranking, ownership and index reuse across restart', () async {
    await index();
    final hits = await rag.search('alice', {
      'courseId': 'course-a',
      'query': 'apprentissage guide',
    });
    expect(hits.single['chunkId'], 'chunk-a');
    expect(hits.single['page'], 1);
    expect(provider.documentEmbeds, 1);
    await expectLater(
      rag.search('bob', {'courseId': 'course-a', 'query': 'x'}),
      throwsA(code('NOT_FOUND')),
    );
    expect(() => rag.status('bob', 'course-a'), throwsA(code('NOT_FOUND')));
    await rag.close();
    db.close();
    db = AppDatabase(temp.path);
    store = Store(db);
    rag = RagService(store, provider);
    await index();
    expect(provider.documentEmbeds, 1);
    provider.embeddingKey = 'test-model-v2';
    await index();
    expect(provider.documentEmbeds, 2);
    store.execute('DELETE FROM documents WHERE id=?', ['doc-a']);
    expect(store.rows('SELECT * FROM chunk_embeddings'), isEmpty);
  });

  test(
    'generated answer returns exact persisted sources and source numbers',
    () async {
      await index();
      final result = await rag.ask('alice', {
        'courseId': 'course-a',
        'question': 'Explain supervised learning',
      });
      expect(result['generated'], true);
      expect(result['sources'].single['sourceNumber'], 1);
      expect(
        result['sources'].single['excerpt'],
        'Supervised learning learns from labeled examples.',
      );
    },
  );

  test(
    'unrelated question and unsupported answer do not fabricate evidence',
    () async {
      await index();
      final result = await rag.ask('alice', {
        'courseId': 'course-a',
        'question': 'planets',
      });
      expect(result['generated'], false);
      expect(result['sources'], isEmpty);
      expect(provider.generations, 0);
      provider.answer = {
        'supported': false,
        'answer': 'Made up',
        'citations': [],
      };
      expect(
        (await rag.ask('alice', {
          'courseId': 'course-a',
          'question': 'x',
        }))['generated'],
        false,
      );
    },
  );

  test('invented quotations, foreign source numbers and uncited claims are refused', () async {
    await index();
    for (final answer in [
      {
        'supported': true,
        'answer': 'Answer [1]',
        'citations': [
          {'source': 1, 'quote': 'invented passage'},
        ],
      },
      {
        'supported': true,
        'answer': 'Answer [2]',
        'citations': [
          {'source': 2, 'quote': 'learns from labeled examples'},
        ],
      },
      {
        'supported': true,
        'answer': 'Answer [9]',
        'citations': [
          {'source': 1, 'quote': 'learns from labeled examples'},
        ],
      },
      {
        'supported': true,
        'answer': 'Answer [9999999999999999999999999999999999999999]',
        'citations': [
          {'source': 1, 'quote': 'learns from labeled examples'},
        ],
      },
      {
        'supported': true,
        'answer': 'Answer without citation',
        'citations': [
          {'source': 1, 'quote': 'learns from labeled examples'},
        ],
      },
    ]) {
      provider.answer = answer;
      final result = await rag.ask('alice', {
        'courseId': 'course-a',
        'question': 'x',
      });
      expect(result['generated'], false);
      expect(result['sources'], isEmpty);
    }
  });

  test('deleting a PDF during generation cannot return its citation', () async {
    await index();
    provider.holdAnswer = Completer<void>();
    final pending = rag.ask('alice', {'courseId': 'course-a', 'question': 'x'});
    while (provider.generations == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    store.execute('DELETE FROM documents WHERE id=?', ['doc-a']);
    provider.holdAnswer!.complete();
    expect((await pending)['generated'], false);
  });

  test(
    'deletion during embedding cannot recreate a document or vector',
    () async {
      provider.holdEmbedding = Completer<void>();
      rag.enqueue('alice', 'course-a');
      while (provider.documentEmbeds == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      store.execute('DELETE FROM documents WHERE id=?', ['doc-a']);
      provider.holdEmbedding!.complete();
      await rag.tail;
      expect(store.rows('SELECT * FROM chunk_embeddings'), isEmpty);
    },
  );

  test('indexing failure is explicit and retry resumes successfully', () async {
    provider.unavailable = true;
    rag.enqueue('alice', 'course-a');
    await rag.tail;
    expect(rag.status('alice', 'course-a')['state'], 'failed');
    expect(rag.status('alice', 'course-a')['error'], 'Model missing');
    provider.unavailable = false;
    await index();
  });
  test(
    'schema one upgrades without replacing accounts and remains reopenable',
    () {
      final legacyDir = Directory('${temp.path}/legacy')..createSync();
      final legacy = sqlite3.open('${legacyDir.path}/studymate.db');
      legacy.execute(File('migrations/001_initial.sql').readAsStringSync());
      legacy.execute('PRAGMA user_version=1');
      legacy.execute('INSERT INTO users VALUES(?,?,?,?,?,?,?,?)', [
        'existing',
        'Existing Student',
        'existing@example.com',
        'hash',
        'L3',
        'AI',
        'now',
        'now',
      ]);
      legacy.close();
      var upgraded = AppDatabase(legacyDir.path);
      expect(upgraded.db.select('PRAGMA user_version').single.values.single, 2);
      expect(
        upgraded.db.select('SELECT id FROM users').single['id'],
        'existing',
      );
      expect(upgraded.db.select('SELECT * FROM chunk_embeddings'), isEmpty);
      upgraded.close();
      upgraded = AppDatabase(legacyDir.path);
      expect(
        upgraded.db.select('SELECT id FROM users').single['id'],
        'existing',
      );
      upgraded.close();
    },
  );
}
