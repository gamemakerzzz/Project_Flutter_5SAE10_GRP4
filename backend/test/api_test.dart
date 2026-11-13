import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:studymate_backend/src/config/config.dart';
import 'package:studymate_backend/src/http/application.dart';
import 'package:studymate_backend/src/services/pdf_service.dart';

import '../../test/features/courses/pdf_fixture.dart';

void main() {
  late Directory temp;
  late Application app;
  late HttpServer server;
  late Uri base;
  const secret = 'test-only-secret-32-characters-minimum';
  Future<void> start() async {
    app = Application(
      Config(
        secret: secret,
        dataDirectory: '${temp.path}/data',
        pdfDirectory: '${temp.path}/pdfs',
      ),
    );
    server = await serve(app.handle, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  }

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('studymate-test-');
    await start();
  });
  tearDown(() async {
    await server.close(force: true);
    await app.close();
    temp.deleteSync(recursive: true);
  });
  Future<http.Response> request(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request(method, base.resolve(path));
      if (token != null) req.headers['authorization'] = 'Bearer $token';
      if (body != null) {
        req.headers['content-type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return await http.Response.fromStream(await client.send(req));
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> data(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> register(String email) async {
    final r = await request(
      'POST',
      '/api/auth/register',
      body: {
        'fullName': 'Test Student',
        'email': email,
        'password': 'TestPassword123!',
        'academicLevel': 'Bachelor 3',
        'specialty': 'Computer Science',
        'subjects': ['AI'],
      },
    );
    expect(r.statusCode, 201, reason: r.body);
    return data(r);
  }

  Future<http.Response> upload(
    String token,
    String course,
    List<int> bytes, {
    String name = 'test.pdf',
  }) async {
    final req =
        http.MultipartRequest(
            'POST',
            base.resolve('/api/courses/$course/documents'),
          )
          ..headers['authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: name),
          );
    return http.Response.fromStream(await req.send());
  }

  test(
    'migration, auth normalization, password hashing, JWT and profile',
    () async {
      expect(
        app.database.db.select('PRAGMA user_version').first.values.first,
        2,
      );
      final user = await register('TEST@example.com');
      final token = user['accessToken'] as String;
      expect(user['user']['email'], 'test@example.com');
      expect(
        app.store
            .rows('SELECT password_hash FROM users')
            .first['password_hash'],
        startsWith(r'$2'),
      );
      expect(
        (await request(
          'POST',
          '/api/auth/register',
          body: {
            'fullName': 'Test',
            'email': 'test@example.com',
            'password': 'TestPassword123!',
            'academicLevel': 'B3',
            'specialty': 'CS',
          },
        )).statusCode,
        409,
      );
      expect(
        (await request(
          'POST',
          '/api/auth/login',
          body: {'email': 'test@example.com', 'password': 'wrongpassword'},
        )).statusCode,
        401,
      );
      expect(
        (await request(
          'POST',
          '/api/auth/login',
          body: {'email': 'test@example.com', 'password': 'TestPassword123!'},
        )).statusCode,
        200,
      );
      expect((await request('GET', '/api/users/me')).statusCode, 401);
      expect(
        (await request(
          'GET',
          '/api/users/me',
          token: '$token-invalid',
        )).statusCode,
        401,
      );
      final expired = JWT(
        {},
        subject: user['user']['id'],
        issuer: 'studymate',
      ).sign(SecretKey(secret), expiresIn: const Duration(seconds: -1));
      expect(
        (await request('GET', '/api/users/me', token: expired)).statusCode,
        401,
      );
      final update = await request(
        'PUT',
        '/api/users/me',
        token: token,
        body: {
          'fullName': 'Updated Name',
          'academicLevel': 'Master 1',
          'specialty': 'Data Science',
          'subjects': ['Cloud'],
        },
      );
      expect(data(update)['subjects'], ['Cloud']);
      expect(
        data(await request('GET', '/api/users/me', token: token))['fullName'],
        'Updated Name',
      );
    },
  );
  test('course ownership, PDF processing, exact search, download and restart persistence', () async {
    final a = await register('a@example.com'),
        b = await register('b@example.com');
    final token = a['accessToken'] as String,
        other = b['accessToken'] as String;
    final created = await request(
      'POST',
      '/api/courses',
      token: token,
      body: {'title': 'ML', 'subject': 'AI', 'description': 'Course'},
    );
    expect(created.statusCode, 201);
    final id = data(created)['id'] as String;
    expect(
      (await request('GET', '/api/courses/$id', token: other)).statusCode,
      404,
    );
    expect(
      (await request(
        'PUT',
        '/api/courses/$id',
        token: token,
        body: {'title': 'Machine Learning', 'subject': 'AI', 'description': ''},
      )).statusCode,
      200,
    );
    final bytes = coursePdfFixture();
    final uploaded = await upload(token, id, bytes);
    expect(uploaded.statusCode, 201, reason: uploaded.body);
    final doc = data(uploaded)['id'] as String;
    await app.courses.tail;
    expect(
      data(
        await request('GET', '/api/documents/$doc/status', token: token),
      )['status'],
      'ready',
    );
    expect(app.store.rows('SELECT * FROM document_chunks').length, 2);
    expect((await upload(token, id, bytes)).statusCode, 409);
    expect((await upload(other, id, bytes)).statusCode, 404);
    expect(
      (await request(
        'GET',
        '/api/documents/$doc/content',
        token: other,
      )).statusCode,
      404,
    );
    expect(
      (await request(
        'GET',
        '/api/documents/$doc/content',
        token: token,
      )).bodyBytes,
      bytes,
    );
    final search = await request(
      'POST',
      '/api/courses/search',
      token: token,
      body: {'courseId': id, 'query': 'patterns', 'topK': 5},
    );
    final hits = jsonDecode(search.body) as List;
    expect(hits.single['page'], 2);
    expect(
      hits.single['excerpt'],
      'Unsupervised learning discovers patterns without labels.',
    );
    expect(
      (await request(
        'POST',
        '/api/courses/search',
        token: other,
        body: {'courseId': id, 'query': 'patterns'},
      )).statusCode,
      404,
    );
    expect(
      (await request(
        'POST',
        '/api/rag/ask',
        token: token,
        body: {'courseId': id, 'question': 'Explain'},
      )).statusCode,
      501,
    );
    await server.close(force: true);
    await app.close();
    await start();
    expect(
      (jsonDecode(
        (await request('GET', '/api/courses', token: token)).body,
      ) as List).length,
      1,
    );
    expect(
      (await request(
        'GET',
        '/api/documents/$doc/content',
        token: token,
      )).bodyBytes,
      bytes,
    );
    expect(
      (jsonDecode(
        (await request(
          'POST',
          '/api/courses/search',
          token: token,
          body: {'courseId': id, 'query': 'patterns'},
        )).body,
      ) as List).single['page'],
      2,
    );
    expect(
      (await request('DELETE', '/api/courses/$id', token: other)).statusCode,
      404,
    );
    expect(
      (await request('DELETE', '/api/courses/$id', token: token)).statusCode,
      204,
    );
    expect(app.store.rows('SELECT * FROM document_chunks'), isEmpty);
    expect(Directory('${temp.path}/pdfs').listSync(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
  test(
    'PDF validation, failed extraction, retry and document deletion',
    () async {
      final token =
          (await register('pdf@example.com'))['accessToken'] as String;
      final id =
          data(
                await request(
                  'POST',
                  '/api/courses',
                  token: token,
                  body: {'title': 'PDF', 'subject': 'AI'},
                ),
              )['id']
              as String;
      expect((await upload(token, id, [1, 2, 3])).statusCode, 400);
      expect(
        (await upload(
          token,
          id,
          coursePdfFixture(),
          name: 'bad.txt',
        )).statusCode,
        400,
      );
      expect(
        (await upload(
          token,
          id,
          List.filled(20 * 1024 * 1024 + 1, 0),
        )).statusCode,
        413,
      );
      final result = await upload(token, id, utf8.encode('%PDF-broken'));
      expect(result.statusCode, 201);
      final doc = data(result)['id'] as String;
      await app.courses.tail;
      expect(
        data(
          await request('GET', '/api/documents/$doc', token: token),
        )['status'],
        'failed',
      );
      expect(
        (await request(
          'POST',
          '/api/documents/$doc/retry',
          token: token,
        )).statusCode,
        202,
      );
      await app.courses.tail;
      expect(
        (await request(
          'DELETE',
          '/api/documents/$doc',
          token: token,
        )).statusCode,
        204,
      );
      expect(Directory('${temp.path}/pdfs').listSync(), isEmpty);
    },
    // Includes a 20 MB HTTP upload and native PDF extraction/retry.
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test('chunking preserves page boundaries and text', () {
    final text = List.filled(400, 'learning').join(' ');
    final result = chunks([text, 'second page']);
    expect(result.where((c) => c.page == 1).map((c) => c.text).join(' '), text);
    expect(result.last.page, 2);
    expect(result.every((c) => c.text.length <= 900), isTrue);
    final unicode = '${'a' * 899}\u{1f600}end';
    final unicodeChunks = chunks([unicode]);
    expect(unicodeChunks.map((c) => c.text).join(), unicode);
    for (final chunk in unicodeChunks) {
      expect(utf8.decode(utf8.encode(chunk.text)), chunk.text);
    }
  });
  test(
    'real blank and accented PDFs retain page references and safe filenames',
    () async {
      final token =
          (await register('edges@example.com'))['accessToken'] as String;
      final course =
          data(
                await request(
                  'POST',
                  '/api/courses',
                  token: token,
                  body: {
                    'title': "Course '); DROP TABLE courses; --",
                    'subject': 'Custom subject',
                  },
                ),
              )['id']
              as String;
      final empty = await upload(
        token,
        course,
        coursePdfFixture(texts: ['', '']),
      );
      expect(empty.statusCode, 201);
      await app.courses.tail;
      final failed = data(
        await request(
          'GET',
          '/api/documents/${data(empty)['id']}',
          token: token,
        ),
      );
      expect(failed['status'], 'failed');
      expect(failed['error'], contains('OCR'));
      const passage = 'Le café coûte cher. Élève (révision).';
      final mixed = await upload(
        token,
        course,
        coursePdfFixture(texts: ['', passage]),
        name: '../../outside.pdf',
      );
      expect(mixed.statusCode, 201);
      await app.courses.tail;
      final doc = data(
        await request(
          'GET',
          '/api/documents/${data(mixed)['id']}',
          token: token,
        ),
      );
      expect(doc['status'], 'ready');
      expect(doc['pages'], 2);
      expect(doc['name'], 'outside.pdf');
      expect(doc['error'], contains('Some pages'));
      final chunks = app.store.rows('SELECT * FROM document_chunks');
      expect(chunks.single['page_number'], 2);
      expect(chunks.single['content'], passage);
      expect(Directory('${temp.path}/pdfs').listSync().length, 2);
      expect(File('${temp.path}/outside.pdf').existsSync(), false);
      expect(app.store.rows('SELECT * FROM courses').length, 1);
      final hits = await request(
        'POST',
        '/api/courses/search',
        token: token,
        body: {'courseId': course, 'query': 'café'},
      );
      expect((jsonDecode(hits.body) as List).single['page'], 2);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
