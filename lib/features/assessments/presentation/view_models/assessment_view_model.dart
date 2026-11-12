import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/ai_assessment_api.dart';
import '../../data/assessment_database.dart';
import '../../data/demo_question_repository.dart';
import '../../data/open_trivia_repository.dart';
import '../../models/assessment.dart';

enum AssessmentStage { setup, session, result }

class AssessmentViewModel extends ChangeNotifier {
  AssessmentViewModel({
    DemoQuestionRepository? repository,
    AssessmentStore? database,
    OpenTriviaRepository? openTriviaRepository,
    AiAssessmentApi? aiApi,
    DateTime Function()? now,
  }) : _repository = repository ?? DemoQuestionRepository(),
       _database = database ?? AssessmentDatabase(),
       _openTriviaRepository = openTriviaRepository ?? OpenTriviaRepository(),
       _aiApi = aiApi ?? AiAssessmentApi(),
       _now = now ?? DateTime.now;
  final DemoQuestionRepository _repository;
  final AssessmentStore _database;
  final OpenTriviaRepository _openTriviaRepository;
  final AiAssessmentApi _aiApi;
  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _started;
  DateTime? _deadline;
  AssessmentStage stage = AssessmentStage.setup;
  AssessmentConfig config = const AssessmentConfig();
  List<Question> questions = [];
  final Map<String, String> answers = {};
  final Map<String, String> aiFeedback = {};
  final Set<String> revealed = {};
  final List<AssessmentResult> history = [];
  AssessmentResult? result;
  int index = 0;
  Duration remaining = Duration.zero;
  Duration elapsed = Duration.zero;
  bool loading = false;
  bool correcting = false;
  String? loadError;
  Question get current => questions[index];
  int get answered =>
      questions.where((q) => (answers[q.id] ?? '').trim().isNotEmpty).length;

  void start(AssessmentConfig value) {
    _begin(value, _repository.generate(value));
  }

  Future<void> startFromSource(
    AssessmentConfig value,
    QuestionSource source,
  ) async {
    if (source == QuestionSource.local) {
      start(value);
      return;
    }
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final List<Question> questions;
      switch (source) {
        case QuestionSource.local:
          questions = _repository.generate(value);
          break;
        case QuestionSource.openTrivia:
          questions = await _openTriviaRepository.loadQuestions(value);
          break;
        case QuestionSource.gemini:
          questions = await _aiApi.generateFlutterQuestions(value);
          break;
      }
      _begin(value, questions);
    } catch (error) {
      loadError = error.toString();
      loading = false;
      notifyListeners();
    }
  }

  void _begin(AssessmentConfig value, List<Question> newQuestions) {
    _timer?.cancel();
    config = value;
    questions = newQuestions;
    answers.clear();
    aiFeedback.clear();
    revealed.clear();
    index = 0;
    result = null;
    _started = _now();
    _deadline = _started!.add(Duration(minutes: value.minutes));
    remaining = Duration(minutes: value.minutes);
    elapsed = Duration.zero;
    stage = AssessmentStage.session;
    loading = false;
    loadError = null;
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

  Future<void> requestAiCorrection() async {
    if (stage != AssessmentStage.session || current.kind != QuestionKind.open) {
      return;
    }
    final answer = answers[current.id]?.trim() ?? '';
    if (answer.isEmpty) return;
    correcting = true;
    loadError = null;
    notifyListeners();
    try {
      aiFeedback[current.id] = await _aiApi.correctOpenAnswer(
        question: current,
        answer: answer,
      );
    } catch (error) {
      loadError = error.toString();
    } finally {
      correcting = false;
      notifyListeners();
    }
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
    _saveAttempt(result!);
    stage = AssessmentStage.result;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final saved = await _database.loadAttempts();
      history
        ..clear()
        ..addAll(saved);
    } catch (error) {
      loadError = 'Impossible de charger l’historique local : $error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveAttempt(AssessmentResult attempt) async {
    try {
      await _database.saveAttempt(attempt);
    } catch (error) {
      loadError = 'Tentative non sauvegardée localement : $error';
      notifyListeners();
    }
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
    _database.close();
    super.dispose();
  }
}
