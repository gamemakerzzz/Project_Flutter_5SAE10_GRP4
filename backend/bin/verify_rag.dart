// Opt-in end-to-end check: real HTTP, temporary SQLite/PDF storage and real Ollama.
// Does not use or modify the development accounts/database.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:studymate_backend/src/config/config.dart';
import 'package:studymate_backend/src/http/application.dart';

import '../../test/features/courses/pdf_fixture.dart';

Future<void> main() async {
  final temp = Directory.systemTemp.createTempSync('studymate-live-rag-');
  final secret = base64Url.encode(
    List.generate(48, (_) => Random.secure().nextInt(256)),
  );
  final config = Config(
    secret: secret,
    dataDirectory: '${temp.path}/data',
    pdfDirectory: '${temp.path}/pdfs',
    ollamaUrl: Uri.parse(
      Platform.environment['OLLAMA_BASE_URL'] ?? 'http://127.0.0.1:11434',
    ),
    embeddingModel:
        Platform.environment['OLLAMA_EMBED_MODEL'] ?? 'embeddinggemma:300m',
    chatModel: Platform.environment['OLLAMA_CHAT_MODEL'] ?? 'qwen3:4b',
  );
  var app = Application(config);
  var server = await serve(app.handle, '127.0.0.1', 0);
  var base = Uri.parse('http://127.0.0.1:${server.port}');
  final client = http.Client();
  String? token;
  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  Future<dynamic> request(
    String method,
    String path, [
    Object? body,
    int expected = 200,
  ]) async {
    final req = http.Request(method, base.resolve(path));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await client.send(req))
        .timeout(const Duration(minutes: 3));
    require(
      response.statusCode == expected,
      '$path returned ${response.statusCode}: ${response.body}',
    );
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  try {
    await app.rag.ai.checkReady();
    stdout.writeln('Ollama models ready. Creating isolated test account.');
    final session = await request('POST', '/api/auth/register', {
      'fullName': 'RAG Validation',
      'email': 'rag-validation@example.com',
      'password': 'ValidationOnly123!',
      'academicLevel': 'L3',
      'specialty': 'AI',
      'subjects': ['Machine Learning'],
    }, 201);
    token = session['accessToken'] as String;
    final course = await request('POST', '/api/courses', {
      'title': 'ML validation',
      'subject': 'AI',
    }, 201);
    final courseId = course['id'] as String;
    final upload =
        http.MultipartRequest(
            'POST',
            base.resolve('/api/courses/$courseId/documents'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              coursePdfFixture(),
              filename: 'course_sample.pdf',
            ),
          );
    final uploaded = await http.Response.fromStream(await client.send(upload));
    require(uploaded.statusCode == 201, 'PDF upload failed');
    final documentId = jsonDecode(uploaded.body)['id'] as String;
    await app.courses.tail;
    await app.rag.tail;
    var status = await request('GET', '/api/courses/$courseId/index');
    require(
      status['state'] == 'ready' && status['indexed'] == 2,
      'Index not ready: $status',
    );
    stdout.writeln('Real PDF extracted and both pages embedded.');
    final search = await request('POST', '/api/courses/search', {
      'courseId': courseId,
      'query': 'Comment apprendre sans etiquettes ?',
      'mode': 'semantic',
      'topK': 2,
    }) as List;
    require(
      search.isNotEmpty && search.first['page'] == 2,
      'Cross-language semantic retrieval failed: $search',
    );
    stdout.writeln('French semantic query found the English source on page 2.');
    final answer = await request('POST', '/api/rag/ask', {
      'courseId': courseId,
      'question': "Explique en français ce que fait l'apprentissage non supervisé selon le document.",
    });
    require(
      answer['generated'] == true && (answer['sources'] as List).isNotEmpty,
      'No grounded answer: $answer',
    );
    stdout.writeln(
      jsonEncode({'answer': answer['answer'], 'sources': answer['sources']}),
    );
    final unrelated = await request('POST', '/api/rag/ask', {
      'courseId': courseId,
      'question': 'What is the capital of Australia?',
    });
    require(
      unrelated['generated'] == false && (unrelated['sources'] as List).isEmpty,
      'Unrelated question was answered',
    );
    stdout.writeln('Unrelated question correctly refused.');
    final other = await request('POST', '/api/auth/register', {
      'fullName': 'Other Student',
      'email': 'other@example.com',
      'password': 'ValidationOnly123!',
      'academicLevel': 'L3',
      'specialty': 'AI',
      'subjects': [],
    }, 201);
    final ownerToken = token;
    token = other['accessToken'] as String;
    await request('POST', '/api/rag/ask', {
      'courseId': courseId,
      'question': 'Read this course',
    }, 404);
    token = ownerToken;
    await server.close(force: true);
    await app.close();
    app = Application(config);
    server = await serve(app.handle, '127.0.0.1', 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    await app.rag.ai.checkReady();
    status = await request('GET', '/api/courses/$courseId/index');
    require(status['indexed'] == 2, 'Embeddings were not persisted');
    await request('DELETE', '/api/documents/$documentId', null, 204);
    require(
      app.store.rows('SELECT * FROM chunk_embeddings').isEmpty,
      'Deleted vectors remain',
    );
    stdout.writeln(
      'PASS: real RAG, citations, isolation, persistence and deletion.',
    );
  } finally {
    client.close();
    await server.close(force: true);
    await app.close();
    temp.deleteSync(recursive: true);
  }
}
