import 'package:flutter/material.dart';

import '../../data/demo_repository.dart';
import '../../data/auth_api.dart';
import '../../../../core/network/api_config.dart';
import '../../../profile/models/student.dart';

class SessionController extends ChangeNotifier {
  SessionController({DemoRepository? repository, bool? demo, AuthApi? api})
    : repository = repository ?? DemoRepository(),
      isDemo = demo ?? ApiConfig.demo,
      api = api ?? AuthApi();
  final DemoRepository repository;
  final bool isDemo;
  final AuthApi api;
  bool restoring = false;
  String? restoreError;
  Future<void> restore() async {
    if (isDemo) return;
    restoring = true;
    notifyListeners();
    try {
      student = await api.restore();
    } catch (e) {
      restoreError = e is FormatException
          ? e.message
          : 'Could not restore your session. Please sign in.';
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Student? student;
  ThemeMode themeMode = ThemeMode.system;
  String? rememberedEmail;
  Future<void> signIn(String email, String password, bool remember) async {
    if (!isDemo) {
      student = await api.authenticate('login', {
        'email': email.trim(),
        'password': password,
      });
      rememberedEmail = remember ? email.trim() : null;
      restoreError = null;
      notifyListeners();
      return;
    }
    await repository.delay();
    if (email.trim().toLowerCase() != 'alex@studymate.demo' ||
        password != 'StudyMate123!') {
      throw const FormatException(
        'Use the demo credentials shown above to explore.',
      );
    }
    rememberedEmail = remember ? email.trim() : null;
    student = repository.sampleStudent();
    notifyListeners();
  }

  Future<void> register(Student value, {String? password}) async {
    if (!isDemo) {
      student = await api.authenticate('register', {
        ...value.toJson(),
        'password': password,
      });
      restoreError = null;
      notifyListeners();
      return;
    }
    await repository.delay();
    student = value;
    notifyListeners();
  }

  Future<void> updateProfile(Student value) async {
    student = isDemo ? value : await api.update(value);
    notifyListeners();
  }

  void setDark(bool dark) {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> logout() async {
    if (!isDemo) await api.logout();
    student = null;
    notifyListeners();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
