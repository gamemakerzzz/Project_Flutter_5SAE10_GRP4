import 'dart:typed_data';

import '../models/course_models.dart';

abstract class CoursesRepository {
  bool get isLocal;
  Future<List<Course>> listCourses();
  Future<Course> saveCourse({
    String? id,
    required String title,
    required String subject,
    required String description,
  });
  Future<void> deleteCourse(String id);
  Future<List<CourseDocument>> documents(String courseId);
  Future<CourseDocument> upload(String courseId, SelectedPdf pdf);
  Future<void> process(String documentId);
  Future<void> deleteDocument(String documentId);
  Future<Uint8List> content(String documentId);
  Future<List<SourcePassage>> search(String courseId, String query);
  Future<RagAnswer> ask(String courseId, String question);
  void dispose() {}
}
