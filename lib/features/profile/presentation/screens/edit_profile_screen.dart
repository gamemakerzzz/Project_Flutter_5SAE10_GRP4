import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/view_models/session_controller.dart';
import '../../models/student.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late String level, specialty;
  late Set<String> subjects;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final student = widget.session.student!;
    name = TextEditingController(text: student.name);
    level = student.level;
    specialty = student.specialty;
    subjects = student.subjects.toSet();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.updateProfile(
        Student(
          name: name.text.trim(),
          email: widget.session.student!.email,
          level: level,
          specialty: specialty,
          subjects: subjects.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      notice(
        context,
        widget.session.isDemo
            ? 'Profile updated for this demo session.'
            : 'Profile saved.',
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: PageBody(
      maxWidth: 520,
      children: [
        Text(
          'Make this space yours.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text('Your choices shape the subjects on your dashboard.'),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: requiredText,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: level,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Academic Level'),
                items: {...academicLevels, level}
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => level = v!),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: specialty,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Specialty'),
                items: {...specialties, specialty}
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => specialty = v!),
              ),
              const SectionTitle('Choose your subjects'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subjectOptions
                    .map(
                      (s) => FilterChip(
                        label: Text(s),
                        selected: subjects.contains(s),
                        onSelected: (selected) => setState(() {
                          selected ? subjects.add(s) : subjects.remove(s);
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 28),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              BusyButton(onPressed: save, busy: busy, label: 'Save Changes'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (widget.session.isDemo) const DemoNote(),
      ],
    ),
  );
}
