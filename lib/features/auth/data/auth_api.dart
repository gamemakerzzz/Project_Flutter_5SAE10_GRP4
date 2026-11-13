import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../profile/models/student.dart';

abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  final storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: 'studymate.jwt');
  @override
  Future<void> write(String token) =>
      storage.write(key: 'studymate.jwt', value: token);
  @override
  Future<void> clear() => storage.delete(key: 'studymate.jwt');
}

class AuthApi {
  AuthApi({Uri? baseUri, http.Client? client, TokenStorage? storage})
    : baseUri = baseUri ?? ApiConfig.baseUri,
      client = client ?? http.Client(),
      storage = storage ?? SecureTokenStorage();
  final Uri baseUri;
  final http.Client client;
  final TokenStorage storage;
  String? token;
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    ApiConfig.validate(baseUri);
    final req = http.Request(method, baseUri.resolve(path))
      ..headers['Accept'] = 'application/json';
    if (authenticated) {
      if (token == null) throw const FormatException('Please sign in.');
      req.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(const Duration(seconds: 45));
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (authenticated && response.statusCode == 401) {
          token = null;
          await storage.clear();
        }
        throw FormatException(
          data['message'] as String? ??
              'Request failed (${response.statusCode}).',
        );
      }
      return data;
    } on TimeoutException {
      throw const FormatException('The server timed out. Please retry.');
    } on http.ClientException {
      throw const FormatException(
        'Cannot reach StudyMate server. Check your connection.',
      );
    }
  }

  Future<Student> authenticate(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final data = await send('POST', '/api/auth/$endpoint', body: body);
    final value = data['accessToken'] as String;
    await storage.write(value);
    token = value;
    return Student.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<Student?> restore() async {
    token = await storage.read();
    if (token == null) return null;
    return Student.fromJson(
      await send('GET', '/api/users/me', authenticated: true),
    );
  }

  Future<Student> update(Student value) async => Student.fromJson(
    await send(
      'PUT',
      '/api/users/me',
      authenticated: true,
      body: value.toJson(),
    ),
  );
  Future<void> logout() async {
    await storage.clear();
    token = null;
  }

  void dispose() => client.close();
}
