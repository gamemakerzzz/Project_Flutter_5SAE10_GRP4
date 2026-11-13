import 'package:flutter/material.dart';

import '../../models/flashcard.dart';
import 'flashcards_screen.dart';
import '../widgets/explain_more_button.dart';

class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key, required this.deck, required this.save});
  final Deck deck;
  final Future<bool> Function() save;
  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  Future<void> edit([Flashcard? card]) async {
    final q = TextEditingController(text: card?.question);
    final a = TextEditingController(text: card?.answer);
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(card == null ? 'Nouvelle carte' : 'Modifier la carte'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: q,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Question · recto',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Ajoutez une question.' : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: a,
                    maxLines: 5,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'Réponse · verso',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Ajoutez une réponse.' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      setState(() {
        if (card != null) {
          card.question = q.text.trim();
          card.answer = a.text.trim();
        } else {
          widget.deck.cards.add(
            Flashcard(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              question: q.text.trim(),
              answer: a.text.trim(),
              due: DateTime.now(),
            ),
          );
        }
      });
      final saved = await widget.save();
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modification non sauvegardée. Réessayez.'),
          ),
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    q.dispose();
    a.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.deck.title)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: edit,
      icon: const Icon(Icons.add),
      label: const Text('Ajouter une carte'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          children: [
            Text(
              '${widget.deck.source} • ${modeLabel(widget.deck.mode)}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vérifiez les cartes générées avant de commencer votre révision.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            for (final c in widget.deck.cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: panel(),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    title: Text(
                      c.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.answer}\n\n${c.page == null ? '' : 'Page ${c.page} • '}Prochaine révision : ${c.due.day}/${c.due.month}/${c.due.year} à ${c.due.hour.toString().padLeft(2, '0')}:${c.due.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(height: 1.6),
                          ),
                          ExplainMoreButton(
                            question: c.question,
                            answer: c.answer,
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Modifier',
                      onPressed: () => edit(c),
                      icon: const Icon(Icons.edit_outlined, color: purple),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
