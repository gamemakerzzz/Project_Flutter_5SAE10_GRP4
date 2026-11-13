import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assessment.dart';
import 'open_trivia_repository.dart';

/// Local-demo configuration. Pass keys with --dart-define; never commit keys.
class AiApiConfig {
  const AiApiConfig({
    this.geminiKey = const String.fromEnvironment('GEMINI_API_KEY'),
    this.openAiKey = const String.fromEnvironment('OPENAI_API_KEY'),
    this.geminiModel = const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-2.5-flash',
    ),
    this.openAiModel = const String.fromEnvironment(
      'OPENAI_MODEL',
      defaultValue: 'gpt-4.1-mini',
    ),
  });
  final String geminiKey;
  final String openAiKey;
  final String geminiModel;
  final String openAiModel;
}

class AiAssessmentApi {
  AiAssessmentApi({http.Client? client, AiApiConfig? config})
    : _client = client ?? http.Client(), _config = config ?? const AiApiConfig();
  final http.Client _client;
  final AiApiConfig _config;

  Future<List<Question>> generateCourseQuestions(AssessmentConfig config) async {
    if (_config.geminiKey.isEmpty) {
      throw const QuizApiException(
        'Gemini n’est pas configuré. Lancez avec --dart-define=GEMINI_API_KEY=…',
      );
    }
    final type = switch (config.mix) {
      QuestionMix.multipleChoice => 'QCM uniquement',
      QuestionMix.open => 'questions ouvertes uniquement',
      QuestionMix.mixed => 'un mélange de QCM et questions ouvertes',
    };
    if (config.courseTitle == null || config.courseContext.trim().isEmpty) {
      throw const QuizApiException('Sélectionnez un cours ayant du contenu importé avant de générer le quiz.');
    }
    final prompt = '''Génère ${config.count} questions en français basées uniquement sur les extraits du cours « ${config.courseTitle} », niveau ${config.difficulty.label}, sous forme de $type.
N'invente aucune information absente des extraits. Réponds uniquement avec un tableau JSON. Chaque objet doit contenir id, prompt, kind (multipleChoice ou open), options (liste vide pour open), correctIndex (null pour open), expectedAnswer, explanation et keywords (liste de mots clés pour open).

EXTRAITS DU COURS :
${config.courseContext}''';
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${_config.geminiModel}:generateContent',
      {'key': _config.geminiKey},
    );
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'response_mime_type': 'application/json'},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw QuizApiException('Gemini a répondu ${response.statusCode}.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text is! String) throw const QuizApiException('Réponse Gemini invalide.');
    final questions = jsonDecode(text) as List<dynamic>;
    return questions
        .map((item) => Question.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> correctOpenAnswer({
    required Question question,
    required String answer,
  }) async {
    if (_config.openAiKey.isEmpty) {
      throw const QuizApiException(
        'OpenAI n’est pas configuré. Lancez avec --dart-define=OPENAI_API_KEY=…',
      );
    }
    final prompt = '''Tu es un correcteur pédagogique. Corrige brièvement en français.
Question: ${question.prompt}
Réponse attendue: ${question.expectedAnswer}
Réponse étudiant: $answer
Donne une explication courte, précise et bienveillante.''';
    final response = await _client
        .post(
          Uri.parse('https://api.openai.com/v1/responses'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_config.openAiKey}',
          },
          body: jsonEncode({'model': _config.openAiModel, 'input': prompt}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw QuizApiException('OpenAI a répondu ${response.statusCode}.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final outputs = List<dynamic>.from(body['output'] as List? ?? const []);
    for (final output in outputs) {
      for (final content in List<dynamic>.from((output as Map)['content'] as List? ?? const [])) {
        final value = (content as Map)['text'];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    throw const QuizApiException('OpenAI n’a retourné aucun commentaire.');
  }
}
