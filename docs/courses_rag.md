# Smart Courses et RAG local

## Fonctionnement

Flutter appelle le backend Dart Frog avec le JWT de l’utilisateur. Les PDF sont enregistrés sur disque, extraits par PDFium et découpés en passages de 900 caractères maximum, sans traverser les pages.

Après extraction, le backend crée les embeddings avec Ollama / EmbeddingGemma. Les vecteurs normalisés sont persistés dans SQLite avec l’identifiant du passage, le modèle, son digest et la version du préfixe de recherche. Une mise à jour du modèle produit un nouvel espace d’indexation. Les suppressions de documents et de cours suppriment leurs vecteurs par cascade.

La recherche sémantique compare l’embedding de la question aux passages du cours par similarité cosinus. Ask AI envoie au modèle Qwen3 jusqu’à cinq passages autorisés. Le modèle répond en JSON avec texte, numéros de sources et citations exactes. Le serveur vérifie les numéros, les citations et l’existence des passages après la génération, puis retourne les noms des documents et les pages provenant de SQLite. Les références ouvrent le lecteur PDF à la bonne page.

Les instructions présentes dans un PDF sont traitées comme des données non fiables. Le modèle n’a ni outils, ni accès réseau, ni accès aux autres cours. Une réponse sans preuve ou avec des références invalides devient une réponse « contexte insuffisant ». La vérification des références ne garantit pas la justesse de chaque phrase : l’étudiant doit consulter les sources.

## Installation et lancement Windows

Installer Ollama depuis https://ollama.com/download/windows, puis :

```powershell
cd backend
.\setup-ai.ps1
$env:PORT = '8081'
.\start-dev.ps1
```

Le script télécharge `embeddinggemma:300m` (environ 622 Mo) et `qwen3:4b` (environ 2,5 Go). Aucun compte cloud ni clé API n’est nécessaire. Les téléchargements nécessitent Internet ; l’inférence utilise ensuite les modèles locaux. Ollama doit rester actif sur `127.0.0.1:11434`.

Dans un autre terminal à la racine :

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

Se connecter, ouvrir Courses, créer un cours, importer un PDF contenant du texte, attendre Ready puis utiliser Search within course ou Ask AI. Les documents déjà présents sont indexés lors de la première recherche. Cette première opération peut prendre plusieurs minutes ; le client attend l’index puis la réponse. Les questions sont indépendantes, sans historique envoyé au modèle.

## Configuration serveur

| Variable | Défaut |
| --- | --- |
| OLLAMA_BASE_URL | http://127.0.0.1:11434 (HTTP loopback uniquement) |
| OLLAMA_EMBED_MODEL | embeddinggemma:300m |
| OLLAMA_CHAT_MODEL | qwen3:4b |
| RAG_ENABLED | true ; false désactive l’IA |
| PORT | 8080 ; utiliser 8081 sur ce poste |

Les variables sont lues depuis l’environnement du processus. `.env.example` est une référence, pas un fichier chargé automatiquement. Le secret JWT est géré séparément par `start-dev.ps1`. Le mode `DEMO_MODE=true` reste une démonstration en mémoire, sans génération IA.

## API RAG authentifiée

- `POST /api/courses/{id}/index` : 202, démarre ou reprend l’indexation.
- `GET /api/courses/{id}/index` : `{state, total, indexed, model, error}`. États : pending, indexing, ready, failed.
- `POST /api/courses/search` : `{courseId, query, topK: 5, mode: "semantic"}`. Liste de passages exacts avec document, page et score cosinus. Mode omis ou keyword : recherche textuelle historique.
- `POST /api/rag/ask` : `{courseId, question}`. Réponse `{answer, sources, generated}`. Chaque source comporte `chunkId`, `documentId`, `courseId`, `documentName`, `page`, `excerpt`, `score`, `sourceNumber`.

Les cours d’un autre utilisateur renvoient 404, avant tout appel IA. Pas de preuve : generated=false et sources vides. Index en préparation : 409 INDEXING. Ollama arrêté ou modèle absent : 503 AI_UNAVAILABLE. Timeout du modèle : 504 AI_TIMEOUT. Sortie invalide : 502 AI_INVALID_RESPONSE. Aucun de ces cas ne devient une fausse réussite ou une réponse de démonstration.

## Limites connues

- PDF : 20 Mo, 250 pages, 1 000 000 caractères extraits. Pas d’OCR pour les scans.
- Index local : 5 000 passages par cours, lots de 8, file de 32 cours, indexation séquentielle. Recherche exacte en mémoire sur les vecteurs du seul cours ; adaptée au projet étudiant, pas à une très grande bibliothèque.
- Similarité minimale : 0,25, valeur technique à calibrer sur les cours. Ce score n’est pas une probabilité de correction.
- Deux requêtes de recherche/génération simultanées, timeout Ollama de 120 secondes, contexte de 4 096 tokens, réponse plafonnée à 700 tokens. Le client attend au plus 10 minutes l’indexation et 150 secondes une requête de recherche/réponse.
- Une erreur d’indexation conserve les lots déjà enregistrés ; une nouvelle recherche reprend les passages manquants. Les traitements PDF Ready et index IA Ready sont distincts.
- Le chat n’enregistre pas les conversations. Pas d’OCR, de récupération de mot de passe ou de fonctionnalités des autres modules dans cette livraison.

## Validation reproductible

Arrêter le backend avant les commandes Dart sur Windows pour libérer la DLL SQLite.

```powershell
cd backend
dart analyze
dart test
dart run bin/verify_rag.dart
cd ..
flutter analyze lib test
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

Les tests automatisés couvrent comptes/profils, propriété des documents, PDF réels, persistance, classement vectoriel, cache d’embeddings, erreurs du fournisseur, citations invalides et suppressions pendant l’indexation/génération. Les tests de protocole Ollama utilisent un serveur HTTP local déterministe ; ils ne prétendent pas mesurer la qualité du modèle.

`bin/verify_rag.dart` appelle les vrais modèles sur un serveur HTTP et une base temporaires : inscription, upload PDF, embeddings, question française sur un passage anglais, réponse citée, question hors contexte, isolation utilisateur, redémarrage et suppression. Il ne touche pas aux comptes ni aux PDF de développement.

## Validation du 30 octobre 2026

- Analyse Flutter (`lib test`) et analyse backend : aucune anomalie.
- Tests Flutter : 28 réussis ; tests backend : 17 réussis.
- Revue du client : les rafraîchissements obsolètes ne remplacent plus les données récentes, le polling attend la fin des modifications, les sessions fermées refusent les nouvelles requêtes et les erreurs de validation du serveur sont affichées. Cinq tests de régression couvrent ces corrections de cycle de vie et de gestion des erreurs.
- APK debug compilé avec `API_BASE_URL=http://10.0.2.2:8081` : `build/app/outputs/flutter-apk/app-debug.apk`.
- Validation réelle avec EmbeddingGemma et Qwen3 : extraction et indexation des deux pages du PDF, recherche française sur un passage anglais, réponse française citant la page 2, refus d'une question hors contexte, isolation des comptes, persistance après redémarrage et suppression des vecteurs validés.
- Correction du prompt de génération : exemple explicite et description du champ `answer` pour demander les marqueurs `[1]` dans le texte. Qwen omettait ces marqueurs malgré une citation exacte dans le tableau `citations`, ce qui entraînait un rejet correct par le serveur. Les contrôles de citations restent inchangés.

Cette validation utilise un PDF de test et des données temporaires ; elle ne mesure pas la qualité des réponses sur tous les cours et ne remplace pas une vérification visuelle sur appareil.

## Références techniques

- API Ollama embeddings : https://docs.ollama.com/api/embed
- API Ollama chat : https://docs.ollama.com/api/chat
- Préfixes de recherche EmbeddingGemma : https://ai.google.dev/gemma/docs/embeddinggemma/model_card
- Modèles : https://ollama.com/library/embeddinggemma et https://ollama.com/library/qwen3:4b
