import 'package:flutter/material.dart';

import '../../models/assessment.dart';
import '../widgets/assessment_widgets.dart';

/// A route that presents a saved SQFLite attempt without changing its data.
class AttemptDetailScreen extends StatelessWidget {
  const AttemptDetailScreen({super.key, required this.result});
  final AssessmentResult result;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: assessmentBackground,
    appBar: AppBar(title: const Text('Détail de la tentative')),
    body: ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: result.questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AssessmentBanner(
              icon: Icons.insights_outlined,
              title: '${result.percentage}% · ${result.correct}/${result.questions.length}',
              subtitle: '${result.config.mode == AssessmentMode.exam ? 'Examen' : 'Entraînement'} · ${result.config.difficulty.label}',
            ),
          );
        }
        final question = result.questions[index - 1];
        final answer = result.answers[question.id] ?? '';
        final correct = question.isCorrect(answer);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AssessmentPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.prompt, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('Votre réponse : ${question.displayAnswer(answer)}'),
                const SizedBox(height: 8),
                Text(
                  correct ? 'Correct' : 'Réponse attendue : ${question.expectedAnswer}',
                  style: TextStyle(
                    color: correct ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(question.explanation),
              ],
            ),
          ),
        );
      },
    ),
  );
}
