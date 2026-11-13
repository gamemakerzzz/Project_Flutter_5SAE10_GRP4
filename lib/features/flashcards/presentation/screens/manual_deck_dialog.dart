import 'package:flutter/material.dart';

import '../../models/flashcard.dart';

class ManualDeckDialog extends StatefulWidget {
  const ManualDeckDialog({super.key});

  @override
  State<ManualDeckDialog> createState() => _ManualDeckDialogState();
}

class _ManualDeckDialogState extends State<ManualDeckDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final question = TextEditingController();
  final answer = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    question.dispose();
    answer.dispose();
    super.dispose();
  }

  void create() {
    if (!form.currentState!.validate()) return;
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      Deck(
        id: id,
        title: title.text.trim(),
        source: 'Création manuelle',
        cards: [
          Flashcard(
            id: '$id-0',
            question: question.text.trim(),
            answer: answer.text.trim(),
            due: now,
          ),
        ],
      ),
    );
  }

  Widget field(
    TextEditingController controller,
    String label,
    int limit,
    int lines,
  ) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    maxLength: limit,
    maxLines: lines,
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null,
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Créer un paquet manuellement'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(title, 'Nom du paquet', 120, 1),
              const SizedBox(height: 12),
              field(question, 'Question · recto', 1000, 2),
              const SizedBox(height: 12),
              field(answer, 'Réponse · verso', 5000, 3),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: create, child: const Text('Créer le paquet')),
    ],
  );
}
