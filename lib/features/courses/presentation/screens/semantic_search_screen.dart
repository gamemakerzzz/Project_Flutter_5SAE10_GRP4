import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/courses_repository.dart';
import '../../models/course_models.dart';
import '../view_models/retrieval_view_model.dart';
import '../widgets/course_widgets.dart';
import '../widgets/source_reference_card.dart';

class SemanticSearchScreen extends StatefulWidget {
  const SemanticSearchScreen({
    super.key,
    required this.repository,
    required this.course,
  });
  final CoursesRepository repository;
  final Course course;
  @override
  State<SemanticSearchScreen> createState() => _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends State<SemanticSearchScreen> {
  late final model = RetrievalViewModel(widget.repository, widget.course.id);
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.repository.isLocal ? 'Full-text Search' : 'Semantic Search',
        ),
      ),
      body: PageBody(
        children: [
          Text(
            'Find the passage that matters.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(widget.course.title),
          const SizedBox(height: 20),
          DemoNote(
            text: widget.repository.isLocal
                ? 'Local text search · Matches words in your imported PDFs. No embeddings or semantic model are connected. Scores show query-term coverage, not confidence.'
                : 'Search by meaning across your course PDFs. Results include exact passages and original pages. Similarity is not a confidence score.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: query,
            maxLength: 1000,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What would you like to find?',
              hintText: 'e.g. supervised and unsupervised learning',
            ),
            onSubmitted: (_) => model.submit(query.text, chat: false),
          ),
          const SizedBox(height: 12),
          BusyButton(
            label: 'Search passages',
            busy: model.busy,
            onPressed: () {
              if (query.text.trim().isEmpty) {
                notice(context, 'Enter a question or a few search terms.');
                return;
              }
              model.submit(query.text, chat: false);
            },
          ),
          if (model.error != null)
            CourseError(
              model.error!,
              retry: () => model.submit(query.text, chat: false),
            ),
          if (model.busy && !widget.repository.isLocal)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Preparing the course index and searching locally. The first search can take a few minutes.',
              ),
            ),
          const SizedBox(height: 20),
          if (!model.searched && !model.busy)
            const Panel(
              child: Text(
                'Your results will include the exact passage, document name and original page. Import and index a PDF first.',
              ),
            ),
          if (model.searched && model.results.isEmpty)
            const Panel(
              child: Text(
                'No matching passages found. Try different terms or check that your documents are Ready.',
              ),
            ),
          for (final source in model.results)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SourceReferenceCard(
                source: source,
                repository: widget.repository,
              ),
            ),
        ],
      ),
    ),
  );
}
