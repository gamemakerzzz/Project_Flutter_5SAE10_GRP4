# AI handoff - Quiz & Exam Simulator

## Scope

- Branch: `feature/quiz-exam`
- Module: **AI Quiz & Exam Simulator** only.
- Keep `Quiz & Examens` as the in-app French heading.

## Product distinction

Flashcards provide spaced repetition of small cards. This module assesses mastery through QCM/open questions, timed exam simulations, explanations, saved results, and weak-topic feedback.

## Architecture for the school prototype

The app stays local-first and does not use a deployed backend yet:

```text
Flutter/Dart
|- SQFLite: attempts, answers, scores, local history
|- Open Trivia DB: live non-AI QCM fallback
|- Gemini: direct question generation through HTTP
`- OpenAI Responses: direct correction/explanation through HTTP
```

AI keys are not committed. Pass local keys with `--dart-define`. This is suitable only for a private demonstration; a published app must proxy AI requests through a backend.

## Configuration

```text
flutter run -t lib/features/assessments/assessments_demo.dart \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=OPENAI_API_KEY=...
```

Optional model values: `GEMINI_MODEL` and `OPENAI_MODEL`.

For convenience, `api_keys.json` is ignored by Git and `.vscode/launch.json` loads it through `--dart-define-from-file`. Fill the file once and select `Quiz demo with local API keys` in VS Code; do not commit either secret.

## Technologies demonstrated

- Material widgets, `StatefulWidget`, `ListView.builder`, and form validation.
- `Navigator.push` to an attempt-detail route.
- `Future`, `async`/`await`, `FutureBuilder`, HTTP, and JSON.
- SQFLite local persistence with `path`.

## Current implementation

The existing offline Flutter/Dart question bank remains the reliable fallback. New data-layer files provide SQLite persistence, Open Trivia DB requests, configurable Gemini generation, and OpenAI correction after an open answer is checked. `docs/quiz_exam_api_setup.md` contains run-time key instructions.

Validation completed on 2026-11-12:

- `dart analyze lib/features/assessments test/features/assessments` - no issues.
- `flutter test --no-pub test/features/assessments/assessments_test.dart` - 11 tests passed.

## Integration note - 2026-11-13

`origin/feature/courses-rag` was merged into `feature/quiz-exam`. The merged app now includes the courses/RAG, auth, dashboard, and profile work alongside the quiz module. Dependency conflicts were resolved by retaining all required packages (`sqflite`, `path`, `file_picker`, `pdfrx`, and `flutter_secure_storage`) and all generated macOS plugin registrations.

`flutter pub get` succeeds. A full Windows `flutter test --no-pub` currently stops before tests because `pdfium_dart` tries to compile a native PDF helper and the local Visual C++ hook command mishandles a path containing spaces (`C:\\Program Files ...`). This is an environment/native-toolchain issue introduced by the PDF dependency, not a Dart test failure; validate on Android after the emulator/device is ready.
