import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_learning/features/courses/data/local_courses_repository.dart';
import 'package:smart_learning/features/courses/models/course_models.dart';
import 'package:smart_learning/features/courses/presentation/view_models/courses_view_model.dart';

class ControlledRepository extends LocalCoursesRepository {
  final requests = <Completer<List<Course>>>[];

  @override
  Future<List<Course>> listCourses() {
    final request = Completer<List<Course>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<CourseDocument>> documents(String courseId) async => [];
}

Course course(String id) => Course(
  id: id,
  title: id,
  subject: courseSubjects.first,
  description: '',
  updatedAt: DateTime(2026),
);

void main() {
  test('an older refresh cannot overwrite the latest course list', () async {
    final repository = ControlledRepository();
    final model = CoursesViewModel(repository);
    addTearDown(model.dispose);

    final older = model.refresh();
    final newer = model.refresh();
    repository.requests[1].complete([course('new')]);
    await newer;
    repository.requests[0].complete([course('old')]);
    await older;

    expect(model.courses.single.id, 'new');
    expect(model.loading, false);
    expect(model.error, isNull);
  });

  test('an outdated error cannot end or fail the latest refresh', () async {
    final repository = ControlledRepository();
    final model = CoursesViewModel(repository);
    addTearDown(model.dispose);

    final older = model.refresh();
    final newer = model.refresh();
    repository.requests[0].completeError(const CoursesException('Old error'));
    await older;
    expect(model.loading, true);
    expect(model.error, isNull);
    repository.requests[1].complete([course('new')]);
    await newer;
    expect(model.loading, false);
  });

  test('disposal ignores pending results and prevents new actions', () async {
    final repository = ControlledRepository();
    final model = CoursesViewModel(repository);
    final pending = model.refresh();
    model.dispose();
    repository.requests.single.complete([course('late')]);
    await pending;
    expect(model.courses, isEmpty);
    var called = false;
    expect(await model.run(() async => called = true), false);
    expect(called, false);
  });
}
