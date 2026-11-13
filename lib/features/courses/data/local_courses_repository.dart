import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../models/course_models.dart';
import 'courses_repository.dart';
import 'pdf_import_service.dart';

/// Local-first course repository backed by the app's shared SQLite database.
class LocalCoursesRepository implements CoursesRepository {
  LocalCoursesRepository({PdfTextExtractor? extractor})
    : extractor = extractor ?? PdfrxTextExtractor();

  final PdfTextExtractor extractor;
  final _inFlight = <String>{};

  @override
  bool get isLocal => true;

  Future<Database> get _db => AppDatabase.instance.database;
  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Course _courseFromRow(Map<String, Object?> row) => Course(
    id: row['id']! as String,
    title: row['title']! as String,
    subject: row['subject']! as String,
    description: row['description']! as String,
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  CourseDocument _documentFromRow(Map<String, Object?> row) => CourseDocument(
    id: row['id']! as String,
    courseId: row['course_id']! as String,
    name: row['name']! as String,
    size: row['size']! as int,
    status: ProcessingStatus.values.byName(row['status']! as String),
    uploadedAt: DateTime.parse(row['uploaded_at']! as String),
    pages: row['pages'] as int?,
    error: row['error'] as String?,
  );

  SourcePassage _passageFromRow(Map<String, Object?> row) => SourcePassage(
    chunkId: row['id']! as String,
    documentId: row['document_id']! as String,
    courseId: row['course_id']! as String,
    documentName: row['document_name']! as String,
    page: row['page']! as int,
    excerpt: row['excerpt']! as String,
  );

  Future<Course> _course(String id) async {
    final rows = await (await _db).query('courses', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw const CoursesException('This course is no longer available.');
    return _courseFromRow(rows.single);
  }

  Future<CourseDocument> _document(String id) async {
    final rows = await (await _db).query('course_documents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw const CoursesException('This document is no longer available.');
    return _documentFromRow(rows.single);
  }

  Future<void> _touch(String courseId) async => (await _db).update(
    'courses',
    {'updated_at': DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [courseId],
  );

  @override
  Future<List<Course>> listCourses() async => (await (await _db).query('courses', orderBy: 'updated_at DESC')).map(_courseFromRow).toList();

  @override
  Future<Course> saveCourse({String? id, required String title, required String subject, required String description}) async {
    if (title.trim().isEmpty || title.trim().length > 120 || subject.trim().isEmpty || subject.trim().length > 100 || description.trim().length > 4000) {
      throw const CoursesException('Enter a title (up to 120 characters), a subject (up to 100), and a description up to 4,000 characters.');
    }
    if (id != null) await _course(id);
    final course = Course(id: id ?? _id('course'), title: title.trim(), subject: subject.trim(), description: description.trim(), updatedAt: DateTime.now());
    await (await _db).insert('courses', {
      'id': course.id, 'title': course.title, 'subject': course.subject,
      'description': course.description, 'updated_at': course.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return course;
  }

  @override
  Future<void> deleteCourse(String id) async {
    await _course(id);
    final database = await _db;
    await database.transaction((tx) async {
      await tx.delete('course_chunks', where: 'course_id = ?', whereArgs: [id]);
      await tx.delete('course_documents', where: 'course_id = ?', whereArgs: [id]);
      await tx.delete('courses', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<CourseDocument>> documents(String courseId) async {
    await _course(courseId);
    return (await (await _db).query('course_documents', where: 'course_id = ?', whereArgs: [courseId], orderBy: 'uploaded_at DESC')).map(_documentFromRow).toList();
  }

  @override
  Future<CourseDocument> upload(String courseId, SelectedPdf pdf) async {
    await _course(courseId);
    PdfValidation.validate(pdf);
    final database = await _db;
    final total = Sqflite.firstIntValue(await database.rawQuery('SELECT COALESCE(SUM(size), 0) FROM course_documents')) ?? 0;
    if (total + pdf.bytes.length > 80 * 1024 * 1024) {
      throw const CoursesException('The local storage limit is 80 MB. Remove a document before importing another.');
    }
    final duplicates = await database.query('course_documents', columns: ['id'], where: 'course_id = ? AND name = ? AND size = ?', whereArgs: [courseId, pdf.name, pdf.bytes.length], limit: 1);
    if (duplicates.isNotEmpty) throw const CoursesException('A PDF with this name and size is already imported in this course.');
    final doc = CourseDocument(id: _id('document'), courseId: courseId, name: pdf.name, size: pdf.bytes.length, status: ProcessingStatus.uploaded, uploadedAt: DateTime.now());
    await database.insert('course_documents', {
      'id': doc.id, 'course_id': doc.courseId, 'name': doc.name, 'size': doc.size,
      'status': doc.status.name, 'uploaded_at': doc.uploadedAt.toIso8601String(),
      'bytes': Uint8List.fromList(pdf.bytes),
    });
    await _touch(courseId);
    return doc;
  }

  @override
  Future<void> process(String documentId) async {
    final doc = await _document(documentId);
    if (_inFlight.contains(documentId) || doc.status == ProcessingStatus.ready) return;
    _inFlight.add(documentId);
    final database = await _db;
    await database.update('course_documents', {'status': ProcessingStatus.processing.name, 'error': null}, where: 'id = ?', whereArgs: [documentId]);
    try {
      final rows = await database.query('course_documents', columns: ['bytes'], where: 'id = ?', whereArgs: [documentId], limit: 1);
      final pages = await extractor.pages(rows.single['bytes']! as Uint8List);
      final chunks = chunkPages(doc, pages);
      if (chunks.isEmpty) throw const CoursesException('No selectable text found. This may be a scanned PDF; OCR is not enabled.');
      final blank = pages.where((page) => page.trim().isEmpty).length;
      await database.transaction((tx) async {
        await tx.delete('course_chunks', where: 'document_id = ?', whereArgs: [documentId]);
        for (var index = 0; index < chunks.length; index++) {
          final chunk = chunks[index];
          await tx.insert('course_chunks', {
            'id': '${documentId}_$index', 'document_id': documentId,
            'course_id': doc.courseId, 'document_name': doc.name,
            'page': chunk.page, 'excerpt': chunk.excerpt,
          });
        }
        await tx.update('course_documents', {
          'status': ProcessingStatus.ready.name, 'pages': pages.length,
          'error': blank == 0 ? null : '$blank page(s) have no extractable text and are not searchable. No OCR was performed.',
        }, where: 'id = ?', whereArgs: [documentId]);
      });
      await _touch(doc.courseId);
    } catch (error) {
      await database.update('course_documents', {
        'status': ProcessingStatus.failed.name,
        'error': error is CoursesException ? error.message : 'Cannot index this PDF. It may be damaged or password-protected. Use an unlocked PDF and retry.',
      }, where: 'id = ?', whereArgs: [documentId]);
    } finally {
      _inFlight.remove(documentId);
    }
  }

  @override
  Future<Uint8List> content(String documentId) async {
    await _document(documentId);
    final rows = await (await _db).query('course_documents', columns: ['bytes'], where: 'id = ?', whereArgs: [documentId], limit: 1);
    return Uint8List.fromList(rows.single['bytes']! as Uint8List);
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    final doc = await _document(documentId);
    final database = await _db;
    await database.transaction((tx) async {
      await tx.delete('course_chunks', where: 'document_id = ?', whereArgs: [documentId]);
      await tx.delete('course_documents', where: 'id = ?', whereArgs: [documentId]);
    });
    await _touch(doc.courseId);
  }

  @override
  Future<List<SourcePassage>> search(String courseId, String query) async {
    await _course(courseId);
    const stop = {'the', 'and', 'what', 'how', 'does', 'are', 'for', 'with', 'this', 'that', 'from', 'explain', 'about', 'les', 'des', 'une', 'est', 'que', 'dans', 'pour'};
    final terms = RegExp(r'[a-zA-ZÀ-ÿ0-9]+').allMatches(query.toLowerCase()).map((match) => match.group(0)!).where((term) => term.length > 2 && !stop.contains(term)).toSet();
    if (terms.isEmpty) return [];
    final matches = <SourcePassage>[];
    for (final passage in await quizSources(courseId)) {
      final words = RegExp(r'[a-zA-ZÀ-ÿ0-9]+').allMatches(passage.excerpt.toLowerCase()).map((match) => match.group(0)!).toSet();
      final matched = terms.intersection(words).length;
      if (matched > 0) matches.add(passage.scored(matched / terms.length));
    }
    matches.sort((a, b) => b.score!.compareTo(a.score!));
    return matches.take(5).toList();
  }

  @override
  Future<List<SourcePassage>> quizSources(String courseId) async {
    final course = await _course(courseId);
    final rows = await (await _db).query('course_chunks', where: 'course_id = ?', whereArgs: [courseId], orderBy: 'page ASC', limit: 12);
    if (rows.isNotEmpty) return rows.map(_passageFromRow).toList();
    if (course.description.isEmpty) return [];
    return [SourcePassage(chunkId: '${course.id}-description', documentId: '', courseId: course.id, documentName: course.title, page: 0, excerpt: course.description)];
  }

  @override
  Future<RagAnswer> ask(String courseId, String question) async {
    final sources = await search(courseId, question);
    return RagAnswer(
      answer: sources.isEmpty ? 'An answer could not be established from the uploaded materials. Try a more specific term or import another PDF.' : 'AI generation is not connected. These exact passages match words in your question; they are evidence to read, not an AI-generated answer.',
      sources: sources,
      generated: false,
    );
  }
}
