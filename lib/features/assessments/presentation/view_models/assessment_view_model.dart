import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/demo_question_repository.dart';
import '../../models/assessment.dart';

enum AssessmentStage { setup, session, result }

class AssessmentViewModel extends ChangeNotifier {
  AssessmentViewModel({
    DemoQuestionRepository? repository,
    DateTime Function()? now,
  }) : _repository = repository ?? DemoQuestionRepository(),
       _now = now ?? DateTime.now;
  final DemoQuestionRepository _repository;
  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _started;
  DateTime? _deadline;
  AssessmentStage stage = AssessmentStage.setup;
  AssessmentConfig config = const AssessmentConfig();
  List<Question> questions = [];
  final Map<String, String> answers = {};
  final Set<String> revealed = {};
  final List<AssessmentResult> history = [];
  AssessmentResult? result;
  int index = 0;
  Duration remaining = Duration.zero;
  Duration elapsed = Duration.zero;
  Question get current => questions[index];
  int get answered =>
      questions.where((q) => (answers[q.id] ?? '').trim().isNotEmpty).length;

  void start(AssessmentConfig value) {
    _timer?.cancel();
    config = value;
    questions = _repository.generate(value);
    answers.clear();
    revealed.clear();
    index = 0;
    result = null;
    _started = _now();
    _deadline = _started!.add(Duration(minutes: value.minutes));
    remaining = Duration(minutes: value.minutes);
    elapsed = Duration.zero;
    stage = AssessmentStage.session;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refreshClock());
    notifyListeners();
  }

  void refreshClock() {
    if (stage != AssessmentStage.session) return;
    final now = _now();
    elapsed = now.difference(_started!);
    remaining = _deadline!.difference(now);
    if (config.mode == AssessmentMode.exam && remaining <= Duration.zero) {
      remaining = Duration.zero;
      finish(timedOut: true);
    } else {
      notifyListeners();
    }
  }

  void answer(String value) {
    if (stage != AssessmentStage.session || revealed.contains(current.id)) {
      return;
    }
    if (config.mode == AssessmentMode.exam && !_now().isBefore(_deadline!)) {
      refreshClock();
      return;
    }
    answers[current.id] = value;
    notifyListeners();
  }

  void reveal() {
    if (stage != AssessmentStage.session || config.mode == AssessmentMode.exam) {
      return;
    }
    if ((answers[current.id] ?? '').trim().isEmpty) return;
    revealed.add(current.id);
    notifyListeners();
  }

  void goTo(int value) {
    if (stage != AssessmentStage.session ||
        value < 0 ||
        value >= questions.length) {
      return;
    }
    index = value;
    notifyListeners();
  }

  void finish({bool timedOut = false}) {
    if (stage != AssessmentStage.session) return;
    _timer?.cancel();
    final now = _now();
    final expired =
        config.mode == AssessmentMode.exam && !now.isBefore(_deadline!);
    result = AssessmentResult(
      id: now.microsecondsSinceEpoch.toString(),
      date: now,
      config: config,
      questions: List.unmodifiable(questions),
      answers: Map.unmodifiable(answers),
      elapsed: expired
          ? Duration(minutes: config.minutes)
          : now.difference(_started!),
      timedOut: timedOut || expired,
    );
    history.insert(0, result!);
    stage = AssessmentStage.result;
    notifyListeners();
  }

  void showResult(AssessmentResult value) {
    result = value;
    stage = AssessmentStage.result;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    stage = AssessmentStage.setup;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
