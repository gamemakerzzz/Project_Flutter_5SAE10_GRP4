import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/courses_repository.dart';
import '../../models/course_models.dart';
import '../view_models/retrieval_view_model.dart';
import '../widgets/course_widgets.dart';
import '../widgets/source_reference_card.dart';

class RagChatScreen extends StatefulWidget {
  const RagChatScreen({
    super.key,
    required this.repository,
    required this.course,
  });
  final CoursesRepository repository;
  final Course course;
  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  late final model = RetrievalViewModel(widget.repository, widget.course.id);
  final question = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    question.dispose();
    scroll.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = question.text.trim();
    if (text.isEmpty) return;
    await model.submit(text, chat: true);
    if (!mounted) return;
    if (model.error == null) question.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI · Course assistant'),
        actions: [
          IconButton(
            tooltip: 'Reset conversation',
            onPressed: () {
              model.reset();
              question.clear();
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.course.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      DemoNote(
                        text: widget.repository.isLocal
                            ? 'Evidence preview · AI generation is unavailable. Only exact, locally retrieved PDF passages are shown. Each question is searched independently.'
                            : 'Answers use this course’s PDF passages and run locally with Ollama. Each question is independent. Check the numbered sources; AI can make mistakes.',
                      ),
                      const SizedBox(height: 20),
                      if (model.turns.isEmpty) ...[
                        Icon(
                          Icons.auto_awesome,
                          size: 52,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask a question. Follow the evidence.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final suggestion in [
                          'What are the key definitions?',
                          'Explain the main architecture.',
                          'Find examples and applications.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () => question.text = suggestion,
                              child: Text(suggestion),
                            ),
                          ),
                      ],
                      for (final turn in model.turns) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(top: 20, left: 32),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(turn.question),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turn.answer.generated
                                    ? 'Course-grounded answer'
                                    : 'Source evidence · No generated answer',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(turn.answer.answer),
                            ],
                          ),
                        ),
                        for (final source in turn.answer.sources)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SourceReferenceCard(
                              source: source,
                              repository: widget.repository,
                            ),
                          ),
                      ],
                      if (model.busy)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              LinearProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Preparing sources and answering your question. Local AI can take a few minutes.',
                              ),
                            ],
                          ),
                        ),
                      if (model.error != null)
                        CourseError(model.error!, retry: send),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: question,
                          enabled: !model.busy,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Ask about this course',
                            counterText: '',
                          ),
                          onSubmitted: (_) => send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send question',
                        onPressed: model.busy ? null : send,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
