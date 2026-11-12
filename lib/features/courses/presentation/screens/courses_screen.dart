import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../view_models/courses_view_model.dart';
import '../widgets/course_widgets.dart';
import 'course_details_screen.dart';
import 'course_editor_screen.dart';
import 'pdf_viewer_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({
    super.key,
    required this.model,
    this.standalone = false,
  });
  final CoursesViewModel model;
  final bool standalone;
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String query = '', subject = 'All subjects';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final filtered = model.courses
          .where(
            (c) =>
                (subject == 'All subjects' || c.subject == subject) &&
                '${c.title} ${c.subject}'.toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
          .toList();
      final recent = model.documents.values.expand((d) => d).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      final body = PageBody(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Courses',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh courses',
                onPressed: model.loading ? null : model.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Your knowledge, in one thoughtful space.'),
          const SizedBox(height: 20),
          CourseModeBanner(local: model.isLocal),
          const SizedBox(height: 20),
          Panel(
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 34,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${model.courses.length} courses · ${model.documentCount} documents',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search courses',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in [
                  'All subjects',
                  ...model.courses.map((c) => c.subject).toSet(),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        s == 'All subjects'
                            ? s
                            : '$s (${model.courses.where((c) => c.subject == s).fold<int>(0, (n, c) => n + model.docs(c.id).length)})',
                      ),
                      selected: subject == s,
                      onSelected: (_) => setState(() => subject = s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: model.working
                ? null
                : () => openPage(context, CourseEditorScreen(model: model)),
            icon: const Icon(Icons.add),
            label: const Text('Add a course'),
          ),
          if (model.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (model.error != null)
            CourseError(model.error!, retry: model.refresh),
          const SectionTitle('Your collection'),
          if (filtered.isEmpty && !model.loading)
            Panel(
              child: Column(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 54,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    model.courses.isEmpty
                        ? 'Start your course collection'
                        : 'No matching courses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    model.courses.isEmpty
                        ? 'Create a course and import your first PDF. Your sources stay connected to every passage.'
                        : 'Try another title or subject filter.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final course in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => openPage(
                    context,
                    CourseDetailsScreen(model: model, courseId: course.id),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_open_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                course.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(course.subject),
                        const SizedBox(height: 8),
                        Text(
                          '${model.docs(course.id).length} documents · Updated ${dateLabel(course.updatedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (recent.isNotEmpty) ...[
            const SectionTitle('Recent uploads'),
            for (final doc in recent.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DocumentTile(
                  document: doc,
                  onOpen: () => openPage(
                    context,
                    PdfViewerScreen(
                      repository: model.repository,
                      document: doc,
                    ),
                  ),
                  onRetry: model.working ? null : () => model.retry(doc.id),
                ),
              ),
          ],
        ],
      );
      return widget.standalone
          ? Scaffold(
              appBar: AppBar(title: const Text('Smart Courses')),
              body: body,
            )
          : body;
    },
  );
}
