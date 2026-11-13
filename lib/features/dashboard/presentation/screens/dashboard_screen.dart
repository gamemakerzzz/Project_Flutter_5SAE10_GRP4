import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../../profile/models/student.dart';
import '../../data/dashboard_data.dart';
import '../../models/course_progress.dart';
import '../../../courses/models/course_models.dart';
import '../widgets/dashboard_cards.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.student,
    required this.onProfile,
    this.onCourses,
    this.onQuiz,
    this.onFlashcards,
    this.savedCourses,
  });
  final Student student;
  final VoidCallback onProfile;
  final VoidCallback? onCourses;
  final VoidCallback? onQuiz;
  final VoidCallback? onFlashcards;
  final List<Course>? savedCourses;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    final courses =
        savedCourses
            ?.map((c) => CourseProgress(c.title, c.subject, 0, 0xe4f0))
            .toList() ??
        demoCourses.where((c) => student.subjects.contains(c.name)).toList();
    final exams = (savedCourses == null ? demoExams : <UpcomingExam>[])
        .where((e) => student.subjects.contains(e.subject))
        .toList();
    final progress = courses.isEmpty
        ? 0.0
        : courses.map((c) => c.progress).reduce((a, b) => a + b) /
              courses.length;
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, Student!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.firstName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, size: 40),
                        SizedBox(height: 16),
                        Text(
                          'You’re all caught up!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text('No notifications in this demo session.'),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            IconButton(
              tooltip: 'Open profile',
              onPressed: onProfile,
              icon: CircleAvatar(child: Text(student.initials)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6945C7), Color(0xFF4256A8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE3D8FF), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YOUR LEARNING JOURNEY',
                      style: TextStyle(
                        color: Color(0xFFE3D8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Small steps.\nBrilliant possibilities.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Keep showing up for yourself. You’ve got this, ${student.firstName}.',
                style: const TextStyle(color: Color(0xFFE8E3FC), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${courses.length} courses in progress',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFC6B7FF),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 8),
              Text(
                savedCourses == null
                    ? 'Overall progress · Sample learning data'
                    : 'Saved courses · Learning progress is not tracked yet',
                style: const TextStyle(color: Color(0xFFE8E3FC), fontSize: 11),
              ),
            ],
          ),
        ),
        const SectionTitle('Your week at a glance'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: StatisticsCard(
                    label: 'Active Courses',
                    value: '${courses.length}',
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFF8060CB),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatisticsCard(
                    label: 'Study Hours',
                    value: savedCourses == null ? '24.5' : '—',
                    icon: Icons.schedule,
                    color: const Color(0xFF4E82BA),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatisticsCard(
                    label: 'Completed Tasks',
                    value: savedCourses == null ? '18' : '—',
                    icon: Icons.task_alt,
                    color: const Color(0xFF40876C),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatisticsCard(
                    label: 'Upcoming Exams',
                    value: '${exams.length}',
                    icon: Icons.event_note,
                    color: const Color(0xFFB17B3C),
                  ),
                ),
              ],
            );
          },
        ),
        const SectionTitle('Make it a productive day'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in [
              (Icons.auto_awesome, 'AI Tutor'),
              (Icons.calendar_month_outlined, 'Study Planner'),
            ])
              ActionChip(
                avatar: Icon(action.$1, size: 18),
                label: Text(action.$2),
                onPressed: () =>
                    openPage(context, ModulePlaceholder(action.$2)),
              ),
            ActionChip(
              avatar: const Icon(Icons.style_outlined, size: 18),
              label: const Text('Flashcards'),
              onPressed: onFlashcards,
            ),
            ActionChip(
              avatar: const Icon(Icons.quiz_outlined, size: 18),
              label: const Text('Quiz & Exams'),
              onPressed: onQuiz,
            ),
          ],
        ),
        SectionTitle(
          'My Courses',
          action: TextButton(
            onPressed:
                onCourses ??
                () => openPage(context, const ModulePlaceholder('Courses')),
            child: const Text('View All'),
          ),
        ),
        if (courses.isEmpty)
          Panel(
            child: Text(
              savedCourses == null
                  ? 'Your learning journey is a blank canvas. Add subjects in Edit Profile to get started.'
                  : 'No saved courses yet. Open Courses to create your first course.',
            ),
          ),
        for (final course in courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CourseProgressCard(
              course: course,
              onTap:
                  onCourses ??
                  () => openPage(context, ModulePlaceholder(course.name)),
            ),
          ),
        const SectionTitle('Upcoming Exams'),
        if (exams.isEmpty)
          Panel(
            child: Text(
              savedCourses == null
                  ? 'No upcoming demo exams for your selected subjects.'
                  : 'Exam planning is not connected yet.',
            ),
          ),
        for (final exam in exams)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UpcomingExamCard(exam: exam, today: now),
          ),
        const SizedBox(height: 18),
        if (savedCourses == null) const DemoNote(),
      ],
    );
  }
}
