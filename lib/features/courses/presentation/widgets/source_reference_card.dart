import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/courses_repository.dart';
import '../../models/course_models.dart';
import '../screens/pdf_viewer_screen.dart';

class SourceReferenceCard extends StatelessWidget {
  const SourceReferenceCard({
    super.key,
    required this.source,
    required this.repository,
  });
  final SourcePassage source;
  final CoursesRepository repository;
  Future<void> open(BuildContext context) async {
    try {
      final docs = await repository.documents(source.courseId);
      final doc = docs.where((d) => d.id == source.documentId).firstOrNull;
      if (doc == null) {
        throw const CoursesException('This source document has been removed.');
      }
      if (!context.mounted) return;
      openPage(
        context,
        PdfViewerScreen(
          repository: repository,
          document: doc,
          initialPage: source.page,
          excerpt: source.excerpt,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        notice(
          context,
          e is CoursesException
              ? e.message
              : 'Could not open this source. Please retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(
        Icons.format_quote,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        '${source.sourceNumber == null ? '' : '[${source.sourceNumber}] '}${source.documentName}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        'Page ${source.page}${source.score == null
            ? ''
            : repository.isLocal
            ? ' · Term match ${(source.score! * 100).round()}%'
            : ' · Semantic match'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        SelectableText(source.excerpt),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => open(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open source page'),
          ),
        ),
      ],
    ),
  );
}
