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

enum QuestionSource { local, openTrivia, gemini }

class AssessmentConfig {
  const AssessmentConfig({
    this.difficulty = Difficulty.easy,
    this.mix = QuestionMix.mixed,
    this.mode = AssessmentMode.practice,
    this.count = 5,
    this.minutes = 10,
    this.courseId,
    this.courseTitle,
    this.courseContext = '',
  });
  final Difficulty difficulty;
  final QuestionMix mix;
  final AssessmentMode mode;
  final int count;
  final int minutes;
  final String? courseId;
  final String? courseTitle;
  /// Extracted local course passages provided only for the current generation.
  final String courseContext;

  Map<String, Object> toJson() => {
    'difficulty': difficulty.name,
    'mix': mix.name,
    'mode': mode.name,
    'count': count,
    'minutes': minutes,
    'courseId': courseId,
    'courseTitle': courseTitle,
  };

  factory AssessmentConfig.fromJson(Map<String, dynamic> json) =>
      AssessmentConfig(
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        mix: QuestionMix.values.byName(json['mix'] as String),
        mode: AssessmentMode.values.byName(json['mode'] as String),
        count: json['count'] as int,
        minutes: json['minutes'] as int,
        courseId: json['courseId'] as String?,
        courseTitle: json['courseTitle'] as String?,
      );
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

  Map<String, Object?> toJson() => {
    'id': id,
    'prompt': prompt,
    'kind': kind.name,
    'options': options,
    'correctIndex': correctIndex,
    'expectedAnswer': expectedAnswer,
    'explanation': explanation,
    'keywords': keywords,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    kind: QuestionKind.values.byName(json['kind'] as String),
    options: List<String>.from(json['options'] as List<dynamic>? ?? const []),
    correctIndex: json['correctIndex'] as int?,
    expectedAnswer: json['expectedAnswer'] as String,
    explanation: json['explanation'] as String,
    keywords: List<String>.from(json['keywords'] as List<dynamic>? ?? const []),
  );
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

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'config': config.toJson(),
    'questions': questions.map((question) => question.toJson()).toList(),
    'answers': answers,
    'elapsedSeconds': elapsed.inSeconds,
    'timedOut': timedOut,
  };

  factory AssessmentResult.fromJson(Map<String, dynamic> json) =>
      AssessmentResult(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        config: AssessmentConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        ),
        questions: (json['questions'] as List<dynamic>)
            .map(
              (question) =>
                  Question.fromJson(Map<String, dynamic>.from(question as Map)),
            )
            .toList(),
        answers: Map<String, String>.from(json['answers'] as Map),
        elapsed: Duration(seconds: json['elapsedSeconds'] as int),
        timedOut: json['timedOut'] as bool? ?? false,
      );
}
