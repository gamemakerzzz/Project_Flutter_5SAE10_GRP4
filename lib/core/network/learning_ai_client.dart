import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LearningAiClient {
  static String get baseUrl =>
      const String.fromEnvironment(
        'LEARNING_AI_URL',
        defaultValue: '',
      ).isNotEmpty
      ? const String.fromEnvironment('LEARNING_AI_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:18081'
      : 'http://127.0.0.1:18081';

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 180));
      final payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
          payload['error'] as String? ?? 'Le service IA a refusé la demande.',
        );
      }
      return payload;
    } on http.ClientException {
      throw const FormatException(
        'Service IA injoignable. Vérifiez que le service local est démarré.',
      );
    } on TimeoutException {
      throw const FormatException(
        'Le service IA met trop de temps à répondre. Réessayez.',
      );
    }
  }
}
