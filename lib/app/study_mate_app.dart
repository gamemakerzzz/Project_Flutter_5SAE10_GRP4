import '../features/courses/data/local_courses_repository.dart';
import '../features/courses/presentation/view_models/courses_view_model.dart';
import '../features/courses/presentation/screens/courses_screen.dart';
import '../features/assessments/presentation/screens/assessments_screen.dart';
import '../features/flashcards/presentation/screens/flashcards_screen.dart';

import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/presentation/view_models/session_controller.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../shared/widgets/ui.dart';
import 'theme/app_theme.dart';

class StudyMateApp extends StatefulWidget {
  const StudyMateApp({super.key, this.demo});
  final bool? demo;
  @override
  State<StudyMateApp> createState() => _StudyMateAppState();
}

class _StudyMateAppState extends State<StudyMateApp> {
  late final session = SessionController(demo: widget.demo);
  @override
  void initState() {
    super.initState();
    session.restore();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      title: 'StudyMate AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: session.themeMode,
      home: session.restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.student == null
          ? WelcomeScreen(session: session)
          : StudentShell(session: session),
    ),
  );
}

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.session});
  final SessionController session;
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int tab = 0;
  // Courses and quizzes are intentionally local-first and share one SQLite DB.
  late final courses = CoursesViewModel(LocalCoursesRepository());
  @override
  void initState() {
    super.initState();
    courses.refresh();
  }

  @override
  void dispose() {
    courses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: tab == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) setState(() => tab = 0);
    },
    child: Scaffold(
      appBar: AppBar(title: const Brand()),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey(tab),
          child: switch (tab) {
            0 => ListenableBuilder(
              listenable: courses,
              builder: (context, _) => DashboardScreen(
                student: widget.session.student!,
                onProfile: () => setState(() => tab = 5),
                onCourses: () => setState(() => tab = 1),
                onQuiz: () => setState(() => tab = 2),
                onFlashcards: () => setState(() => tab = 3),
                savedCourses: courses.courses,
              ),
            ),
            1 => CoursesScreen(model: courses),
            2 => AssessmentsScreen(coursesModel: courses, embedded: true),
            3 => const FlashcardsScreen(),
            4 => const ModulePlaceholder('Study Planner', standalone: false),
            _ => ProfileScreen(session: widget.session),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Flashcards',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );
}
