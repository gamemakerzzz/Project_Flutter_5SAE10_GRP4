import '../../../core/network/learning_ai_client.dart';
import '../models/assessment.dart';

/// Provider credentials are held by the local AI service, never in the app.
class AiAssessmentApi {
  AiAssessmentApi({
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? post,
  }) : _post = post ?? LearningAiClient.post;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  _post;
  Future<List<Question>> generateCourseQuestions(
    AssessmentConfig config,
  ) async {
    final payload = await _post('/api/quiz/generate', {
      ...config.toJson(),
      'courseContext': config.courseContext,
    });
    return (payload['questions'] as List)
        .map((row) => Question.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<String> correctOpenAnswer({
    required Question question,
    required String answer,
  }) async {
    final payload = await _post('/api/quiz/correct', {
      'question': question.prompt,
      'expectedAnswer': question.expectedAnswer,
      'answer': answer,
    });
    return payload['feedback'] as String;
  }
}
