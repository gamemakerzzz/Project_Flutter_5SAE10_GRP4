import 'package:flutter/foundation.dart';

import '../models/course_models.dart';
import 'courses_repository.dart';
import 'pdf_import_service.dart';

/// Session-only sandbox. Uses actual uploaded PDF text; no embeddings or LLM.
class LocalCoursesRepository implements CoursesRepository {
  LocalCoursesRepository({PdfTextExtractor? extractor})
    : extractor = extractor ?? PdfrxTextExtractor();
  final PdfTextExtractor extractor;
  final _courses = <String, Course>{};
  final _documents = <String, CourseDocument>{};
  final _bytes = <String, Uint8List>{};
  final _chunks = <String, List<SourcePassage>>{};
  final _inFlight = <String>{};
  int _next = 0;
  bool _disposed = false;
  @override
  bool get isLocal => true;
  void _course(String id) {
    if (_disposed || !_courses.containsKey(id)) {
      throw const CoursesException('This course is no longer available.');
    }
  }

  CourseDocument _document(String id) {
    final doc = _documents[id];
    if (_disposed || doc == null) {
      throw const CoursesException('This document is no longer available.');
    }
    return doc;
  }

  @override
  Future<List<Course>> listCourses() async => List.unmodifiable(
    _courses.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  @override
  Future<Course> saveCourse({
    String? id,
    required String title,
    required String subject,
    required String description,
  }) async {
    if (title.trim().isEmpty ||
        title.trim().length > 120 ||
        subject.trim().isEmpty ||
        subject.trim().length > 100 ||
        description.trim().length > 4000) {
      throw const CoursesException(
        'Enter a title (up to 120 characters), a subject (up to 100), and a description up to 4,000 characters.',
      );
    }
    if (id != null) _course(id);
    final course = Course(
      id: id ?? 'course-${++_next}',
      title: title.trim(),
      subject: subject.trim(),
      description: description.trim(),
      updatedAt: DateTime.now(),
    );
    _courses[course.id] = course;
    return course;
  }

  void _touch(String courseId) {
    final c = _courses[courseId];
    if (c != null) {
      _courses[courseId] = Course(
        id: c.id,
        title: c.title,
        subject: c.subject,
        description: c.description,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteCourse(String id) async {
    _course(id);
    for (final doc
        in _documents.values.where((d) => d.courseId == id).toList()) {
      await deleteDocument(doc.id);
    }
    _courses.remove(id);
  }

  @override
  Future<List<CourseDocument>> documents(String courseId) async {
    _course(courseId);
    return _documents.values.where((d) => d.courseId == courseId).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  @override
  Future<CourseDocument> upload(String courseId, SelectedPdf pdf) async {
    _course(courseId);
    PdfValidation.validate(pdf);
    if (_bytes.values.fold<int>(0, (s, b) => s + b.length) + pdf.bytes.length >
        80 * 1024 * 1024) {
      throw const CoursesException(
        'The session limit is 80 MB. Remove a document before importing another.',
      );
    }
    for (final doc in _documents.values.where((d) => d.courseId == courseId)) {
      if (listEquals(_bytes[doc.id], pdf.bytes)) {
        throw const CoursesException(
          'This PDF is already imported in this course.',
        );
      }
    }
    final doc = CourseDocument(
      id: 'document-${++_next}',
      courseId: courseId,
      name: pdf.name,
      size: pdf.bytes.length,
      status: ProcessingStatus.uploaded,
      uploadedAt: DateTime.now(),
    );
    _documents[doc.id] = doc;
    _bytes[doc.id] = Uint8List.fromList(pdf.bytes);
    _touch(courseId);
    return doc;
  }

  @override
  Future<void> process(String documentId) async {
    final doc = _document(documentId);
    if (_inFlight.contains(documentId) ||
        doc.status == ProcessingStatus.ready) {
      return;
    }
    _inFlight.add(documentId);
    _documents[documentId] = doc.withStatus(ProcessingStatus.processing);
    try {
      final pages = await extractor.pages(_bytes[documentId]!);
      final chunks = chunkPages(doc, pages);
      if (chunks.isEmpty) {
        throw const CoursesException(
          'No selectable text found. This may be a scanned PDF; OCR is not enabled.',
        );
      }
      if (_disposed || !_documents.containsKey(documentId)) return;
      _chunks[documentId] = chunks;
      final blank = pages.where((p) => p.trim().isEmpty).length;
      _documents[documentId] = doc.withStatus(
        ProcessingStatus.ready,
        pages: pages.length,
        error: blank == 0
            ? null
            : '$blank page(s) have no extractable text and are not searchable. No OCR was performed.',
      );
    } catch (e) {
      if (!_disposed && _documents.containsKey(documentId)) {
        _documents[documentId] = doc.withStatus(
          ProcessingStatus.failed,
          error: e is CoursesException ? e.message : 'Cannot index this PDF. It may be damaged or password-protected. Use an unlocked PDF and retry.',
        );
      }
    } finally {
      _inFlight.remove(documentId);
    }
  }

  @override
  Future<Uint8List> content(String documentId) async {
    _document(documentId);
    return Uint8List.fromList(_bytes[documentId]!);
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    final doc = _document(documentId);
    _documents.remove(documentId);
    _bytes.remove(documentId);
    _chunks.remove(documentId);
    _touch(doc.courseId);
  }

  @override
  Future<List<SourcePassage>> search(String courseId, String query) async {
    _course(courseId);
    const stop = {
      'the',
      'and',
      'what',
      'how',
      'does',
      'are',
      'for',
      'with',
      'this',
      'that',
      'from',
      'explain',
      'about',
      'les',
      'des',
      'une',
      'est',
      'que',
      'dans',
      'pour',
    };
    final terms = RegExp(r'[a-zA-ZÀ-ÿ0-9]+')
        .allMatches(query.toLowerCase())
        .map((m) => m.group(0)!)
        .where((t) => t.length > 2 && !stop.contains(t))
        .toSet();
    if (terms.isEmpty) return [];
    final result = <SourcePassage>[];
    for (final list in _chunks.values) {
      for (final chunk in list.where((c) => c.courseId == courseId)) {
        final words = RegExp(r'[a-zA-ZÀ-ÿ0-9]+')
            .allMatches(chunk.excerpt.toLowerCase())
            .map((m) => m.group(0)!)
            .toSet();
        final matched = terms.intersection(words).length;
        if (matched > 0) result.add(chunk.scored(matched / terms.length));
      }
    }
    result.sort((a, b) => b.score!.compareTo(a.score!));
    return result.take(5).toList();
  }

  @override
  Future<RagAnswer> ask(String courseId, String question) async {
    final sources = await search(courseId, question);
    return RagAnswer(
      answer: sources.isEmpty
          ? 'An answer could not be established from the uploaded materials. Try a more specific term or import another PDF.'
          : 'AI generation is not connected. These exact passages match words in your question; they are evidence to read, not an AI-generated answer.',
      sources: sources,
      generated: false,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _courses.clear();
    _documents.clear();
    _bytes.clear();
    _chunks.clear();
  }
}
