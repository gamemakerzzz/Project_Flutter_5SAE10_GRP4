import 'dart:io';

import 'package:path/path.dart' as p;

class Config {
  Config({
    required this.secret,
    required this.dataDirectory,
    required this.pdfDirectory,
    this.ollamaUrl,
    this.embeddingModel = 'embeddinggemma:300m',
    this.chatModel = 'qwen3:4b',
  }) {
    if (secret.length < 32) {
      throw ArgumentError('JWT_SECRET must contain at least 32 characters.');
    }
  }
  factory Config.environment() {
    final root = Platform.environment['BACKEND_ROOT'] ?? Directory.current.path;
    return Config(
      secret: Platform.environment['JWT_SECRET'] ?? '',
      dataDirectory: p.join(root, 'data'),
      pdfDirectory: p.join(root, 'storage', 'pdfs'),
      ollamaUrl: Platform.environment['RAG_ENABLED'] == 'false'
          ? null
          : Uri.parse(
              Platform.environment['OLLAMA_BASE_URL'] ??
                  'http://127.0.0.1:11434',
            ),
      embeddingModel:
          Platform.environment['OLLAMA_EMBED_MODEL'] ?? 'embeddinggemma:300m',
      chatModel: Platform.environment['OLLAMA_CHAT_MODEL'] ?? 'qwen3:4b',
    );
  }
  final String secret, dataDirectory, pdfDirectory;
  final Uri? ollamaUrl;
  final String embeddingModel, chatModel;
}
