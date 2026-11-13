import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

import '../models/course_models.dart';
import 'courses_repository.dart';
import 'pdf_import_service.dart';

/// Authenticated adapter for the StudyMate Dart Frog REST API.
/// The server must authorize every course/document and verify all citations.
class CoursesApiService implements CoursesRepository {
  CoursesApiService({
    required this.baseUri,
    required this.tokenProvider,
    http.Client? client,
  }) : client = client ?? http.Client() {
    ApiConfig.validate(baseUri);
  }
  final Uri baseUri;
  final Future<String?> Function() tokenProvider;
  final http.Client client;
  bool _disposed = false;
  @override
  bool get isLocal => false;
  void _checkOpen() {
    if (_disposed) {
      throw const CoursesException('The course session was closed.');
    }
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    _checkOpen();
    final token = await tokenProvider();
    _checkOpen();
    if (token == null || token.isEmpty) {
      throw const CoursesException(
        'Sign in with a real account before using the server.',
      );
    }
    request.headers['Authorization'] = 'Bearer $token';
    request.headers.putIfAbsent('Accept', () => 'application/json');
    try {
      final response =
          await (() async => http.Response.fromStream(
            await client.send(request),
          ))().timeout(
            Duration(
              seconds:
                  request.url.path == '/api/rag/ask' ||
                      request.url.path == '/api/courses/search'
                  ? 150
                  : 45,
            ),
          );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      if (response.statusCode == 501) {
        throw const CoursesException(
          'RAG generation is not yet available. Use full-text search to find source passages.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CoursesException(
          'Your session expired or you do not have access.',
        );
      }
      if (response.statusCode == 413) {
        throw CoursesException(
          _problem(response) ?? 'The request exceeds a server size limit.',
        );
      }
      if (response.statusCode == 404) {
        throw const CoursesException(
          'This course or document is no longer available.',
        );
      }
      if (response.statusCode == 400 || response.statusCode == 422) {
        throw CoursesException(
          _problem(response) ?? 'Check the entered information and retry.',
        );
      }
      if (response.statusCode == 409) {
        final problem = _problem(response);
        if (problem != null) throw CoursesException(problem);
        throw const CoursesException(
          'This document already exists or is being processed.',
        );
      }
      if ([502, 503, 504].contains(response.statusCode)) {
        throw CoursesException(
          _problem(response) ??
              'Local AI is temporarily unavailable. Please retry.',
        );
      }
      throw CoursesException(
        'The server could not complete this request (HTTP ${response.statusCode}). Please retry.',
      );
    } on TimeoutException {
      throw const CoursesException(
        'The server timed out. Refresh before retrying: the operation may have completed.',
      );
    } on http.ClientException {
      throw const CoursesException(
        'Cannot reach the server. Check your connection and retry.',
      );
    }
  }

  String? _problem(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final message = data is Map ? data['message'] : null;
      return message is String && message.length <= 500 ? message : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureIndexed(String courseId) async {
    final path = '/api/courses/${_id(courseId)}/index';
    var state = await _json('POST', path) as Map<String, dynamic>;
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (!_disposed) {
      if (state['state'] == 'ready') return;
      if (state['state'] == 'failed') {
        throw CoursesException(
          state['error'] as String? ?? 'Indexing failed. Please retry.',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const CoursesException(
          'Indexing is still running on the server. Retry later to use the saved progress.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_disposed) break;
      state = await _json('GET', path) as Map<String, dynamic>;
    }
    throw const CoursesException('The course session was closed.');
  }

  Uri _uri(String path) => baseUri.resolve(path);
  String _id(String id) => Uri.encodeComponent(id);
  Future<dynamic> _json(String method, String path, [Object? body]) async {
    final request = http.Request(method, _uri(path));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _send(request);
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const CoursesException('The server returned an invalid response.');
    }
  }

  @override
  Future<List<Course>> listCourses() async =>
      ((await _json('GET', '/api/courses')) as List)
          .map((j) => Course.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<Course> saveCourse({
    String? id,
    required String title,
    required String subject,
    required String description,
  }) async => Course.fromJson(
    await _json(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/courses' : '/api/courses/${_id(id)}',
      {'title': title, 'subject': subject, 'description': description},
    ) as Map<String, dynamic>,
  );
  @override
  Future<void> deleteCourse(String id) async {
    await _json('DELETE', '/api/courses/${_id(id)}');
  }

  @override
  Future<List<CourseDocument>> documents(String courseId) async =>
      ((await _json('GET', '/api/courses/${_id(courseId)}/documents')) as List)
          .map((j) => CourseDocument.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<CourseDocument> upload(String courseId, SelectedPdf pdf) async {
    PdfValidation.validate(pdf);
    final request =
        http.MultipartRequest(
            'POST',
            _uri('/api/courses/${_id(courseId)}/documents'),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              pdf.bytes,
              filename: pdf.name,
              contentType: http.MediaType('application', 'pdf'),
            ),
          );
    final response = await _send(request);
    return CourseDocument.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> process(String documentId) async {
    // Normal processing starts on server upload; this endpoint retries failures.
    await _json('POST', '/api/documents/${_id(documentId)}/retry');
  }

  Future<CourseDocument> status(String documentId) async =>
      CourseDocument.fromJson(
        await _json('GET', '/api/documents/${_id(documentId)}/status')
            as Map<String, dynamic>,
      );
  @override
  Future<void> deleteDocument(String documentId) async {
    await _json('DELETE', '/api/documents/${_id(documentId)}');
  }

  @override
  Future<Uint8List> content(String documentId) async {
    final response = await _send(
      http.Request('GET', _uri('/api/documents/${_id(documentId)}/content'))
        ..headers['Accept'] = 'application/pdf',
    );
    return response.bodyBytes;
  }

  Future<List<SourcePassage>> _sources(
    String courseId,
    List<dynamic> data,
  ) async {
    final docs = {for (final d in await documents(courseId)) d.id: d};
    final result = data
        .map((j) => SourcePassage.fromJson(j as Map<String, dynamic>))
        .toList();
    for (final source in result) {
      final doc = docs[source.documentId];
      if (doc == null ||
          doc.courseId != courseId ||
          source.documentName != doc.name ||
          source.courseId != courseId ||
          source.page < 1 ||
          (doc.pages != null && source.page > doc.pages!) ||
          source.chunkId.isEmpty ||
          source.excerpt.trim().isEmpty) {
        throw const CoursesException(
          'The server returned an invalid source reference.',
        );
      }
    }
    return result;
  }

  @override
  Future<List<SourcePassage>> search(String courseId, String query) async {
    await _ensureIndexed(courseId);
    final data = await _json('POST', '/api/courses/search', {
      'query': query,
      'courseId': courseId,
      'topK': 5,
      'mode': 'semantic',
    });
    return _sources(courseId, data as List<dynamic>);
  }

  @override
  Future<RagAnswer> ask(String courseId, String question) async {
    await _ensureIndexed(courseId);
    final data = await _json('POST', '/api/rag/ask', {
      'courseId': courseId,
      'question': question,
    }) as Map<String, dynamic>;
    final sources = await _sources(courseId, data['sources'] as List<dynamic>);
    if (sources.isEmpty) {
      return const RagAnswer(
        answer:
            'An answer could not be established from the uploaded materials.',
        sources: [],
        generated: false,
      );
    }
    return RagAnswer(
      answer: data['answer'] as String,
      sources: sources,
      generated: data['generated'] != false,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    client.close();
  }
}
