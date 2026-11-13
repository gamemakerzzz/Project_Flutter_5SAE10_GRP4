# Smart Learning

Flutter e-learning platform for the five-member 5SAE10 GRP4 team.

## Setup

Use the same Flutter SDK version across the team. The initial project requires Dart ^3.13.4; record the agreed Flutter version here before adding dependencies.

```sh
flutter --version
flutter pub get
flutter run
```

## Structure

- `lib/app/`: application setup, routing, dependency wiring, and theme.
- `lib/core/`: common networking, storage, and error handling.
- `lib/shared/widgets/`: UI components reused by multiple features.
- `lib/features/`: auth, profile, dashboard, courses, tutor, assessments, planner, and flashcards.
- `test/features/`: feature tests; `integration_test/`: complete user flows.
- `docs/`: architecture and API agreements.
- `template_reference/`: source reference from Hash Studios; independent legacy Flutter app, not imported by the main app.

Feature folders contain models, data, screens, widgets, and view models. Add domain logic only when needed. Empty folders are tracked with `.gitkeep`. The flashcards feature is implemented; the application entry point opens its workspace.

## Team workflow

Build authentication, profile, and navigation together using separate task branches. Each member then owns one module:

| Module | Starting branch |
| --- | --- |
| Smart Courses and RAG | `feature/courses-rag` |
| AI Tutor and Mind Map | `feature/tutor-mindmap` |
| AI Quiz and Exam Simulator | `feature/quiz-exam` |
| Smart Planner and Recommendations | `feature/planner-recommendations` |
| AI Flashcards and Spaced Repetition | `feature/flashcards-repetition` |

Assign actual member names in GitHub Issues. These branches start at the same baseline; use smaller task branches for later changes. Open pull requests into `main`, request a teammate review, and merge frequently. Coordinate changes to routing, dependencies, shared models, and theme.

Before opening a pull request:

```sh
dart format .
flutter analyze
flutter test
```

The reference app has its own legacy dependencies. Run checks from the project root and target `lib` and `test` when checking only the new application, for example `flutter analyze lib test` and `dart format lib test`.

## Template attribution

Reference: https://github.com/Hash-Studios/e-learning-app

Copyright (c) 2020 Hash Studios. The reference source retains its BSD 3-Clause license at `template_reference/LICENSE.txt`. Preserve the applicable notices when copying code into this application. The reference project's original Dart constraint excludes Dart 3, so copied code and dependencies need adaptation.

## Flashcards module

AI Flashcards & Spaced Repetition is implemented. See [setup, API and test instructions](docs/flashcards.md). Start the Python PDF/AI service and run Flutter web on port 8080. Upload a PDF to generate flashcards with Claude Sonnet 5.5. Set ANTHROPIC_API_KEY in backend/.env; cards and review progress are stored with SQFlite (including its browser SQLite adapter). An example deck allows review testing without a key.
