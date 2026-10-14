import 'package:flutter/material.dart';

import '../../models/assessment.dart';
import '../view_models/assessment_view_model.dart';
import '../widgets/assessment_widgets.dart';

/// Feature entry point. Can be pushed as a route from the shared dashboard.
class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key, this.viewModel});
  final AssessmentViewModel? viewModel;
  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen>
    with WidgetsBindingObserver {
  late final AssessmentViewModel vm;
  Difficulty difficulty = Difficulty.easy;
  QuestionMix mix = QuestionMix.mixed;
  AssessmentMode mode = AssessmentMode.practice;
  int count = 5;
  int minutes = 10;
  bool historyTab = false;

  @override
  void initState() {
    super.initState();
    vm = widget.viewModel ?? AssessmentViewModel();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) vm.refreshClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.viewModel == null) vm.dispose();
    super.dispose();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _submit() async {
    final yes = await _confirm(
      title: 'Terminer la session ?',
      message:
          '${vm.answered}/${vm.questions.length} réponses enregistrées. Les questions sans réponse comptent comme incorrectes.',
    );
    if (yes && mounted) {
      FocusScope.of(context).unfocus();
      vm.finish();
    }
  }

  Future<void> _leave() async {
    if (vm.stage == AssessmentStage.session) {
      final yes = await _confirm(
        title: 'Quitter la session ?',
        message: 'Cette tentative sera abandonnée et ne sera pas ajoutée à l’historique.',
      );
      if (!yes || !mounted) return;
    }
    vm.reset();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) => PopScope(
      canPop: vm.stage != AssessmentStage.session,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: assessmentBackground,
        appBar: AppBar(
          backgroundColor: assessmentBackground,
          leading: vm.stage == AssessmentStage.setup
              ? null
              : IconButton(
                  tooltip: 'Retour à la configuration',
                  onPressed: _leave,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: const Text(
            'Quiz & Examens',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('DÉMO'),
                avatar: Icon(Icons.science_outlined, size: 16),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: switch (vm.stage) {
                  AssessmentStage.setup => _setup(),
                  AssessmentStage.session => _session(),
                  AssessmentStage.result => _result(),
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _setup() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AssessmentBanner(
        title: 'Un peu de pratique.\nBeaucoup de progrès.',
        subtitle: 'Entraînez-vous à votre rythme ou relevez le défi d’un examen chronométré.',
      ),
      const SizedBox(height: 20),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Nouvelle session'),
            icon: Icon(Icons.edit_note),
          ),
          ButtonSegment(
            value: true,
            label: Text('Historique'),
            icon: Icon(Icons.history),
          ),
        ],
        selected: {historyTab},
        onSelectionChanged: (value) => setState(() => historyTab = value.first),
      ),
      const SizedBox(height: 20),
      if (historyTab)
        _history()
      else ...[
        AssessmentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personnalisez votre entraînement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Cours de démonstration : Flutter & Dart'),
              const SizedBox(height: 24),
              _dropdown<Difficulty>(
                'Difficulté',
                difficulty,
                Difficulty.values,
                (v) => v.label,
                (v) => setState(() => difficulty = v),
              ),
              const SizedBox(height: 16),
              _dropdown<QuestionMix>(
                'Type de questions',
                mix,
                QuestionMix.values,
                (v) => switch (v) {
                  QuestionMix.multipleChoice => 'QCM',
                  QuestionMix.open => 'Questions ouvertes',
                  QuestionMix.mixed => 'Mixte : QCM + questions ouvertes',
                },
                (v) => setState(() => mix = v),
              ),
              const SizedBox(height: 16),
              _dropdown<int>(
                'Nombre de questions',
                count,
                [3, 5, 6],
                (v) => '$v questions',
                (v) => setState(() => count = v),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Entraînement'),
                    avatar: const Icon(Icons.school_outlined, size: 18),
                    selected: mode == AssessmentMode.practice,
                    onSelected: (_) =>
                        setState(() => mode = AssessmentMode.practice),
                  ),
                  ChoiceChip(
                    label: const Text('Simulation d’examen'),
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    selected: mode == AssessmentMode.exam,
                    onSelected: (_) =>
                        setState(() => mode = AssessmentMode.exam),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                mode == AssessmentMode.exam
                    ? 'Temps limité · correction à la fin · soumission automatique'
                    : 'Sans limite de temps · correction disponible après chaque réponse',
              ),
              if (mode == AssessmentMode.exam) ...[
                const SizedBox(height: 16),
                _dropdown<int>(
                  'Durée de l’examen',
                  minutes,
                  [1, 5, 10, 20, 30],
                  (v) => '$v min',
                  (v) => setState(() => minutes = v),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    vm.start(
                      AssessmentConfig(
                        difficulty: difficulty,
                        mix: mix,
                        mode: mode,
                        count: count,
                        minutes: minutes,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Générer une session démo'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Prototype d’interface : questions préécrites, correction simulée et historique conservé uniquement pendant cette ouverture du module.',
          style: TextStyle(color: Color(0xFF526078), height: 1.5),
        ),
      ],
    ],
  );

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> values,
    String Function(T) text,
    ValueChanged<T> onChanged,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(text(item))),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );

  Widget _session() {
    final q = vm.current;
    final answer = vm.answers[q.id] ?? '';
    final revealed = vm.revealed.contains(q.id);
    final exam = vm.config.mode == AssessmentMode.exam;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssessmentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    exam ? 'SIMULATION D’EXAMEN' : 'ENTRAÎNEMENT',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: assessmentBlue,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(
                      '${exam ? 'Restant' : 'Écoulé'} ${clockLabel(exam ? vm.remaining : vm.elapsed)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: exam && vm.remaining.inSeconds < 60
                            ? Colors.red.shade700
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: vm.answered / vm.questions.length,
                minHeight: 7,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 10),
              Text(
                '${vm.answered}/${vm.questions.length} réponses · ${vm.config.difficulty.label}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < vm.questions.length; i++)
              ChoiceChip(
                label: Text('${i + 1}'),
                selected: i == vm.index,
                avatar: (vm.answers[vm.questions[i].id] ?? '').trim().isNotEmpty
                    ? const Icon(Icons.check, size: 14)
                    : null,
                onSelected: (_) {
                  FocusScope.of(context).unfocus();
                  vm.goTo(i);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        AssessmentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'QUESTION ${vm.index + 1} / ${vm.questions.length} · ${q.kind == QuestionKind.open ? 'OUVERTE' : 'QCM'}',
                style: const TextStyle(
                  color: assessmentBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                q.prompt,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (q.kind == QuestionKind.multipleChoice) ...[
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: answer == '$i'
                            ? const Color(0xFFE8F4FF)
                            : Colors.white,
                        foregroundColor: const Color(0xFF23334D),
                        side: BorderSide(
                          color: answer == '$i'
                              ? assessmentBlue
                              : const Color(0xFFDDE4EE),
                        ),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: revealed ? null : () => vm.answer('$i'),
                      child: Row(
                        children: [
                          Icon(
                            answer == '$i'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              q.options[i],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                OpenAnswerField(
                  key: ValueKey(q.id),
                  answer: answer,
                  enabled: !revealed,
                  onChanged: vm.answer,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Démo : la correction compare des mots-clés. Elle ne représente pas une évaluation pédagogique par IA.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF526078)),
                ),
              ],
              if (!exam && !revealed) ...[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: answer.trim().isEmpty ? null : vm.reveal,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Vérifier ma réponse'),
                ),
              ],
              if (revealed) ...[
                const SizedBox(height: 18),
                _feedback(q, answer),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: vm.index == 0 ? null : () => vm.goTo(vm.index - 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Précédente'),
            ),
            if (vm.index < vm.questions.length - 1)
              FilledButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  vm.goTo(vm.index + 1);
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Suivante'),
              ),
            OutlinedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Terminer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _feedback(Question q, String answer) {
    final correct = q.isCorrect(answer);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFE9F7F0) : const Color(0xFFFFF3E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct
                ? 'Réponse correcte${q.kind == QuestionKind.open ? ' (démo)' : ''}'
                : 'À revoir${q.kind == QuestionKind.open ? ' (démo)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('Réponse attendue : ${q.expectedAnswer}'),
          const SizedBox(height: 8),
          Text(q.explanation, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _result() {
    final result = vm.result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssessmentBanner(
          icon: Icons.emoji_events_outlined,
          title: '${result.percentage}% · Continuez à progresser',
          subtitle:
              '${result.correct}/${result.questions.length} réponses correctes · ${result.config.difficulty.label}\n'
              '${result.timedOut ? 'Temps écoulé : soumission automatique' : 'Session terminée'} · ${clockLabel(result.elapsed)}',
        ),
        const SizedBox(height: 20),
        const Text(
          'Correction détaillée',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Score indicatif de démonstration. Les réponses ouvertes utilisent une comparaison de mots-clés.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < result.questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AssessmentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${i + 1}. ${result.questions[i].prompt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre réponse : ${result.questions[i].displayAnswer(result.answers[result.questions[i].id] ?? '')}',
                  ),
                  const SizedBox(height: 12),
                  _feedback(
                    result.questions[i],
                    result.answers[result.questions[i].id] ?? '',
                  ),
                ],
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: () {
            historyTab = false;
            vm.reset();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Nouvelle session'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () {
            historyTab = true;
            vm.reset();
          },
          icon: const Icon(Icons.history),
          label: const Text('Voir l’historique'),
        ),
      ],
    );
  }

  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AssessmentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vos progrès',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '${vm.history.length} sessions · Meilleur score : ${vm.history.isEmpty ? '—' : '${vm.history.map((r) => r.percentage).reduce((a, b) => a > b ? a : b)}%'}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Historique de cette ouverture du module. Aucune donnée n’est sauvegardée sur un serveur.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (vm.history.isEmpty)
        const AssessmentPanel(
          child: Column(
            children: [
              Icon(Icons.insights_outlined, size: 48, color: assessmentBlue),
              SizedBox(height: 12),
              Text(
                'Votre première session vous attend',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Terminez un quiz ou un examen pour retrouver votre score ici.',
              ),
            ],
          ),
        ),
      for (final result in vm.history)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AssessmentPanel(
            padding: 8,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE8F4FF),
                child: Text(
                  '${result.percentage}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                '${result.config.mode == AssessmentMode.exam ? 'Examen' : 'Entraînement'} · ${result.config.difficulty.label}',
              ),
              subtitle: Text(
                '${result.date.day.toString().padLeft(2, '0')}/${result.date.month.toString().padLeft(2, '0')}/${result.date.year} '
                '${result.date.hour.toString().padLeft(2, '0')}:${result.date.minute.toString().padLeft(2, '0')}\n'
                '${result.correct}/${result.questions.length} · ${clockLabel(result.elapsed)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => vm.showResult(result),
            ),
          ),
        ),
    ],
  );
}
