import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_learning/features/assessments/assessments_demo.dart';
import 'package:smart_learning/features/assessments/data/demo_question_repository.dart';
import 'package:smart_learning/features/assessments/models/assessment.dart';
import 'package:smart_learning/features/assessments/presentation/screens/assessments_screen.dart';
import 'package:smart_learning/features/assessments/presentation/view_models/assessment_view_model.dart';

void main() {
  test(
    'Every difficulty and question mix produces the requested unique questions',
    () {
      final repository = DemoQuestionRepository(random: Random(3));
      for (final difficulty in Difficulty.values) {
        for (final mix in QuestionMix.values) {
          final questions = repository.generate(
            AssessmentConfig(difficulty: difficulty, mix: mix, count: 6),
          );
          expect(questions.length, 6);
          expect(questions.map((q) => q.id).toSet().length, 6);
          if (mix == QuestionMix.mixed) {
            expect(
              questions.where((q) => q.kind == QuestionKind.open).length,
              3,
            );
          } else {
            expect(
              questions.every(
                (q) =>
                    q.kind ==
                    (mix == QuestionMix.open
                        ? QuestionKind.open
                        : QuestionKind.multipleChoice),
              ),
              isTrue,
            );
          }
        }
      }
    },
  );

  test(
    'Correct answers score, blanks do not, and saved results are immutable',
    () {
      final vm = AssessmentViewModel();
      addTearDown(vm.dispose);
      vm.start(
        const AssessmentConfig(mix: QuestionMix.multipleChoice, count: 3),
      );
      vm.answer(vm.current.correctIndex.toString());
      vm.finish();
      expect(vm.result!.correct, 1);
      expect(vm.result!.percentage, 33);
      expect(vm.history.length, 1);
      vm.finish();
      expect(vm.history.length, 1);
      vm.start(const AssessmentConfig());
      expect(vm.history.first.correct, 1);
    },
  );

  test(
    'Practice corrections lock answers but exam corrections remain hidden',
    () {
      final vm = AssessmentViewModel();
      addTearDown(vm.dispose);
      vm.start(const AssessmentConfig(mix: QuestionMix.multipleChoice));
      final correct = vm.current.correctIndex.toString();
      vm.answer(correct);
      vm.reveal();
      vm.answer('invalid');
      expect(vm.answers[vm.current.id], correct);
      vm.start(const AssessmentConfig(mode: AssessmentMode.exam));
      vm.answer('0');
      vm.reveal();
      expect(vm.revealed, isEmpty);
    },
  );

  test(
    'Deadline submission catches delayed ticks and does not duplicate history',
    () {
      var now = DateTime(2026, 10, 14, 12);
      final vm = AssessmentViewModel(now: () => now);
      addTearDown(vm.dispose);
      vm.start(const AssessmentConfig(mode: AssessmentMode.exam, minutes: 1));
      now = now.add(const Duration(seconds: 75));
      vm.refreshClock();
      vm.refreshClock();
      expect(vm.stage, AssessmentStage.result);
      expect(vm.result!.timedOut, isTrue);
      expect(vm.result!.elapsed, const Duration(minutes: 1));
      expect(vm.history.length, 1);
    },
  );

  test('An answer arriving after the deadline is not accepted', () {
    var now = DateTime(2026, 10, 14);
    final vm = AssessmentViewModel(now: () => now);
    addTearDown(vm.dispose);
    vm.start(const AssessmentConfig(mode: AssessmentMode.exam, minutes: 1));
    now = now.add(const Duration(minutes: 1));
    vm.answer('0');
    expect(vm.result!.answers, isEmpty);
    expect(vm.result!.timedOut, isTrue);
  });

  testWidgets('Demo opens at phone width and shows its empty history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AssessmentsDemoApp());
    expect(find.text('Quiz & Examens'), findsOneWidget);
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text('Votre première session vous attend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Open answers survive navigation and results enter history', (
    tester,
  ) async {
    final vm = AssessmentViewModel();
    addTearDown(vm.dispose);
    vm.start(const AssessmentConfig(mix: QuestionMix.open, count: 3));
    await tester.pumpWidget(
      MaterialApp(home: AssessmentsScreen(viewModel: vm)),
    );
    final expected = vm.current.expectedAnswer;
    await tester.enterText(find.byType(TextField), expected);
    vm.goTo(1);
    await tester.pump();
    vm.goTo(0);
    await tester.pump();
    expect(find.widgetWithText(TextField, expected), findsOneWidget);
    vm.finish();
    await tester.pump();
    expect(find.text('Correction détaillée'), findsOneWidget);
    expect(vm.history.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Exam expiry switches the visible screen to results', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 14);
    final vm = AssessmentViewModel(now: () => now);
    addTearDown(vm.dispose);
    vm.start(const AssessmentConfig(mode: AssessmentMode.exam, minutes: 1));
    await tester.pumpWidget(
      MaterialApp(home: AssessmentsScreen(viewModel: vm)),
    );
    expect(find.text('Vérifier ma réponse'), findsNothing);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Correction détaillée'), findsOneWidget);
    expect(vm.result!.timedOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}
