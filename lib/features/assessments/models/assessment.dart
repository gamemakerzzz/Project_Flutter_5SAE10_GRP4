enum Difficulty {
  easy('Facile'),
  medium('Intermédiaire'),
  hard('Avancé');

  const Difficulty(this.label);
  final String label;
}

enum QuestionKind { multipleChoice, open }

enum QuestionMix { multipleChoice, open, mixed }

enum AssessmentMode { practice, exam }

class AssessmentConfig {
  const AssessmentConfig({
    this.difficulty = Difficulty.easy,
    this.mix = QuestionMix.mixed,
    this.mode = AssessmentMode.practice,
    this.count = 5,
    this.minutes = 10,
  });
  final Difficulty difficulty;
  final QuestionMix mix;
  final AssessmentMode mode;
  final int count;
  final int minutes;
}

class Question {
  const Question({
    required this.id,
    required this.prompt,
    required this.kind,
    this.options = const [],
    this.correctIndex,
    required this.expectedAnswer,
    required this.explanation,
    this.keywords = const [],
  });
  final String id;
  final String prompt;
  final QuestionKind kind;
  final List<String> options;
  final int? correctIndex;
  final String expectedAnswer;
  final String explanation;
  final List<String> keywords;

  bool isCorrect(String answer) {
    if (kind == QuestionKind.multipleChoice) {
      return answer == correctIndex.toString();
    }
    final normalized = answer.toLowerCase().trim();
    return normalized.isNotEmpty && keywords.every(normalized.contains);
  }

  String displayAnswer(String answer) {
    if (kind == QuestionKind.open) {
      return answer.trim().isEmpty ? 'Sans réponse' : answer;
    }
    final index = int.tryParse(answer);
    return index != null && index >= 0 && index < options.length
        ? options[index]
        : 'Sans réponse';
  }
}

class AssessmentResult {
  const AssessmentResult({
    required this.id,
    required this.date,
    required this.config,
    required this.questions,
    required this.answers,
    required this.elapsed,
    this.timedOut = false,
  });
  final String id;
  final DateTime date;
  final AssessmentConfig config;
  final List<Question> questions;
  final Map<String, String> answers;
  final Duration elapsed;
  final bool timedOut;
  int get correct =>
      questions.where((q) => q.isCorrect(answers[q.id] ?? '')).length;
  int get percentage =>
      questions.isEmpty ? 0 : (correct * 100 / questions.length).round();
}
