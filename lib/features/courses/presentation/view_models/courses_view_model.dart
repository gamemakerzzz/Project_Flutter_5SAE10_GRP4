import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/courses_repository.dart';
import '../../models/course_models.dart';

class CoursesViewModel extends ChangeNotifier {
  CoursesViewModel(this.repository) {
    if (!repository.isLocal) {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!loading && !working) refresh();
      });
    }
  }
  final CoursesRepository repository;
  List<Course> courses = [];
  Map<String, List<CourseDocument>> documents = {};
  bool loading = false;
  bool working = false;
  bool _disposed = false;
  int _refreshGeneration = 0;
  String? error;
  Timer? _poll;
  bool get isLocal => repository.isLocal;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String message(Object e) =>
      e is CoursesException ? e.message : 'Something went wrong. Please retry.';
  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    loading = true;
    error = null;
    _notify();
    try {
      final next = await repository.listCourses();
      if (_disposed || generation != _refreshGeneration) return;
      final entries = await Future.wait(
        next.map((c) async => MapEntry(c.id, await repository.documents(c.id))),
      );
      if (_disposed || generation != _refreshGeneration) return;
      courses = next;
      documents = Map.fromEntries(entries);
    } catch (e) {
      if (!_disposed && generation == _refreshGeneration) {
        error = message(e);
      }
    } finally {
      if (!_disposed && generation == _refreshGeneration) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> run(Future<void> Function() action) async {
    if (_disposed || working) return false;
    working = true;
    error = null;
    _notify();
    var success = false;
    try {
      await action();
      success = true;
    } catch (e) {
      error = message(e);
    } finally {
      final operationError = error;
      await refresh();
      error = operationError ?? error;
      working = false;
      _notify();
    }
    return success;
  }

  Future<bool> save({
    String? id,
    required String title,
    required String subject,
    required String description,
  }) => run(() async {
    await repository.saveCourse(
      id: id,
      title: title,
      subject: subject,
      description: description,
    );
  });
  Future<bool> removeCourse(String id) =>
      run(() => repository.deleteCourse(id));
  Future<bool> removeDocument(String id) =>
      run(() => repository.deleteDocument(id));
  Future<bool> retry(String id) => run(() async {
    final future = repository.process(id);
    await refresh();
    await future;
  });
  Future<CourseDocument?> importPdf(String courseId, SelectedPdf pdf) async {
    CourseDocument? uploaded;
    final success = await run(() async {
      uploaded = await repository.upload(courseId, pdf);
      if (repository.isLocal) {
        await refresh();
        final future = repository.process(uploaded!.id);
        await refresh();
        await future;
      }
    });
    if (!success || uploaded == null) return null;
    return documents[courseId]
            ?.where((d) => d.id == uploaded!.id)
            .firstOrNull ??
        uploaded;
  }

  Course? course(String id) => courses.where((c) => c.id == id).firstOrNull;
  List<CourseDocument> docs(String id) => documents[id] ?? [];
  int get documentCount =>
      documents.values.fold(0, (count, list) => count + list.length);
  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    _poll?.cancel();
    repository.dispose();
    super.dispose();
  }
}
