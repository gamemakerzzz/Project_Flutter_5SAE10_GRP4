import '../repositories/store.dart';

/// Inference is server-only and receives only authorized course passages.
abstract interface class RagProvider {
  String get embeddingKey;
  String get chatModel;
  Future<void> checkReady();
  Future<List<List<double>>> embed(List<String> texts, {required bool query});
  Future<Json> generate(String question, List<Json> sources);
  void close();
}
