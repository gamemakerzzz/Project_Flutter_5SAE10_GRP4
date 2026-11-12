# StudyMate AI — Authentication, Profile & Dashboard

> Update, 16 October 2026: real registration/login, secure JWT storage, persistent profile and server course data are now connected. See [backend guide](../backend/README.md). Use `--dart-define=DEMO_MODE=true` to run the original demo described below.

## Run the demo

Run from the repository root:

```sh
flutter run --dart-define=DEMO_MODE=true
```

On Welcome, choose **I already have an account**, then **Fill demo credentials**:
- Email: alex@studymate.demo
- Password: StudyMate123!

These public sample credentials select a fictional profile; they do not authenticate a real identity. Registration creates a temporary profile and opens the dashboard. Logout or app restart discards the profile. Registered demo profiles cannot sign in again. Remember me retains only the email in memory during the app session. Passwords are neither persisted nor transmitted. Password reset sends no email.

## Screens and behavior

- Welcome: local Flutter illustration, registration and login entry points.
- Login: validation, password visibility, sample credentials, error and loading states.
- Register: email, password confirmation and strength, academic selectors, demo terms.
- Forgot Password: validated email and explicit simulated result.
- Dashboard: greeting, profile avatar, progress, statistics, courses, upcoming exams, notifications empty state, quick actions.
- Profile: student identity, academic details, subjects, theme setting, logout confirmation.
- Edit Profile: name, level, specialty and subjects; changes update the dashboard immediately.
- Courses, Planner, AI Tutor, Flashcards and Assessments: clearly labeled integration placeholders.

No new package dependencies, external images, backend, database, Firebase or AI APIs are used. Light and dark Material 3 themes are available. Subject selection can be empty; dashboard and profile then show appropriate empty states. Exam dates are relative to the day the dashboard is opened. Study hours and completed tasks are fixed sample statistics.

## File map

- lib/main.dart: application entry point, preserves the MyApp public widget.
- lib/app/study_mate_app.dart: app theme binding, session gate and bottom navigation.
- lib/app/theme/app_theme.dart: shared Material 3 design system.
- lib/shared/widgets/ui.dart: reusable layout, brand, notices, buttons and placeholders.
- lib/features/auth/data/demo_repository.dart: sample student and simulated latency.
- lib/features/auth/presentation/view_models/session_controller.dart: in-memory session and preferences.
- lib/features/auth/presentation/screens/: welcome, login, register, forgot password.
- lib/features/profile/models/student.dart: immutable student and academic choices.
- lib/features/profile/presentation/screens/: profile and edit profile.
- lib/features/dashboard/models/course_progress.dart: progress and exam data types.
- lib/features/dashboard/data/dashboard_data.dart: fictional courses and exams.
- lib/features/dashboard/presentation/widgets/dashboard_cards.dart: statistics, course and exam cards.
- lib/features/dashboard/presentation/screens/dashboard_screen.dart: dashboard composition.
- test/widget_test.dart: validation, profile sync, empty state, logout, registration, reset, small-screen and dark-theme checks.

The existing folders and .gitkeep files in other feature modules are preserved.

## Validation

```sh
flutter analyze lib test
flutter test
flutter build apk --debug
```

The full `flutter analyze` command also traverses the independent legacy `template_reference` app and reports its missing dependencies and outdated APIs. Those files are intentionally untouched; the README already recommends the scoped analysis above.

## Integration boundaries

Replace DemoRepository/session demo methods with the team's agreed authentication and profile services. Define real authentication errors, secure token handling and account persistence only once the backend contract is agreed. Add real password recovery and production terms at that time.

Wire module placeholders in the app shell and dashboard to each module's public route. Replace dashboard fixtures with agreed progress, course and exam repositories. Keep actual credentials and AI provider secrets out of the Flutter app. Agree shared student/course identifiers and data contracts with the team before integration.

Validation completed: targeted analysis passed; all 5 widget tests passed; debug APK built and installed on Medium Phone API 37.0 (emulator-5554). Welcome, login, dashboard and profile were visually checked on Android. Full analysis reports 1781 pre-existing legacy-reference issues. No commit or push was made.
