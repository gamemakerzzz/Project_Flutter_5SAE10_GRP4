import '../database/database.dart';
import '../http/api_error.dart';

typedef Json = Map<String, dynamic>;

class Store {
  Store(this.database);
  final AppDatabase database;
  List<Json> rows(String sql, [List<Object?> args = const []]) => database.db
      .select(sql, args)
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
  void execute(String sql, [List<Object?> args = const []]) =>
      database.db.execute(sql, args);
  Json course(String user, String id) {
    final result = rows('SELECT * FROM courses WHERE id=? AND user_id=?', [
      id,
      user,
    ]);
    if (result.isEmpty) {
      throw const ApiError(404, 'NOT_FOUND', 'Course not found.');
    }
    return result.first;
  }

  Json document(String user, String id) {
    final result = rows(
      'SELECT d.* FROM documents d JOIN courses c ON c.id=d.course_id WHERE d.id=? AND c.user_id=?',
      [id, user],
    );
    if (result.isEmpty) {
      throw const ApiError(404, 'NOT_FOUND', 'Document not found.');
    }
    return result.first;
  }

  Json profile(String id) {
    final result = rows('SELECT * FROM users WHERE id=?', [id]);
    if (result.isEmpty) {
      throw const ApiError(401, 'UNAUTHORIZED', 'Please sign in again.');
    }
    final u = result.first;
    return {
      'id': u['id'],
      'fullName': u['full_name'],
      'email': u['email'],
      'academicLevel': u['academic_level'],
      'specialty': u['specialty'],
      'subjects': rows(
        'SELECT s.name FROM subjects s JOIN user_subjects us ON us.subject_id=s.id WHERE us.user_id=? ORDER BY s.name',
        [id],
      ).map((s) => s['name']).toList(),
    };
  }

  static Json courseJson(Json c) => {
    'id': c['id'],
    'title': c['title'],
    'subject': c['subject'],
    'description': c['description'],
    'updatedAt': c['updated_at'],
  };
  static Json documentJson(Json d) => {
    'id': d['id'],
    'courseId': d['course_id'],
    'name': d['original_filename'],
    'size': d['size_bytes'],
    'status': d['status'],
    'uploadedAt': d['uploaded_at'],
    'pages': d['page_count'],
    'error': d['error_message'],
  };
}
