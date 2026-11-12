import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_learning/features/auth/data/auth_api.dart';
import 'package:smart_learning/features/auth/presentation/view_models/session_controller.dart';
import 'package:smart_learning/features/courses/data/courses_api_service.dart';
import 'package:smart_learning/features/courses/models/course_models.dart';

class MemoryTokens implements TokenStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  final user = {
    'fullName': 'Real Student',
    'email': 'real@example.com',
    'academicLevel': 'Bachelor 3',
    'specialty': 'Computer Science',
    'subjects': ['Artificial Intelligence'],
  };
  test(
    'connected login, restore and logout use secure-storage abstraction',
    () async {
      final storage = MemoryTokens();
      final api = AuthApi(
        storage: storage,
        client: MockClient((r) async {
          if (r.url.path == '/api/auth/login') {
            expect(jsonDecode(r.body)['password'], 'Password123!');
            return http.Response(
              jsonEncode({'accessToken': 'test-token', 'user': user}),
              200,
            );
          }
          expect(r.headers['Authorization'], 'Bearer test-token');
          return http.Response(jsonEncode(user), 200);
        }),
      );
      final session = SessionController(demo: false, api: api);
      await session.signIn('real@example.com', 'Password123!', true);
      expect(session.student!.name, 'Real Student');
      expect(storage.value, 'test-token');
      session.student = null;
      await session.restore();
      expect(session.student!.email, 'real@example.com');
      await session.logout();
      expect(storage.value, isNull);
      expect(session.student, isNull);
      session.dispose();
    },
  );
  test(
    'API failures never produce a demo session and expired token is cleared',
    () async {
      final storage = MemoryTokens()..value = 'expired';
      final api = AuthApi(
        storage: storage,
        client: MockClient(
          (_) async => http.Response('{"message":"Session expired"}', 401),
        ),
      );
      final session = SessionController(demo: false, api: api);
      await session.restore();
      expect(storage.value, isNull);
      expect(session.student, isNull);
      expect(session.restoreError, 'Session expired');
      await expectLater(
        session.signIn('alex@studymate.demo', 'StudyMate123!', false),
        throwsFormatException,
      );
      expect(session.student, isNull);
      session.dispose();
    },
  );
  test('RAG 501 is an explicit unavailable state', () async {
    final api = CoursesApiService(
      baseUri: Uri.parse('https://example.com'),
      tokenProvider: () async => 'token',
      client: MockClient(
        (_) async => http.Response('{"code":"RAG_NOT_AVAILABLE"}', 501),
      ),
    );
    await expectLater(
      api.ask('course', 'question'),
      throwsA(
        isA<CoursesException>().having(
          (e) => e.message,
          'message',
          contains('not yet available'),
        ),
      ),
    );
    api.dispose();
  });
}
