import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../view_models/courses_view_model.dart';
import '../widgets/course_widgets.dart';
import 'course_editor_screen.dart';
import 'upload_pdf_screen.dart';
import 'pdf_viewer_screen.dart';
import 'semantic_search_screen.dart';
import 'rag_chat_screen.dart';

class CourseDetailsScreen extends StatelessWidget {
  const CourseDetailsScreen({
    super.key,
    required this.model,
    required this.courseId,
  });
  final CoursesViewModel model;
  final String courseId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final course = model.course(courseId);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course details'),
          actions: [
            if (course != null)
              IconButton(
                tooltip: 'Edit course',
                onPressed: model.working
                    ? null
                    : () => openPage(
                        context,
                        CourseEditorScreen(model: model, course: course),
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: course == null
            ? const PageBody(
                children: [Text('This course is no longer available.')],
              )
            : PageBody(
                children: [
                  Text(
                    course.subject.toUpperCase(),
                    style: TextStyle(
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course.description.isEmpty
                        ? 'Collect your course materials and turn reading into understanding.'
                        : course.description,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${model.docs(courseId).length} documents · Updated ${dateLabel(course.updatedAt)}',
                  ),
                  const SizedBox(height: 20),
                  CourseModeBanner(local: model.isLocal),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: model.working
                        ? null
                        : () => openPage(
                            context,
                            UploadPdfScreen(model: model, courseId: courseId),
                          ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload PDF'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => openPage(
                          context,
                          SemanticSearchScreen(
                            repository: model.repository,
                            course: course,
                          ),
                        ),
                        icon: const Icon(Icons.manage_search),
                        label: const Text('Search within course'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => openPage(
                          context,
                          RagChatScreen(
                            repository: model.repository,
                            course: course,
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Ask AI'),
                      ),
                    ],
                  ),
                  if (model.error != null)
                    CourseError(model.error!, retry: model.refresh),
                  if (model.loading || model.working)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  const SectionTitle('Course documents'),
                  if (model.docs(courseId).isEmpty)
                    const Panel(
                      child: Text(
                        'No documents yet. Import a PDF to start reading and exploring its passages.',
                      ),
                    ),
                  for (final doc in model.docs(courseId))
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
                        onRetry: model.working
                            ? null
                            : () => model.retry(doc.id),
                        onDelete: model.working
                            ? null
                            : () async {
                                if (await confirmRemoval(
                                  context,
                                  'Delete document?',
                                  'Remove ${doc.name} and its searchable passages from this workspace?',
                                )) {
                                  await model.removeDocument(doc.id);
                                }
                              },
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: model.working
                        ? null
                        : () async {
                            if (!await confirmRemoval(
                              context,
                              'Delete course?',
                              'This removes the course and all its documents from this workspace.',
                            )) {
                              return;
                            }
                            final ok = await model.removeCourse(courseId);
                            if (ok && context.mounted) {
                              Navigator.pop(context);
                              notice(context, 'Course deleted.');
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete course'),
                  ),
                ],
              ),
      );
    },
  );
}
