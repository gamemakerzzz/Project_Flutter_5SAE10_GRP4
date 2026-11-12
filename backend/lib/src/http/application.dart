import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_frog/dart_frog.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../config/config.dart';
import '../database/database.dart';
import '../repositories/store.dart';
import '../security/auth.dart';
import '../services/course_service.dart';
import '../services/ollama_provider.dart';
import '../services/rag_contracts.dart';
import '../services/rag_service.dart';
import 'api_error.dart';

class Application {
  Application(
    Config config, {
    String migrations = 'migrations',
    RagProvider? ragProvider,
  }) {
    database = AppDatabase(config.dataDirectory, migrations: migrations);
    store = Store(database);
    auth = AuthService(store, config.secret);
    rag = RagService(
      store,
      ragProvider ??
          (config.ollamaUrl == null
              ? null
              : OllamaProvider(
                  baseUri: config.ollamaUrl!,
                  embeddingModel: config.embeddingModel,
                  chatModel: config.chatModel,
                )),
    );
    courses = CourseService(
      store,
      config.pdfDirectory,
      onIndexed: (user, course) {
        if (rag.provider != null) rag.enqueue(user, course);
      },
    );
  }
  late final AppDatabase database;
  late final Store store;
  late final AuthService auth;
  late final CourseService courses;
  late final RagService rag;
  int activeUploads = 0;
  final Map<String, ({int count, DateTime until})> attempts = {};
  void rateLimit(Request request) {
    final now = DateTime.now();
    attempts.removeWhere((_, v) => v.until.isBefore(now));
    final key = request.connectionInfo.remoteAddress.address;
    final value =
        attempts[key] ?? (count: 0, until: now.add(const Duration(minutes: 1)));
    if (value.count >= 20 || attempts.length > 10000) {
      throw const ApiError(
        429,
        'RATE_LIMIT',
        'Too many authentication attempts. Try again in one minute.',
      );
    }
    attempts[key] = (count: value.count + 1, until: value.until);
  }

  Future<Uint8List> bounded(Request request, int max) async {
    final length = int.tryParse(request.headers['content-length'] ?? '');
    if (length != null && length > max) {
      throw const ApiError(413, 'BODY_TOO_LARGE', 'Request body is too large.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request.bytes().timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > max) {
        throw const ApiError(
          413,
          'BODY_TOO_LARGE',
          'Request body is too large.',
        );
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<Json> json(Request request) async {
    if (!(request.headers['content-type'] ?? '').toLowerCase().startsWith(
      'application/json',
    )) {
      throw const ApiError(415, 'CONTENT_TYPE', 'Use application/json.');
    }
    final decoded = jsonDecode(utf8.decode(await bounded(request, 32 * 1024)));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiError(400, 'INVALID_JSON', 'Expected a JSON object.');
    }
    return decoded;
  }

  Future<Response> handle(RequestContext context) async {
    try {
      return await dispatch(context.request);
    } on ApiError catch (e) {
      return Response.json(statusCode: e.status, body: e.toJson());
    } on FormatException {
      const e = ApiError(400, 'INVALID_REQUEST', 'Malformed request.');
      return Response.json(statusCode: e.status, body: e.toJson());
    } on TimeoutException {
      const e = ApiError(408, 'TIMEOUT', 'Request timed out.');
      return Response.json(statusCode: e.status, body: e.toJson());
    } catch (e, stack) {
      stderr.writeln(stack);
      stderr.writeln('Request failed: ${e.runtimeType}');
      const error = ApiError(
        500,
        'INTERNAL_ERROR',
        'The server could not complete the request.',
      );
      return Response.json(statusCode: 500, body: error.toJson());
    }
  }

  Future<Response> dispatch(Request request) async {
    final segments = request.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    final path = '/${segments.join('/')}';
    final method = request.method.value.toUpperCase();
    if (path == '/health' && method == 'GET') {
      return Response.json(body: {'status': 'ok'});
    }
    if (path == '/api/auth/register' || path == '/api/auth/login') {
      if (method != 'POST') {
        throw const ApiError(405, 'METHOD_NOT_ALLOWED', 'Use POST.');
      }
      rateLimit(request);
      final body = await json(request);
      return Response.json(
        statusCode: path.endsWith('register') ? 201 : 200,
        body: path.endsWith('register')
            ? await auth.register(body)
            : await auth.login(body),
      );
    }
    final user = auth.identify(request.headers['authorization']);
    if (path == '/api/users/me') {
      if (method == 'GET') return Response.json(body: store.profile(user));
      if (method == 'PUT') {
        return Response.json(body: auth.update(user, await json(request)));
      }
    } else if (path == '/api/courses') {
      if (method == 'GET') return Response.json(body: courses.list(user));
      if (method == 'POST') {
        return Response.json(
          statusCode: 201,
          body: courses.save(user, await json(request)),
        );
      }
    } else if (path == '/api/courses/search' && method == 'POST') {
      final body = await json(request);
      final mode = body['mode'] ?? 'keyword';
      if (mode != 'keyword' && mode != 'semantic') {
        throw const ApiError(400, 'VALIDATION_ERROR', 'Unknown search mode.');
      }
      return Response.json(
        body: mode == 'semantic'
            ? await rag.search(user, body)
            : courses.search(user, body),
      );
    } else if (path == '/api/rag/ask' && method == 'POST') {
      final body = await json(request);
      return Response.json(body: await rag.ask(user, body));
    } else if (segments.length >= 3 &&
        segments[0] == 'api' &&
        segments[1] == 'courses') {
      final id = segments[2];
      if (segments.length == 4 && segments[3] == 'index') {
        if (method == 'GET') return Response.json(body: rag.status(user, id));
        if (method == 'POST') {
          return Response.json(statusCode: 202, body: rag.enqueue(user, id));
        }
      }
      if (segments.length == 3) {
        if (method == 'GET') {
          return Response.json(body: Store.courseJson(store.course(user, id)));
        }
        if (method == 'PUT') {
          return Response.json(
            body: courses.save(user, await json(request), id: id),
          );
        }
        if (method == 'DELETE') {
          courses.deleteCourse(user, id);
          return Response(statusCode: 204);
        }
      } else if (segments.length == 4 && segments[3] == 'documents') {
        if (method == 'GET') {
          return Response.json(body: courses.documents(user, id));
        }
        if (method == 'POST') return upload(request, user, id);
      }
    } else if (segments.length >= 3 &&
        segments[0] == 'api' &&
        segments[1] == 'documents') {
      final id = segments[2];
      final doc = store.document(user, id);
      if (segments.length == 3) {
        if (method == 'GET') {
          return Response.json(body: Store.documentJson(doc));
        }
        if (method == 'DELETE') {
          courses.deleteDocument(user, id);
          return Response(statusCode: 204);
        }
      } else if (segments.length == 4) {
        if (segments[3] == 'status' && method == 'GET') {
          return Response.json(body: Store.documentJson(doc));
        }
        if (segments[3] == 'retry' && method == 'POST') {
          courses.retry(user, id);
          return Response.json(
            statusCode: 202,
            body: Store.documentJson(store.document(user, id)),
          );
        }
        if (segments[3] == 'content' && method == 'GET') {
          final file = File(courses.path(doc['stored_filename'] as String));
          if (!file.existsSync()) {
            throw const ApiError(
              404,
              'PDF_MISSING',
              'The saved PDF file is missing.',
            );
          }
          return Response.bytes(
            body: await file.readAsBytes(),
            headers: {
              'content-type': 'application/pdf',
              'content-disposition':
                  "inline; filename=\"document.pdf\"; filename*=UTF-8''${Uri.encodeComponent(doc['original_filename'] as String)}",
              'cache-control': 'no-store',
              'x-content-type-options': 'nosniff',
            },
          );
        }
      }
    }
    throw const ApiError(404, 'NOT_FOUND', 'Endpoint or method not found.');
  }

  Future<Response> upload(Request request, String user, String course) async {
    store.course(user, course);
    if (activeUploads >= 2) {
      throw const ApiError(
        503,
        'BUSY',
        'Uploads are busy. Please retry shortly.',
      );
    }
    activeUploads++;
    try {
      final type = MediaType.parse(request.headers['content-type'] ?? '');
      final boundary = type.parameters['boundary'];
      if (type.mimeType != 'multipart/form-data' ||
          boundary == null ||
          boundary.length > 200) {
        throw const ApiError(
          400,
          'MULTIPART_REQUIRED',
          'Use multipart/form-data with field file.',
        );
      }
      final bytes = await bounded(request, 20 * 1024 * 1024 + 64 * 1024);
      Uint8List? fileBytes;
      String? filename;
      await for (final part in MimeMultipartTransformer(
        boundary,
      ).bind(Stream.value(bytes))) {
        final disposition = HeaderValue.parse(
          part.headers['content-disposition'] ?? '',
        );
        if (disposition.parameters['name'] != 'file' || fileBytes != null) {
          throw const ApiError(
            400,
            'INVALID_MULTIPART',
            'Send exactly one file field.',
          );
        }
        filename = disposition.parameters['filename'];
        final builder = BytesBuilder(copy: false);
        await for (final chunk in part) {
          builder.add(chunk);
        }
        fileBytes = builder.takeBytes();
      }
      if (filename == null || fileBytes == null) {
        throw const ApiError(400, 'FILE_REQUIRED', 'PDF file is required.');
      }
      return Response.json(
        statusCode: 201,
        body: courses.upload(user, course, filename, fileBytes),
      );
    } finally {
      activeUploads--;
    }
  }

  Future<void> close() async {
    await courses.close();
    await rag.close();
    database.close();
  }
}
