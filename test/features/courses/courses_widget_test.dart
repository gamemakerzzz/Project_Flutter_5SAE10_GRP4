import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_learning/app/theme/app_theme.dart';
import 'package:smart_learning/features/courses/data/local_courses_repository.dart';
import 'package:smart_learning/features/courses/data/pdf_import_service.dart';
import 'package:smart_learning/features/courses/models/course_models.dart';
import 'package:smart_learning/features/courses/presentation/screens/courses_screen.dart';
import 'package:smart_learning/features/courses/presentation/screens/course_editor_screen.dart';
import 'package:smart_learning/features/courses/presentation/screens/upload_pdf_screen.dart';
import 'package:smart_learning/features/courses/presentation/screens/semantic_search_screen.dart';
import 'package:smart_learning/features/courses/presentation/view_models/courses_view_model.dart';

import 'courses_repository_test.dart' show FakeExtractor, sample, addCourse;

class FakePicker extends PdfImportService {
  @override
  Future<SelectedPdf?> pick() async => sample();
}

Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Custom subjects can be created and edited without a dropdown crash',
    (tester) async {
      final repo = LocalCoursesRepository(extractor: FakeExtractor([]));
      final course = await repo.saveCourse(
        title: 'Physics',
        subject: 'Quantum mechanics',
        description: '',
      );
      final model = CoursesViewModel(repo);
      addTearDown(model.dispose);
      await model.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CourseEditorScreen(model: model, course: course),
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Edit');
      expect(tester.takeException(), isNull);
      expect(find.text('Quantum mechanics'), findsOneWidget);
      final subject = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Quantum mechanics',
      );
      await tester.enterText(subject, '  Astrophysics  ');
      await tap(tester, 'Save course');
      expect((await repo.listCourses()).single.subject, 'Astrophysics');
    },
  );
  testWidgets(
    'Empty library, create course, details, search, chat and delete',
    (tester) async {
      final model = CoursesViewModel(
        LocalCoursesRepository(extractor: FakeExtractor([])),
      );
      addTearDown(model.dispose);
      await model.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: Scaffold(body: CoursesScreen(model: model)),
        ),
      );
      expect(find.text('Start your course collection'), findsOneWidget);
      await tap(tester, 'Add a course');
      await tester.enterText(
        find.byType(TextFormField).first,
        'Database systems',
      );
      await tap(tester, 'Save course');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, 'Database systems');
      expect(find.text('Course details'), findsOneWidget);
      await tap(tester, 'Search within course');
      expect(find.text('Full-text Search'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Ask AI');
      expect(find.text('Ask AI · Course assistant'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Delete course');
      await tap(tester, 'Delete');
      expect(find.text('Start your course collection'), findsOneWidget);
    },
  );
  testWidgets('Upload validates, imports and shows real processing result', (
    tester,
  ) async {
    final repo = LocalCoursesRepository(
      extractor: FakeExtractor(['Database normalization reduces redundancy.']),
    );
    final c = await addCourse(repo, 'Databases');
    final model = CoursesViewModel(repo);
    addTearDown(model.dispose);
    await model.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => UploadPdfScreen(
                    model: model,
                    courseId: c.id,
                    importer: FakePicker(),
                  ),
                ),
              ),
              child: const Text('Open upload'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'Open upload');
    await tap(tester, 'Select PDF');
    expect(find.text('lesson.pdf'), findsOneWidget);
    await tap(tester, 'Import into local workspace');
    expect(model.docs(c.id).single.status, ProcessingStatus.ready);
    expect(find.text('Open upload'), findsOneWidget);
  });
  testWidgets('Search displays exact source excerpt on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalCoursesRepository(
      extractor: FakeExtractor(['Normalization reduces redundancy.']),
    );
    addTearDown(repo.dispose);
    final c = await addCourse(repo, 'Databases');
    final doc = await repo.upload(c.id, sample());
    await repo.process(doc.id);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        home: SemanticSearchScreen(repository: repo, course: c),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Normalization');
    await tap(tester, 'Search passages');
    await tap(tester, 'lesson.pdf');
    expect(find.text('Normalization reduces redundancy.'), findsOneWidget);
    expect(find.text('Page 1 · Term match 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
