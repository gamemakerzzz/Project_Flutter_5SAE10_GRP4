enum ReviewGrade { again, hard, good, easy }

class Flashcard {
  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.due,
    this.page,
    this.interval = 0,
    this.ease = 2.5,
    this.repetitions = 0,
    this.reviews = 0,
    this.lapses = 0,
    this.lastGrade,
  });
  final String id;
  String question, answer;
  DateTime due;
  int? page;
  int interval, repetitions, reviews, lapses;
  double ease;
  ReviewGrade? lastGrade;
  bool get needsPractice =>
      lastGrade == ReviewGrade.again || lastGrade == ReviewGrade.hard;
  bool isDue(DateTime now) => !due.isAfter(now);
  int get mastery => repetitions == 0 ? 0 : (repetitions * 20).clamp(0, 100);
  // SM-2 inspired scheduling with a ten-minute relearning step.
  Duration nextDelay(ReviewGrade grade) {
    if (grade == ReviewGrade.again) return const Duration(minutes: 10);
    final days = switch (grade) {
      ReviewGrade.hard => interval == 0 ? 1 : (interval * 1.2).ceil(),
      ReviewGrade.good =>
        repetitions == 0
            ? 1
            : repetitions == 1
            ? 6
            : (interval * ease).round(),
      ReviewGrade.easy =>
        interval == 0 ? 4 : (interval * (ease + .15) * 1.3).ceil(),
      ReviewGrade.again => 0,
    };
    return Duration(days: days.clamp(1, 3650));
  }

  void review(ReviewGrade grade, DateTime now) {
    final delay = nextDelay(grade);
    reviews++;
    lastGrade = grade;
    if (grade == ReviewGrade.again) {
      repetitions = 0;
      lapses++;
      ease = (ease - .2).clamp(1.3, 3.0);
    } else {
      repetitions++;
      if (grade == ReviewGrade.hard) ease = (ease - .15).clamp(1.3, 3.0);
      if (grade == ReviewGrade.easy) ease = (ease + .15).clamp(1.3, 3.0);
    }
    interval = delay.inDays;
    due = now.add(delay);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'due': due.toIso8601String(),
    'page': page,
    'interval': interval,
    'ease': ease,
    'repetitions': repetitions,
    'reviews': reviews,
    'lapses': lapses,
    'last_grade': lastGrade?.name,
  };
  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
    id: j['id'],
    question: j['question'],
    answer: j['answer'],
    due: DateTime.parse(j['due']),
    page: j['page'],
    interval: j['interval'] ?? 0,
    ease: (j['ease'] as num? ?? 2.5).toDouble(),
    repetitions: j['repetitions'] ?? 0,
    reviews: j['reviews'] ?? 0,
    lapses: j['lapses'] ?? 0,
    lastGrade: ReviewGrade.values
        .where((grade) => grade.name == j['last_grade'])
        .firstOrNull,
  );
}

class Deck {
  Deck({
    required this.id,
    required this.title,
    required this.source,
    required this.cards,
    this.mode = 'manual',
    this.color = 0,
  });
  final String id, source, mode;
  String title;
  final List<Flashcard> cards;
  final int color;
  int dueCount(DateTime now) => cards.where((c) => c.isDue(now)).length;
  int get mastery => cards.isEmpty
      ? 0
      : (cards.fold<int>(0, (s, c) => s + c.mastery) / cards.length).round();
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source': source,
    'mode': mode,
    'color': color,
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  factory Deck.fromJson(Map<String, dynamic> j) => Deck(
    id: j['id'],
    title: j['title'],
    source: j['source'],
    mode: j['mode'] ?? 'manual',
    color: j['color'] ?? 0,
    cards: (j['cards'] as List).map((c) => Flashcard.fromJson(c)).toList(),
  );
}
