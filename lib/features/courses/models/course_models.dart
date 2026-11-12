import 'dart:typed_data';

const courseSubjects = [
  'Artificial Intelligence',
  'Mobile Development',
  'Cloud Computing',
  'Software Engineering',
  'Database Administration',
];

enum ProcessingStatus { uploaded, processing, ready, failed }

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.updatedAt,
  });
  final String id, title, subject, description;
  final DateTime updatedAt;
  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'].toString(),
    title: j['title'] as String,
    subject: j['subject'] as String,
    description: j['description'] as String? ?? '',
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

class CourseDocument {
  const CourseDocument({
    required this.id,
    required this.courseId,
    required this.name,
    required this.size,
    required this.status,
    required this.uploadedAt,
    this.pages,
    this.error,
  });
  final String id, courseId, name;
  final int size;
  final ProcessingStatus status;
  final DateTime uploadedAt;
  final int? pages;
  final String? error;
  CourseDocument withStatus(
    ProcessingStatus status, {
    int? pages,
    String? error,
  }) => CourseDocument(
    id: id,
    courseId: courseId,
    name: name,
    size: size,
    status: status,
    uploadedAt: uploadedAt,
    pages: pages ?? this.pages,
    error: error,
  );
  factory CourseDocument.fromJson(Map<String, dynamic> j) => CourseDocument(
    id: j['id'].toString(),
    courseId: j['courseId'].toString(),
    name: j['name'] as String,
    size: j['size'] as int,
    status: ProcessingStatus.values.byName(
      (j['status'] as String).toLowerCase(),
    ),
    uploadedAt: DateTime.parse(j['uploadedAt'] as String),
    pages: j['pages'] as int?,
    error: j['error'] as String?,
  );
}

class SourcePassage {
  const SourcePassage({
    required this.chunkId,
    required this.documentId,
    required this.courseId,
    required this.documentName,
    required this.page,
    required this.excerpt,
    this.score,
    this.sourceNumber,
  });
  final String chunkId, documentId, courseId, documentName, excerpt;
  final int page;
  final double? score;
  final int? sourceNumber;
  SourcePassage scored(double value) => SourcePassage(
    chunkId: chunkId,
    documentId: documentId,
    courseId: courseId,
    documentName: documentName,
    page: page,
    excerpt: excerpt,
    score: value,
    sourceNumber: sourceNumber,
  );
  factory SourcePassage.fromJson(Map<String, dynamic> j) => SourcePassage(
    chunkId: j['chunkId'] as String,
    documentId: j['documentId'].toString(),
    courseId: j['courseId'].toString(),
    documentName: j['documentName'] as String,
    page: j['page'] as int,
    excerpt: j['excerpt'] as String,
    score: (j['score'] as num?)?.toDouble(),
    sourceNumber: j['sourceNumber'] as int?,
  );
}

class RagAnswer {
  const RagAnswer({
    required this.answer,
    required this.sources,
    required this.generated,
  });
  final String answer;
  final List<SourcePassage> sources;
  final bool generated;
}

class SelectedPdf {
  const SelectedPdf(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class CoursesException implements Exception {
  const CoursesException(this.message);
  final String message;
  @override
  String toString() => message;
}
