import 'dart:convert';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

import '../repositories/store.dart';
import '../http/api_error.dart';

Future<String> hashPassword(String password) =>
    Isolate.run(() => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12)));
Future<bool> verifyPassword(String password, String hash) =>
    Isolate.run(() => BCrypt.checkpw(password, hash));

class AuthService {
  AuthService(this.store, this.secret);
  final Store store;
  final String secret;
  static const ttl = Duration(minutes: 30);
  String identify(String? header) {
    try {
      if (header == null || !header.startsWith('Bearer ')) {
        throw const FormatException();
      }
      final token = header.substring(7);
      final tokenHeader = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(token.split('.').first)),
        ),
      );
      if (tokenHeader is! Map || tokenHeader['alg'] != 'HS256') {
        throw const FormatException();
      }
      final jwt = JWT.verify(token, SecretKey(secret), issuer: 'studymate');
      final id = jwt.subject;
      if (id == null ||
          jwt.issuer != 'studymate' ||
          jwt.payload['exp'] == null) {
        throw const FormatException();
      }
      store.profile(id);
      return id;
    } catch (_) {
      throw const ApiError(
        401,
        'UNAUTHORIZED',
        'Session missing or expired. Please sign in.',
      );
    }
  }

  Json tokens(String id) => {
    'accessToken': JWT(
      {},
      subject: id,
      issuer: 'studymate',
    ).sign(SecretKey(secret), algorithm: JWTAlgorithm.HS256, expiresIn: ttl),
    'tokenType': 'Bearer',
    'expiresIn': ttl.inSeconds,
    'user': store.profile(id),
  };
  String email(Json body) {
    final value = field(body, 'email', max: 254).toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      throw const ApiError(400, 'VALIDATION_ERROR', 'Invalid email.');
    }
    return value;
  }

  String password(Json body) {
    final value = body['password'];
    if (value is! String ||
        value.length < 8 ||
        utf8.encode(value).length > 72) {
      throw const ApiError(
        400,
        'VALIDATION_ERROR',
        'Password must contain at least 8 characters and at most 72 UTF-8 bytes.',
      );
    }
    return value;
  }

  Future<Json> register(Json body) async {
    final mail = email(body),
        pass = password(body),
        name = field(body, 'fullName', max: 100),
        level = field(body, 'academicLevel', max: 80),
        specialty = field(body, 'specialty', max: 100);
    if (store.rows('SELECT id FROM users WHERE email=?', [mail]).isNotEmpty) {
      throw const ApiError(
        409,
        'EMAIL_EXISTS',
        'An account with this email already exists.',
      );
    }
    final hash = await hashPassword(pass);
    final id = const Uuid().v4(),
        now = DateTime.now().toUtc().toIso8601String();
    store.database.transaction(() {
      if (store.rows('SELECT id FROM users WHERE email=?', [mail]).isNotEmpty) {
        throw const ApiError(
          409,
          'EMAIL_EXISTS',
          'An account with this email already exists.',
        );
      }
      store.execute('INSERT INTO users VALUES(?,?,?,?,?,?,?,?)', [
        id,
        name,
        mail,
        hash,
        level,
        specialty,
        now,
        now,
      ]);
      subjects(id, body['subjects'] ?? <String>[]);
    });
    return tokens(id);
  }

  Future<Json> login(Json body) async {
    final mail = email(body), pass = password(body);
    final users = store.rows(
      'SELECT id,password_hash FROM users WHERE email=?',
      [mail],
    );
    // A fixed valid bcrypt hash keeps unknown-account verification computationally comparable.
    final hash = users.isEmpty
        ? r'$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW'
        : users.first['password_hash'] as String;
    final valid = await verifyPassword(pass, hash);
    if (!valid || users.isEmpty) {
      throw const ApiError(
        401,
        'INVALID_CREDENTIALS',
        'Incorrect email or password.',
      );
    }
    return tokens(users.first['id'] as String);
  }

  void subjects(String id, dynamic values) {
    if (values is! List ||
        values.length > 20 ||
        values.any((v) => v is! String || v.trim().isEmpty || v.length > 100)) {
      throw const ApiError(400, 'VALIDATION_ERROR', 'Invalid subjects.');
    }
    store.execute('DELETE FROM user_subjects WHERE user_id=?', [id]);
    for (final name in values.cast<String>().map((v) => v.trim()).toSet()) {
      store.execute('INSERT OR IGNORE INTO subjects(id,name) VALUES(?,?)', [
        const Uuid().v4(),
        name,
      ]);
      store.execute(
        'INSERT INTO user_subjects SELECT ?,id FROM subjects WHERE name=?',
        [id, name],
      );
    }
  }

  Json update(String id, Json body) {
    final name = field(body, 'fullName', max: 100),
        level = field(body, 'academicLevel', max: 80),
        specialty = field(body, 'specialty', max: 100);
    store.database.transaction(() {
      store.execute(
        'UPDATE users SET full_name=?,academic_level=?,specialty=?,updated_at=? WHERE id=?',
        [name, level, specialty, DateTime.now().toUtc().toIso8601String(), id],
      );
      subjects(id, body['subjects']);
    });
    return store.profile(id);
  }
}
