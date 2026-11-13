import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/view_models/session_controller.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final student = session.student!;
    return PageBody(
      children: [
        Text(
          'Your learning identity',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('A little about you. A world of possibilities ahead.'),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                child: Text(
                  student.initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                student.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(student.email, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Chip(
                avatar: const Icon(Icons.school_outlined, size: 18),
                label: Text(
                  session.isDemo ? 'Student · Demo profile' : 'Student account',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    openPage(context, EditProfileScreen(session: session)),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
        const SectionTitle('Academic details'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACADEMIC LEVEL',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                student.level,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(height: 30),
              const Text(
                'SPECIALTY',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                student.specialty,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SectionTitle('My Subjects'),
        if (student.subjects.isEmpty)
          const Panel(
            child: Text(
              'No subjects yet. Choose your subjects in Edit Profile.',
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: student.subjects
                .map((s) => Chip(label: Text(s)))
                .toList(),
          ),
        const SectionTitle('App Settings'),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark appearance'),
                subtitle: const Text('For late-night inspiration'),
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: session.setDark,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('StudyMate AI'),
                subtitle: Text(
                  session.isDemo
                      ? 'Student experience · Demo version'
                      : 'Connected student workspace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  session.isDemo ? 'Leave your demo session?' : 'Sign out?',
                ),
                content: Text(
                  session.isDemo
                      ? 'Profile changes will be cleared. You can explore again with the demo account.'
                      : 'Your courses and PDFs stay saved on the server. You can access them after signing in again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                await session.logout();
              } catch (_) {
                if (context.mounted) {
                  notice(
                    context,
                    'Could not remove the saved token. Please retry logout.',
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
        const SizedBox(height: 16),
        if (session.isDemo) const DemoNote(),
      ],
    );
  }
}
