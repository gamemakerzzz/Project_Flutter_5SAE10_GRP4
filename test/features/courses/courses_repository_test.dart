import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_learning/features/courses/data/courses_api_service.dart';
import 'package:smart_learning/features/courses/data/local_courses_repository.dart';
import 'package:smart_learning/features/courses/data/pdf_import_service.dart';
import 'package:smart_learning/features/courses/models/course_models.dart';

class FakeExtractor implements PdfTextExtractor {
  FakeExtractor(this.text);
  List<String> text;
  @override
  Future<List<String>> pages(Uint8List bytes) async => text;
}

SelectedPdf sample([String name = 'lesson.pdf']) =>
    SelectedPdf(name, Uint8List.fromList(utf8.encode('%PDF-1.7 test')));
Future<Course> addCourse(LocalCoursesRepository repo, String title) =>
    repo.saveCourse(
      title: title,
      subject: courseSubjects.first,
      description: 'Test course',
    );

void main() {
  test(
    'Index limits preserve their explanation instead of blaming PDF size',
    () async {
      final api = CoursesApiService(
        baseUri: Uri.parse('https://courses.example'),
        tokenProvider: () async => 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'INDEX_LIMIT',
              'message': 'A course can contain at most 5,000 passages.',
            }),
            413,
          ),
        ),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.search('course', 'question'),
        throwsA(
          isA<CoursesException>().having(
            (e) => e.message,
            'message',
            contains('5,000 passages'),
          ),
        ),
      );
    },
  );
  test('closed API sessions do not request tokens or send requests', () async {
    var tokenRequested = false;
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async {
        tokenRequested = true;
        return 'token';
      },
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    api.dispose();
    await expectLater(api.listCourses(), throwsA(isA<CoursesException>()));
    expect(tokenRequested, false);
  });

  test('course validation errors retain the server explanation', () async {
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Title must not be empty.'}),
          400,
        ),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.saveCourse(title: '', subject: 'AI', description: ''),
      throwsA(
        isA<CoursesException>().having(
          (error) => error.message,
          'message',
          'Title must not be empty.',
        ),
      ),
    );
  });
  test(
    'PDF validation rejects extension, empty, oversized and non-PDF bytes',
    () {
      expect(
        () => PdfValidation.validate(sample('lesson.txt')),
        throwsA(isA<CoursesException>()),
      );
      expect(
        () => PdfValidation.metadata('lesson.pdf', 0),
        throwsA(isA<CoursesException>()),
      );
      expect(
        () => PdfValidation.metadata('lesson.pdf', PdfValidation.maxBytes + 1),
        throwsA(isA<CoursesException>()),
      );
      expect(
        () => PdfValidation.validate(
          SelectedPdf('fake.pdf', Uint8List.fromList([1, 2, 3])),
        ),
        throwsA(isA<CoursesException>()),
      );
      expect(
        () => PdfValidation.validate(sample('LESSON.PDF')),
        returnsNormally,
      );
    },
  );
  test(
    'Import, actual page metadata, exact excerpts, duplicate and deletion',
    () async {
      final pages = [
        'Neural networks learn weights from examples.',
        'Supervised learning uses labelled examples.',
      ];
      final repo = LocalCoursesRepository(extractor: FakeExtractor(pages));
      final c = await addCourse(repo, 'Learning');
      final doc = await repo.upload(c.id, sample());
      expect(doc.status, ProcessingStatus.uploaded);
      await repo.process(doc.id);
      expect(
        (await repo.documents(c.id)).single.status,
        ProcessingStatus.ready,
      );
      final results = await repo.search(c.id, 'supervised learning');
      expect(results.first.page, 2);
      expect(results.first.excerpt, pages[1]);
      expect(results.first.documentId, doc.id);
      expect(results.first.chunkId, contains(':p2:'));
      expect(
        () => repo.upload(c.id, sample()),
        throwsA(isA<CoursesException>()),
      );
      await repo.deleteDocument(doc.id);
      expect(await repo.search(c.id, 'supervised learning'), isEmpty);
      expect(() => repo.content(doc.id), throwsA(isA<CoursesException>()));
    },
  );
  test('Sources stay in their course and unavailable answers have no invented citations', () async {
    final repo = LocalCoursesRepository(
      extractor: FakeExtractor([
        'Oracle database architecture includes an instance.',
      ]),
    );
    final a = await addCourse(repo, 'DBA');
    final b = await addCourse(repo, 'Mobile');
    final doc = await repo.upload(a.id, sample());
    await repo.process(doc.id);
    expect(await repo.search(b.id, 'Oracle'), isEmpty);
    final answer = await repo.ask(a.id, 'quantum entanglement');
    expect(answer.sources, isEmpty);
    expect(answer.generated, isFalse);
    final evidence = await repo.ask(a.id, 'Oracle');
    expect(evidence.generated, isFalse);
    expect(evidence.sources.single.documentId, doc.id);
  });
  test('Scanned PDFs fail explicitly and retry can recover', () async {
    final extractor = FakeExtractor(['', '   ']);
    final repo = LocalCoursesRepository(extractor: extractor);
    final course = await addCourse(repo, 'Scans');
    final doc = await repo.upload(course.id, sample());
    await repo.process(doc.id);
    expect(
      (await repo.documents(course.id)).single.status,
      ProcessingStatus.failed,
    );
    expect((await repo.documents(course.id)).single.error, contains('OCR'));
    extractor.text = ['Recovered selectable text.'];
    await repo.process(doc.id);
    expect(
      (await repo.documents(course.id)).single.status,
      ProcessingStatus.ready,
    );
  });
  test('Chunks preserve page and text boundaries without missing words', () {
    final text = List.generate(400, (i) => 'word$i').join(' ');
    final doc = CourseDocument(
      id: 'd',
      courseId: 'c',
      name: 'long.pdf',
      size: 1,
      status: ProcessingStatus.uploaded,
      uploadedAt: DateTime(2026),
    );
    final chunks = chunkPages(doc, ['', text]);
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((c) => c.page == 2 && c.excerpt.length <= 900), isTrue);
    expect(chunks.map((c) => c.excerpt).join(' '), text);
    final unicode = '${'a' * 899}\u{1f600}end';
    final unicodeChunks = chunkPages(doc, [unicode]);
    expect(unicodeChunks.map((c) => c.excerpt).join(), unicode);
    for (final chunk in unicodeChunks) {
      expect(utf8.decode(utf8.encode(chunk.excerpt)), chunk.excerpt);
    }
  });
  test('API refuses missing real auth before any request', () async {
    var calls = 0;
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => null,
      client: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    await expectLater(api.listCourses(), throwsA(isA<CoursesException>()));
    expect(calls, 0);
    api.dispose();
  });
  test('API upload rejection never becomes a successful document', () async {
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('too big', 413);
      }),
    );
    await expectLater(
      api.upload('1', sample()),
      throwsA(isA<CoursesException>()),
    );
    api.dispose();
  });
  test('API rejects citation to a document outside the course', () async {
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => 'test-token',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/index')
                ? {'state': 'ready'}
                : request.url.path.endsWith('/search')
                ? [
                    {
                      'chunkId': 'x',
                      'documentId': 'private',
                      'courseId': '1',
                      'documentName': 'private.pdf',
                      'page': 1,
                      'excerpt': 'Unrelated text',
                    },
                  ]
                : [],
          ),
          200,
        ),
      ),
    );
    await expectLater(
      api.search('1', 'query'),
      throwsA(isA<CoursesException>()),
    );
    api.dispose();
  });
  test('API requests PDF bytes with the correct accept header', () async {
    final bytes = sample().bytes;
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        expect(request.headers['Accept'], 'application/pdf');
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
    expect(await api.content('1'), bytes);
    api.dispose();
  });
  test('connected search requests semantic retrieval and RAG preserves numbered citations', () async {
    final source = {
      'chunkId': 'chunk',
      'documentId': 'doc',
      'courseId': 'course',
      'documentName': 'lecture.pdf',
      'page': 2,
      'excerpt': 'Learning without labels.',
      'sourceNumber': 1,
    };
    final api = CoursesApiService(
      baseUri: Uri.parse('https://courses.example'),
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        Object data;
        if (request.url.path.endsWith('/index')) {
          data = {'state': 'ready'};
        } else if (request.url.path.endsWith('/documents')) {
          data = [
            {
              'id': 'doc',
              'courseId': 'course',
              'name': 'lecture.pdf',
              'size': 123,
              'status': 'ready',
              'uploadedAt': '2026-10-29T12:00:00Z',
              'pages': 2,
            },
          ];
        } else if (request.url.path.endsWith('/search')) {
          expect(jsonDecode(request.body)['mode'], 'semantic');
          data = [source];
        } else {
          data = {
            'answer': 'It learns without labels [1].',
            'sources': [source],
            'generated': true,
          };
        }
        return http.Response(jsonEncode(data), 200);
      }),
    );
    expect((await api.search('course', 'discover groups')).single.page, 2);
    final answer = await api.ask('course', 'Explain');
    expect(answer.generated, true);
    expect(answer.sources.single.sourceNumber, 1);
    api.dispose();
  });
  test(
    'index failure surfaces its error instead of returning a fake answer',
    () async {
      final api = CoursesApiService(
        baseUri: Uri.parse('https://courses.example'),
        tokenProvider: () async => 'token',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({'state': 'failed', 'error': 'Ollama is not running.'}),
            200,
          ),
        ),
      );
      await expectLater(
        api.ask('course', 'Explain'),
        throwsA(
          isA<CoursesException>().having(
            (e) => e.message,
            'message',
            contains('Ollama'),
          ),
        ),
      );
      api.dispose();
    },
  );
}
