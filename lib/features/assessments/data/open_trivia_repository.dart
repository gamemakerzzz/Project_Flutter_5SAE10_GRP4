import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assessment.dart';

class QuizApiException implements Exception {
  const QuizApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Live non-AI question fallback. Category 18 is Science: Computers.
class OpenTriviaRepository {
  OpenTriviaRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Question>> loadQuestions(AssessmentConfig config) async {
    if (config.mix == QuestionMix.open) {
      throw const QuizApiException(
        'Open Trivia DB fournit uniquement des QCM. Choisissez QCM ou une source IA.',
      );
    }
    final difficulty = switch (config.difficulty) {
      Difficulty.easy => 'easy',
      Difficulty.medium => 'medium',
      Difficulty.hard => 'hard',
    };
    final uri = Uri.https('opentdb.com', '/api.php', {
      'amount': '${config.count}',
      'category': '18',
      'difficulty': difficulty,
      'type': 'multiple',
      'encode': 'url3986',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw QuizApiException('Le service de questions a répondu ${response.statusCode}.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['response_code'] != 0) {
      throw const QuizApiException('Aucune question disponible pour cette sélection.');
    }
    final results = List<Map<String, dynamic>>.from(json['results'] as List);
    return [
      for (var index = 0; index < results.length; index++)
        _toQuestion(results[index], index),
    ];
  }

  Question _toQuestion(Map<String, dynamic> item, int index) {
    String decode(String value) => Uri.decodeComponent(value);
    final correct = decode(item['correct_answer'] as String);
    final options = [
      ...List<String>.from(item['incorrect_answers'] as List).map(decode),
      correct,
    ]..shuffle();
    return Question(
      id: 'opentdb-${DateTime.now().microsecondsSinceEpoch}-$index',
      prompt: decode(item['question'] as String),
      kind: QuestionKind.multipleChoice,
      options: options,
      correctIndex: options.indexOf(correct),
      expectedAnswer: correct,
      explanation: 'Réponse issue d’Open Trivia DB.',
    );
  }
}
