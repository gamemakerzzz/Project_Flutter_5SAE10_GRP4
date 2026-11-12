# Quiz & Exam Simulator API setup

## What runs locally

The Flutter application and its SQLite database run on the student's device. SQFLite stores attempts, submitted answers, scores, and question payloads in `smart_learning_assessments.db`.

## APIs used by this module

| Service | Purpose | Key required |
| --- | --- | --- |
| Open Trivia DB | Computer-science QCM fallback | No |
| Google Gemini | Generate Flutter/Dart QCM and open questions | Yes |
| OpenAI Responses | Correct a submitted open answer | Yes |

## Local demonstration configuration

Never add keys to source files, `pubspec.yaml`, commits, or screenshots. The project has a local ignored `api_keys.json` file. Replace its two placeholder values once, then launch the VS Code configuration named `Quiz demo with local API keys` with F5.

VS Code passes the file to Flutter without placing keys in a command or in Git. For Git Bash only, the equivalent command remains:

```sh
flutter run -t lib/features/assessments/assessments_demo.dart \
  --dart-define=GEMINI_API_KEY=your_gemini_key \
  --dart-define=OPENAI_API_KEY=your_openai_key
```

Optional overrides:

```sh
--dart-define=GEMINI_MODEL=your_model
--dart-define=OPENAI_MODEL=your_model
```

The app remains usable without keys: choose `Démonstration locale Flutter/Dart`, or choose Open Trivia DB for live QCM. Gemini and OpenAI display a clear setup error rather than silently using a key from source code.

## Production note

Direct AI calls are acceptable only for this private course demonstration. A released app must put Gemini/OpenAI calls behind a backend so API keys are not extractable from the installed application.
