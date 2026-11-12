import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../repositories/store.dart';
import '../http/api_error.dart';
import 'pdf_service.dart';

class CourseService {
  CourseService(
    this.store,
    this.directory, {
    PdfService? extractor,
    this.onIndexed,
  }) : extractor = extractor ?? PdfService() {
    Directory(directory).createSync(recursive: true);
    store.execute(
      "UPDATE documents SET status='failed',error_message='Processing interrupted by server restart. Retry processing.' WHERE status IN ('uploaded','processing')",
    );
    cleanup();
  }
  final Store store;
  final String directory;
  final PdfService extractor;
  final void Function(String user, String course)? onIndexed;
  final Map<String, Future<void>> jobs = {};
  Future<void> tail = Future.value();
  bool closing = false;
  String get now => DateTime.now().toUtc().toIso8601String();
  List<Json> list(String user) => store
      .rows('SELECT * FROM courses WHERE user_id=? ORDER BY updated_at DESC', [
        user,
      ])
      .map(Store.courseJson)
      .toList();
  Json save(String user, Json body, {String? id}) {
    final title = field(body, 'title', max: 120),
        subject = field(body, 'subject', max: 100),
        description = field(body, 'description', max: 4000, optional: true);
    if (id == null) {
      id = const Uuid().v4();
      store.execute('INSERT INTO courses VALUES(?,?,?,?,?,?,?)', [
        id,
        user,
        title,
        subject,
        description,
        now,
        now,
      ]);
    } else {
      store.course(user, id);
      store.execute(
        'UPDATE courses SET title=?,subject=?,description=?,updated_at=? WHERE id=?',
        [title, subject, description, now, id],
      );
    }
    return Store.courseJson(store.course(user, id));
  }

  String path(String filename) {
    if (!RegExp(r'^[a-f0-9-]{36}\.pdf$').hasMatch(filename)) {
      throw const ApiError(
        500,
        'STORAGE_ERROR',
        'Invalid stored file reference.',
      );
    }
    return p.join(directory, filename);
  }

  void cleanup() {
    for (final row in store.rows('SELECT stored_filename FROM file_cleanup')) {
      try {
        final file = File(path(row['stored_filename'] as String));
        if (file.existsSync()) file.deleteSync();
        store.execute('DELETE FROM file_cleanup WHERE stored_filename=?', [
          row['stored_filename'],
        ]);
      } on FileSystemException {
        /* Persisted cleanup queue retries at next startup. */
      }
    }
  }

  void deleteCourse(String user, String id) {
    store.course(user, id);
    store.database.transaction(() {
      store.execute(
        'INSERT OR IGNORE INTO file_cleanup SELECT stored_filename FROM documents WHERE course_id=?',
        [id],
      );
      store.execute('DELETE FROM courses WHERE id=?', [id]);
    });
    cleanup();
  }

  void deleteDocument(String user, String id) {
    final doc = store.document(user, id);
    store.database.transaction(() {
      store.execute('INSERT OR IGNORE INTO file_cleanup VALUES(?)', [
        doc['stored_filename'],
      ]);
      store.execute('DELETE FROM documents WHERE id=?', [id]);
    });
    cleanup();
  }

  List<Json> documents(String user, String id) {
    store.course(user, id);
    return store
        .rows(
          'SELECT * FROM documents WHERE course_id=? ORDER BY uploaded_at DESC',
          [id],
        )
        .map(Store.documentJson)
        .toList();
  }

  Json upload(String user, String course, String name, Uint8List bytes) {
    store.course(user, course);
    if (bytes.length > 20 * 1024 * 1024) {
      throw const ApiError(413, 'PDF_TOO_LARGE', 'Maximum PDF size is 20 MB.');
    }
    if (name.length > 255 ||
        !name.toLowerCase().endsWith('.pdf') ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const ApiError(
        400,
        'INVALID_PDF',
        'Choose a nonempty PDF with a valid signature.',
      );
    }
    final digest = sha256.convert(bytes).toString();
    if (store.rows('SELECT id FROM documents WHERE course_id=? AND sha256=?', [
      course,
      digest,
    ]).isNotEmpty) {
      throw const ApiError(
        409,
        'DUPLICATE_PDF',
        'This PDF already exists in this course.',
      );
    }
    final id = const Uuid().v4(), filename = '${const Uuid().v4()}.pdf';
    final file = File(path(filename));
    try {
      file.writeAsBytesSync(bytes, flush: true);
      store.execute('INSERT INTO documents VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)', [
        id,
        course,
        p.basename(name.replaceAll('\\', '/')),
        filename,
        'storage/pdfs/$filename',
        'application/pdf',
        bytes.length,
        digest,
        'uploaded',
        null,
        null,
        now,
        now,
      ]);
    } catch (_) {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
    final result = Store.documentJson(store.document(user, id));
    queue(id);
    return result;
  }

  void retry(String user, String id) {
    final doc = store.document(user, id);
    if (jobs.containsKey(id)) {
      throw const ApiError(
        409,
        'PROCESSING',
        'Document is already processing.',
      );
    }
    if (doc['status'] == 'ready') {
      throw const ApiError(
        409,
        'ALREADY_READY',
        'Document is already searchable.',
      );
    }
    queue(id);
  }

  void queue(String id) {
    if (closing || jobs.containsKey(id)) return;
    store.execute(
      "UPDATE documents SET status='uploaded',error_message=NULL,updated_at=? WHERE id=?",
      [now, id],
    );
    final job = tail.then((_) => process(id));
    jobs[id] = job;
    tail = job.whenComplete(() => jobs.remove(id));
  }

  Future<void> process(String id) async {
    final docs = store.rows('SELECT * FROM documents WHERE id=?', [id]);
    if (docs.isEmpty) return;
    store.execute(
      "UPDATE documents SET status='processing',updated_at=? WHERE id=?",
      [now, id],
    );
    try {
      final pages = await extractor.extract(
        path(docs.first['stored_filename'] as String),
      );
      if (store.rows('SELECT id FROM documents WHERE id=?', [id]).isEmpty) {
        return;
      }
      store.database.transaction(() {
        store.execute('DELETE FROM document_chunks WHERE document_id=?', [id]);
        for (final chunk in chunks(pages)) {
          store.execute('INSERT INTO document_chunks VALUES(?,?,?,?,?,?)', [
            const Uuid().v4(),
            id,
            chunk.page,
            chunk.index,
            chunk.text,
            now,
          ]);
        }
        store.execute(
          "UPDATE documents SET status='ready',page_count=?,error_message=?,updated_at=? WHERE id=?",
          [
            pages.length,
            pages.any((p) => p.trim().isEmpty)
                ? 'Some pages contain no searchable text. OCR is not available.'
                : null,
            now,
            id,
          ],
        );
      });
    } catch (e) {
      final message = e is FormatException
          ? e.message
          : 'Unable to extract this PDF. It may be damaged, encrypted, or unsupported.';
      store.execute(
        "UPDATE documents SET status='failed',error_message=?,updated_at=? WHERE id=?",
        [message, now, id],
      );
    }
    // PDF readiness does not depend on AI availability; index failures are shown separately.
    final owner = store.rows(
      'SELECT c.user_id,c.id FROM courses c JOIN documents d ON d.course_id=c.id WHERE d.id=? AND d.status=\'ready\'',
      [id],
    );
    if (owner.isNotEmpty && onIndexed != null) {
      try {
        onIndexed!(
          owner.single['user_id'] as String,
          owner.single['id'] as String,
        );
      } catch (_) {
        /* Search can retry indexing. */
      }
    }
    cleanup();
  }

  List<Json> search(String user, Json body) {
    final course = field(body, 'courseId'),
        query = field(body, 'query', max: 1000);
    store.course(user, course);
    final top = body['topK'] ?? 5;
    if (top is! int || top < 1 || top > 20) {
      throw const ApiError(
        400,
        'VALIDATION_ERROR',
        'topK must be between 1 and 20.',
      );
    }
    final terms = RegExp(r'[\p{L}\p{N}]+', unicode: true)
        .allMatches(query.toLowerCase())
        .map((m) => m[0]!)
        .toSet()
        .take(30)
        .toList();
    if (terms.isEmpty) return [];
    const columns =
        'k.id AS chunkId,d.id AS documentId,c.id AS courseId,d.original_filename AS documentName,k.page_number AS page,k.content AS excerpt';
    if (store.database.fts) {
      final match = terms.map((t) => '"$t"').join(' OR ');
      return store.rows(
        'SELECT $columns, -bm25(chunk_fts) AS score FROM chunk_fts JOIN document_chunks k ON k.rowid=chunk_fts.rowid JOIN documents d ON d.id=k.document_id JOIN courses c ON c.id=d.course_id WHERE chunk_fts MATCH ? AND c.id=? AND c.user_id=? AND d.status=\'ready\' ORDER BY bm25(chunk_fts) LIMIT ?',
        [match, course, user, top],
      );
    }
    final conditions = terms
        .map((_) => 'instr(lower(k.content),?)>0')
        .join(' OR ');
    return store.rows(
      'SELECT $columns, 1.0 AS score FROM document_chunks k JOIN documents d ON d.id=k.document_id JOIN courses c ON c.id=d.course_id WHERE c.id=? AND c.user_id=? AND d.status=\'ready\' AND ($conditions) ORDER BY k.page_number LIMIT ?',
      [course, user, ...terms, top],
    );
  }

  Future<void> close() async {
    closing = true;
    await tail;
  }
}
