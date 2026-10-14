# AI Quiz & Exam Simulator — interface demo

## Preview

From the Flutter project root:

```sh
flutter pub get
flutter run -t lib/features/assessments/assessments_demo.dart
```

The module is isolated from the shared `main.dart`. To integrate it later, import `presentation/screens/assessments_screen.dart` and open `const AssessmentsScreen()` from your dashboard/router. Keep one view model alive if history should survive navigation between modules.

## Interface flows

- Configuration: Flutter/Dart sample course, three difficulty levels, QCM/open/mixed types, 3/5/6 questions.
- Practice: elapsed time, question navigation, optional per-question corrections and explanations.
- Exam: 1/5/10/20/30 minutes, countdown, corrections hidden until submission, automatic submission on timeout.
- Results: score, submitted answers, expected answers and explanations.
- History: completed attempts, best score, timestamps and reopening detailed results.
- Confirmation before manual submission or abandonment.

## Demo limitations

This is an interface prototype, not an AI integration. Sample questions are shuffled from an authored bank. Open answers use a keyword match visibly labeled as simulated. Scores are indicative, not reliable educational grading. History is in memory for the lifetime of the view model and is lost on restart. No API, database, authentication, or secure exam enforcement is included. A terminated process is not a resumable exam; on resumption while still running, the deadline is checked.

## Structure

- `models/assessment.dart`: configuration, questions, results.
- `data/demo_question_repository.dart`: sample bank.
- `presentation/view_models/assessment_view_model.dart`: state and timer.
- `presentation/screens/assessments_screen.dart`: setup, session, results, history.
- `presentation/widgets/assessment_widgets.dart`: cards, banner, answer field.
- `assessments_demo.dart`: standalone preview.

No additional packages required. Palette and gradient direction are inspired by `template_reference/lib/theme/config.dart` from https://github.com/Hash-Studios/e-learning-app. Its original source and BSD license remain in the project. Legacy template APIs are not imported.

## Validation

```sh
dart format lib/features/assessments test/features/assessments
flutter analyze lib/features/assessments test/features/assessments
flutter test test/features/assessments
```

Eight tests cover selection, scoring, immutable history, answer locking, hidden exam corrections, late-answer rejection, timeout, phone layout, and answer retention.
