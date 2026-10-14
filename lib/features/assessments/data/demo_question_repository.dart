import 'dart:math';

import '../models/assessment.dart';

/// Curated samples for the interface demo. No AI service is called.
class DemoQuestionRepository {
  DemoQuestionRepository({Random? random}) : _random = random ?? Random();
  final Random _random;

  List<Question> generate(AssessmentConfig config) {
    final bank = _bank(config.difficulty);
    final mcq =
        bank.where((q) => q.kind == QuestionKind.multipleChoice).toList()
          ..shuffle(_random);
    final open = bank.where((q) => q.kind == QuestionKind.open).toList()
      ..shuffle(_random);
    final pool = switch (config.mix) {
      QuestionMix.multipleChoice => mcq,
      QuestionMix.open => open,
      QuestionMix.mixed => [
        for (var i = 0; i < mcq.length; i++) ...[mcq[i], open[i]],
      ],
    };
    return pool.take(config.count).toList();
  }

  List<Question> _bank(Difficulty level) {
    final items = switch (level) {
      Difficulty.easy =>
        <(String, List<String>, int, String, String, List<String>)>[
          (
            'Quel langage utilise Flutter ?',
            ['Dart', 'Java', 'PHP', 'Swift'],
            0,
            'Dart',
            'Flutter utilise Dart pour décrire les interfaces et leur logique.',
            ['dart'],
          ),
          (
            'Quel widget dispose ses enfants verticalement ?',
            ['Row', 'Stack', 'Column', 'Wrap'],
            2,
            'Column',
            'Column utilise un axe principal vertical ; Row utilise un axe horizontal.',
            ['column'],
          ),
          (
            'Quel widget représente une interface sans état mutable interne ?',
            ['StatefulWidget', 'StatelessWidget', 'Navigator', 'Scaffold'],
            1,
            'StatelessWidget',
            'Un StatelessWidget reçoit sa configuration et décrit une interface sans objet State propre.',
            ['stateless'],
          ),
          (
            'Quel fichier déclare les dépendances Flutter ?',
            ['README.md', 'main.dart', 'pubspec.yaml', 'index.html'],
            2,
            'pubspec.yaml',
            'pubspec.yaml décrit les dépendances, les ressources et les contraintes du SDK.',
            ['pubspec'],
          ),
          (
            'Quel widget fournit la structure Material d’une page ?',
            ['Text', 'Scaffold', 'Padding', 'Icon'],
            1,
            'Scaffold',
            'Scaffold propose notamment appBar, body et floatingActionButton.',
            ['scaffold'],
          ),
          (
            'Quel widget ajoute un espace autour de son enfant ?',
            ['Padding', 'Text', 'Navigator', 'Row'],
            0,
            'Padding',
            'Padding applique des marges intérieures autour de son enfant.',
            ['padding'],
          ),
        ],
      Difficulty.medium =>
        <(String, List<String>, int, String, String, List<String>)>[
          (
            'Quel appel signale une modification d’état locale ?',
            ['print()', 'setState()', 'runApp()', 'dispose()'],
            1,
            'setState',
            'setState signale au framework que l’état a changé et qu’un rebuild est nécessaire.',
            ['setstate'],
          ),
          (
            'Quel type représente un résultat asynchrone unique ?',
            ['Stream', 'List', 'Future', 'Widget'],
            2,
            'Future',
            'Un Future se termine avec une valeur ou une erreur ; un Stream peut émettre plusieurs événements.',
            ['future'],
          ),
          (
            'Quel appel libère les ressources d’un contrôleur ?',
            ['build()', 'initState()', 'dispose()', 'createState()'],
            2,
            'dispose',
            'Les contrôleurs et abonnements doivent être libérés dans dispose pour éviter les fuites.',
            ['dispose'],
          ),
          (
            'Quel widget convient à une longue liste construite à la demande ?',
            ['Column', 'ListView.builder', 'Center', 'Stack'],
            1,
            'ListView.builder',
            'Le builder crée les éléments nécessaires à l’affichage, plutôt que toute la liste immédiatement.',
            ['listview', 'builder'],
          ),
          (
            'Comment rendre une variable nullable en Dart ?',
            ['String?', 'String!', 'nullable String', 'String*'],
            0,
            'String?',
            'Le suffixe ? autorise null ; le suffixe ! affirme qu’une valeur n’est pas nulle.',
            ['?'],
          ),
          (
            'Quel objet donne accès au thème et aux ancêtres ?',
            ['Timer', 'BuildContext', 'Future', 'String'],
            1,
            'BuildContext',
            'BuildContext représente la position d’un widget dans l’arbre.',
            ['buildcontext'],
          ),
        ],
      Difficulty.hard =>
        <(String, List<String>, int, String, String, List<String>)>[
          (
            'Après un await, que vérifier avant d’utiliser le contexte d’un State ?',
            ['mounted', 'hashCode', 'runtimeType', 'debugPrint'],
            0,
            'mounted',
            'Le State peut avoir été retiré pendant l’attente ; mounted évite de réutiliser un contexte détaché.',
            ['mounted'],
          ),
          (
            'Pourquoi utiliser un isolate pour un calcul lourd ?',
            [
              'Modifier le thème',
              'Éviter de bloquer l’isolate UI',
              'Accéder au BuildContext',
              'Créer une route',
            ],
            1,
            'Éviter de bloquer l’interface',
            'Un isolate peut exécuter un calcul CPU intensif indépendamment de l’isolate qui rend l’interface.',
            ['isolate'],
          ),
          (
            'Quel type convient à une suite d’événements asynchrones ?',
            ['Future', 'Stream', 'int', 'Key'],
            1,
            'Stream',
            'Un Stream émet une séquence d’événements ; ses abonnements doivent être gérés correctement.',
            ['stream'],
          ),
          (
            'Quel est le rôle principal d’une Key ?',
            [
              'Chiffrer les données',
              'Identifier les widgets lors de mises à jour',
              'Créer un thème',
              'Activer Internet',
            ],
            1,
            'Identifier les widgets',
            'Une Key aide Flutter à associer widgets et éléments, notamment quand une liste est réordonnée.',
            ['key'],
          ),
          (
            'Quelle couche centralise l’accès aux données d’une fonctionnalité ?',
            ['Le widget Text', 'Le repository', 'Le thème', 'L’AppBar'],
            1,
            'Repository',
            'Un repository expose les données et isole leur chargement, leur cache et leurs erreurs.',
            ['repository'],
          ),
          (
            'Quelle approche rend un chronomètre robuste aux retards de ticks ?',
            [
              'Compter uniquement les ticks',
              'Comparer l’heure à une échéance',
              'Recréer le Timer dans build',
              'Ignorer les pauses',
            ],
            1,
            'Comparer à une échéance',
            'Une échéance absolue évite de supposer que chaque tick dure exactement une seconde.',
            ['échéance'],
          ),
        ],
    };
    return [
      for (var i = 0; i < items.length; i++) ...[
        Question(
          id: '${level.name}-mcq-$i',
          prompt: items[i].$1,
          kind: QuestionKind.multipleChoice,
          options: items[i].$2,
          correctIndex: items[i].$3,
          expectedAnswer: items[i].$4,
          explanation: items[i].$5,
        ),
        Question(
          id: '${level.name}-open-$i',
          prompt: '${items[i].$1}\nRépondez avec vos propres mots.',
          kind: QuestionKind.open,
          expectedAnswer: items[i].$4,
          explanation: items[i].$5,
          keywords: items[i].$6,
        ),
      ],
    ];
  }
}
