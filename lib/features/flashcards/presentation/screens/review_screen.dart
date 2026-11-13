import 'package:flutter/material.dart';

import '../../models/flashcard.dart';
import 'flashcards_screen.dart';
import '../widgets/explain_more_button.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.cards,
    required this.title,
    required this.onSave,
    this.focused = false,
  });
  final List<Flashcard> cards;
  final String title;
  final bool focused;
  final Future<bool> Function() onSave;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int index = 0, success = 0;
  bool revealed = false, busy = false;
  Future<void> grade(ReviewGrade grade) async {
    setState(() => busy = true);
    final card = widget.cards[index];
    final old = Flashcard.fromJson(card.toJson());
    card.review(grade, DateTime.now());
    final saved = await widget.onSave();
    if (!saved) {
      card.due = old.due;
      card.interval = old.interval;
      card.ease = old.ease;
      card.repetitions = old.repetitions;
      card.reviews = old.reviews;
      card.lapses = old.lapses;
      card.lastGrade = old.lastGrade;
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse non enregistrée. Réessayez.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        if (widget.focused ? !card.needsPractice : grade != ReviewGrade.again) {
          success++;
        }
        index++;
        revealed = false;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = index >= widget.cards.length;
    final card = done ? null : widget.cards[index];
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: done
                  ? Column(
                      children: [
                        const Icon(
                          Icons.task_alt,
                          size: 80,
                          color: Color(0xFF319C92),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Session terminée !',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.focused
                              ? '$success carte(s) retrouvée(s) • ${index - success} à retravailler'
                              : '$index cartes révisées • $success rappels réussis',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vos prochaines révisions sont planifiées.\nLes cartes oubliées reviennent dans 10 minutes.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Retour à mes paquets'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text(
                          'CARTE ${index + 1} SUR ${widget.cards.length}',
                          style: const TextStyle(
                            color: purple,
                            letterSpacing: 2,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LinearProgressIndicator(
                          value: index / widget.cards.length,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(36),
                          constraints: const BoxConstraints(minHeight: 290),
                          decoration: panel(),
                          child: Column(
                            children: [
                              Text(
                                revealed
                                    ? 'VERSO · RÉPONSE'
                                    : 'RECTO · QUESTION',
                                style: const TextStyle(
                                  color: purple,
                                  letterSpacing: 1.5,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 36),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  revealed ? card!.answer : card!.question,
                                  key: ValueKey('$index-$revealed'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: revealed ? 22 : 26,
                                    color: ink,
                                    height: 1.5,
                                    fontWeight: revealed
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (card.page != null)
                                Text(
                                  'Source : page ${card.page}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              if (revealed)
                                ExplainMoreButton(
                                  question: card.question,
                                  answer: card.answer,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!revealed) ...[
                          const Text(
                            'Essayez de répondre avant de retourner la carte.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => setState(() => revealed = true),
                            icon: const Icon(Icons.flip),
                            label: const Text('Afficher la réponse'),
                          ),
                        ] else ...[
                          const Text(
                            'Comment s’est passé ce rappel ?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final g in ReviewGrade.values)
                                OutlinedButton(
                                  onPressed: busy ? null : () => grade(g),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 18,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        [
                                          'Oublié',
                                          'Difficile',
                                          'Bien',
                                          'Facile',
                                        ][g.index],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        delayLabel(card.nextDelay(g)),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          'Votre auto-évaluation ajuste la prochaine date de révision.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String delayLabel(Duration d) =>
    d.inDays == 0 ? '${d.inMinutes} min' : '${d.inDays} j';
