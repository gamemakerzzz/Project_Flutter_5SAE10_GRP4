import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'flashcard_database.dart';

import '../models/flashcard.dart';

class FlashcardRepository {
  FlashcardRepository({FlashcardDatabase? database})
    : _database = database ?? FlashcardDatabase.instance;
  final FlashcardDatabase _database;
  static const api = String.fromEnvironment(
    'FLASHCARDS_API_URL',
    defaultValue: 'http://127.0.0.1:8081',
  );
  Future<List<Deck>> load() => _database.load();
  Future<void> save(List<Deck> decks) => _database.save(decks);

  Future<({String explanation, String example, String takeaway})> explain(
    String question,
    String answer,
  ) async {
    final response = await http
        .post(
          Uri.parse('$api/api/flashcards/explain'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'question': question, 'answer': answer}),
        )
        .timeout(const Duration(seconds: 180));
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        payload['error'] ?? 'Impossible de générer une explication.',
      );
    }
    return (
      explanation: payload['explanation'] as String,
      example: payload['example'] as String,
      takeaway: payload['takeaway'] as String,
    );
  }

  Future<Deck> generate({
    required Uint8List bytes,
    required String filename,
    required String title,
    required int count,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('Le PDF doit faire moins de 10 Mo.');
    }
    final response = await http
        .post(
          Uri.parse('$api/api/flashcards/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pdf': base64Encode(bytes),
            'filename': filename,
            'count': count,
            'mode': 'ai',
          }),
        )
        .timeout(const Duration(seconds: 180));
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(payload['error'] ?? 'Erreur de génération.');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final rows = payload['cards'] as List;
    if (rows.isEmpty) throw Exception('Aucune carte générée.');
    return Deck(
      id: id,
      title: title,
      source: filename,
      mode: payload['mode'],
      color: int.parse(id) % 4,
      cards: [
        for (var i = 0; i < rows.length; i++)
          Flashcard(
            id: '$id-$i',
            question: rows[i]['question'],
            answer: rows[i]['answer'],
            page: rows[i]['page'],
            due: DateTime.now(),
          ),
      ],
    );
  }

  Deck demo() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    const pairs = [
      [
        'Quel est le rôle d’un StatefulWidget ?',
        'Il décrit une interface dont l’état peut changer au cours du temps. Son objet State conserve cet état et déclenche la reconstruction avec setState.',
      ],
      [
        'À quoi sert la méthode build() ?',
        'Elle décrit l’interface en retournant un arbre de widgets à partir de la configuration et de l’état actuels.',
      ],
      [
        'Quelle est la différence entre Row et Column ?',
        'Row dispose ses enfants horizontalement ; Column les dispose verticalement.',
      ],
      [
        'Qu’est-ce qu’un Future en Dart ?',
        'Un Future représente le résultat à venir d’une opération asynchrone : une valeur ou une erreur.',
      ],
      [
        'Pourquoi utiliser une Key ?',
        'Une Key aide Flutter à identifier les widgets et à préserver correctement leur état quand leur position change.',
      ],
      [
        'À quoi sert pubspec.yaml ?',
        'Il déclare les métadonnées du projet, les contraintes du SDK, les dépendances et les ressources telles que les images et les polices.',
      ],
    ];
    return Deck(
      id: id,
      title: 'Les fondamentaux de Flutter',
      source: 'Exemple pédagogique',
      mode: 'demo',
      cards: [
        for (var i = 0; i < pairs.length; i++)
          Flashcard(
            id: '$id-$i',
            question: pairs[i][0],
            answer: pairs[i][1],
            due: DateTime.now(),
          ),
      ],
    );
  }
}
