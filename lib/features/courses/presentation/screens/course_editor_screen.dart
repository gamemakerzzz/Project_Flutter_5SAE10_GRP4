import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../models/course_models.dart';
import '../view_models/courses_view_model.dart';
import '../widgets/course_widgets.dart';

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({super.key, required this.model, this.course});
  final CoursesViewModel model;
  final Course? course;
  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description, subject;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.course?.title);
    description = TextEditingController(text: widget.course?.description);
    subject = TextEditingController(
      text: widget.course?.subject ?? courseSubjects.first,
    );
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    subject.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final ok = await widget.model.save(
      id: widget.course?.id,
      title: title.text,
      subject: subject.text.trim(),
      description: description.text,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      Navigator.pop(context);
      notice(context, 'Course saved.');
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.course == null ? 'Create a course' : 'Edit course'),
    ),
    body: PageBody(
      maxWidth: 560,
      children: [
        Text(
          'A home for your ideas.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Organize your PDFs by course, then explore their source passages.',
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: title,
                enabled: !busy,
                maxLength: 100,
                validator: requiredText,
                decoration: const InputDecoration(labelText: 'Course title'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: subject,
                enabled: !busy,
                maxLength: 100,
                validator: requiredText,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                enabled: !busy,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 20),
              if (widget.model.error != null) CourseError(widget.model.error!),
              BusyButton(label: 'Save course', busy: busy, onPressed: save),
            ],
          ),
        ),
      ],
    ),
  );
}
