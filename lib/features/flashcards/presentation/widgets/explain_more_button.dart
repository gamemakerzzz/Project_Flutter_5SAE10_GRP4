import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/flashcard_repository.dart';

class ExplainMoreButton extends StatelessWidget {
  const ExplainMoreButton({
    super.key,
    required this.question,
    required this.answer,
  });
  final String question, answer;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.auto_awesome, size: 18),
    label: const Text('Explain more with AI'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _ExplanationDialog(question: question, answer: answer),
    ),
  );
}

class _ExplanationDialog extends StatefulWidget {
  const _ExplanationDialog({required this.question, required this.answer});
  final String question, answer;

  @override
  State<_ExplanationDialog> createState() => _ExplanationDialogState();
}

class _ExplanationDialogState extends State<_ExplanationDialog> {
  late Future<({String explanation, String example, String takeaway})> result;

  Future<({String explanation, String example, String takeaway})> request() =>
      FlashcardRepository().explain(widget.question, widget.answer);

  @override
  void initState() {
    super.initState();
    result = request();
  }

  String errorMessage(Object? error) => switch (error) {
    TimeoutException() => 'La demande a expiré. Réessayez.',
    http.ClientException() =>
      'Impossible de joindre le service IA. Vérifiez votre connexion.',
    Exception() when error is! FormatException => error.toString().replaceFirst(
      'Exception: ',
      '',
    ),
    _ => 'Impossible de lire l’explication. Réessayez.',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: result,
    builder: (context, snapshot) {
      final waiting = snapshot.connectionState != ConnectionState.done;
      final data = snapshot.data;
      return AlertDialog(
        title: const Text('Explain more with AI'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.question,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                if (waiting) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('L’IA prépare une explication…'),
                ] else if (data != null) ...[
                  section(context, 'Explication', data.explanation),
                  section(context, 'Exemple', data.example),
                  section(context, 'À retenir', data.takeaway),
                ] else
                  Text(errorMessage(snapshot.error)),
              ],
            ),
          ),
        ),
        actions: [
          if (!waiting && snapshot.hasError)
            TextButton(
              onPressed: () => setState(() => result = request()),
              child: const Text('Réessayer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      );
    },
  );

  Widget section(BuildContext context, String heading, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SelectableText(text),
      ],
    ),
  );
}
