import 'dart:async';
import 'dart:convert';

import '../http/api_error.dart';
import '../repositories/store.dart';
import 'ollama_provider.dart';
import 'rag_contracts.dart';

class RagService {
  RagService(this.store, this.provider, {this.minimumScore = 0.25});
  final Store store;
  final RagProvider? provider;
  final double minimumScore;
  final Map<String, Future<void>> jobs = {};
  final Map<String, String> errors = {};
  Future<void> tail = Future.value();
  bool closing = false;
  int active = 0;
  RagProvider get ai =>
      provider ??
      (throw const ApiError(
        501,
        'RAG_NOT_AVAILABLE',
        'Local AI is disabled. Configure Ollama on the server.',
      ));
  static const joins =
      'FROM document_chunks k JOIN documents d ON d.id=k.document_id JOIN courses c ON c.id=d.course_id';
  static const scope = "c.id=? AND c.user_id=? AND d.status='ready'";
  static const columns =
      'k.id AS chunkId,d.id AS documentId,c.id AS courseId,d.original_filename AS documentName,k.page_number AS page,k.content AS excerpt';

  Json status(String user, String course) {
    store.course(user, course);
    final model = ai.embeddingKey;
    final row = store.rows(
      'SELECT count(*) AS total, count(e.chunk_id) AS indexed $joins LEFT JOIN chunk_embeddings e ON e.chunk_id=k.id AND e.model=? WHERE $scope',
      [model, course, user],
    ).single;
    final total = row['total'] as int, indexed = row['indexed'] as int;
    return {
      'total': total,
      'indexed': indexed,
      'model': model,
      'state': jobs.containsKey(course)
          ? 'indexing'
          : errors.containsKey(course)
          ? 'failed'
          : total == indexed
          ? 'ready'
          : 'pending',
      'error': errors[course],
    };
  }

  Json enqueue(String user, String course) {
    final current = status(user, course);
    if (closing) {
      throw const ApiError(503, 'AI_UNAVAILABLE', 'Server is shutting down.');
    }
    if (current['total'] > 5000) {
      throw const ApiError(
        413,
        'INDEX_LIMIT',
        'A course can contain at most 5,000 passages for local semantic search.',
      );
    }
    if (jobs.containsKey(course) || current['state'] == 'ready') return current;
    if (jobs.length >= 32) {
      throw const ApiError(
        503,
        'AI_BUSY',
        'Indexing queue is full. Please retry later.',
      );
    }
    errors.remove(course);
    final job = tail
        .then((_) async {
          if (closing) return;
          try {
            await ai.checkReady();
            await _index(user, course);
          } catch (e) {
            errors[course] = e is ApiError
                ? e.message
                : 'Could not index course passages. Please retry.';
          }
        })
        .whenComplete(() {
          jobs.remove(course);
        });
    jobs[course] = job;
    tail = job;
    return status(user, course);
  }

  Future<void> _index(String user, String course) async {
    while (!closing) {
      final batch = store.rows(
        'SELECT k.id,k.content $joins LEFT JOIN chunk_embeddings e ON e.chunk_id=k.id AND e.model=? WHERE $scope AND e.chunk_id IS NULL ORDER BY k.id LIMIT 8',
        [ai.embeddingKey, course, user],
      );
      if (batch.isEmpty) return;
      final vectors = await ai.embed(
        batch.map((r) => r['content'] as String).toList(),
        query: false,
      );
      if (closing) return;
      if (vectors.length != batch.length) {
        throw const ApiError(502, 'AI_INVALID_RESPONSE', 'Missing embeddings.');
      }
      final normalized = vectors.map(OllamaProvider.normalizeVector).toList();
      if (normalized.any((v) => v.length != normalized.first.length)) {
        throw const ApiError(
          502,
          'AI_INVALID_RESPONSE',
          'Embedding dimensions changed.',
        );
      }
      store.database.transaction(() {
        for (var i = 0; i < batch.length; i++) {
          // Recheck existence and ownership after the asynchronous model call.
          store.execute(
            'INSERT OR REPLACE INTO chunk_embeddings(chunk_id,model,dimensions,vector) SELECT k.id,?,?,? $joins WHERE $scope AND k.id=? AND k.content=?',
            [
              ai.embeddingKey,
              normalized[i].length,
              jsonEncode(normalized[i]),
              course,
              user,
              batch[i]['id'],
              batch[i]['content'],
            ],
          );
        }
      });
    }
  }

  Future<T> _limited<T>(Future<T> Function() action) async {
    if (closing || active >= 2) {
      throw const ApiError(
        503,
        'AI_BUSY',
        'Local AI is busy. Please retry shortly.',
      );
    }
    active++;
    try {
      return await action();
    } finally {
      active--;
    }
  }

  Future<List<Json>> search(String user, Json body) =>
      _limited(() => _search(user, body));
  Future<List<Json>> _search(String user, Json body) async {
    final course = field(body, 'courseId'),
        query = field(body, 'query', max: 1000);
    store.course(user, course);
    final top = body['topK'] ?? 5;
    if (top is! int || top < 1 || top > 20) {
      throw const ApiError(
        400,
        'VALIDATION_ERROR',
        'topK must be between 1 and 20.',
      );
    }
    await ai.checkReady();
    final state = enqueue(user, course);
    if (state['state'] != 'ready') {
      throw const ApiError(
        409,
        'INDEXING',
        'Course passages are being indexed. Please retry when indexing completes.',
      );
    }
    if (state['total'] == 0) return [];
    final vectors = await ai.embed([query], query: true);
    if (vectors.length != 1) {
      throw const ApiError(
        502,
        'AI_INVALID_RESPONSE',
        'Missing query embedding.',
      );
    }
    final vector = OllamaProvider.normalizeVector(vectors.single);
    store.course(user, course);
    final rows = store.rows(
      'SELECT $columns,e.vector,e.dimensions $joins JOIN chunk_embeddings e ON e.chunk_id=k.id AND e.model=? WHERE $scope',
      [ai.embeddingKey, course, user],
    );
    final results = <Json>[];
    for (final row in rows) {
      if (row['dimensions'] != vector.length) {
        throw const ApiError(
          503,
          'INDEX_MODEL_CHANGED',
          'Embedding dimensions changed. Rebuild the course index.',
        );
      }
      final saved = OllamaProvider.normalizeVector(
        jsonDecode(row.remove('vector') as String),
      );
      row.remove('dimensions');
      if (saved.length != vector.length) {
        throw const ApiError(503, 'INDEX_INVALID', 'Rebuild the course index.');
      }
      var score = 0.0;
      for (var i = 0; i < vector.length; i++) {
        score += vector[i] * saved[i];
      }
      if (score >= minimumScore) {
        results.add({...row, 'score': score.clamp(-1.0, 1.0)});
      }
    }
    results.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return results.take(top).toList();
  }

  static Json insufficient() => {
    'answer': 'The uploaded materials do not contain enough evidence to answer this question.',
    'sources': <Json>[],
    'generated': false,
  };
  Future<Json> ask(String user, Json body) => _limited(() async {
    final course = field(body, 'courseId'),
        question = field(body, 'question', max: 1000);
    store.course(user, course);
    final sources = await _search(user, {
      'courseId': course,
      'query': question,
      'topK': 5,
    });
    if (sources.isEmpty) return insufficient();
    final result = await ai.generate(question, sources);
    store.course(user, course);
    if (result['supported'] == false) return insufficient();
    final answer = result['answer'], citations = result['citations'];
    if (result['supported'] != true ||
        answer is! String ||
        answer.trim().isEmpty ||
        answer.length > 8000 ||
        citations is! List ||
        citations.isEmpty ||
        citations.length > 10) {
      return insufficient();
    }
    final verified = <int, Json>{};
    for (final citation in citations) {
      if (citation is! Map ||
          citation['source'] is! int ||
          citation['quote'] is! String) {
        return insufficient();
      }
      final number = citation['source'] as int;
      final quote = (citation['quote'] as String).trim();
      if (number < 1 || number > sources.length || quote.length < 8) {
        return insufficient();
      }
      final source = sources[number - 1];
      if (!(source['excerpt'] as String).contains(quote)) return insufficient();
      // A deleted/reprocessed PDF cannot be cited after generation completes.
      final current = store.rows(
        'SELECT $columns $joins WHERE $scope AND k.id=?',
        [course, user, source['chunkId']],
      );
      if (current.isEmpty || current.single['excerpt'] != source['excerpt']) {
        return insufficient();
      }
      verified[number] = {...source, 'sourceNumber': number};
    }
    final numbers = RegExp(r'\[(\d+)\]')
        .allMatches(answer)
        .map((m) => int.tryParse(m[1]!))
        .toSet();
    if (numbers.isEmpty ||
        numbers.any((n) => !verified.containsKey(n)) ||
        verified.keys.any((n) => !numbers.contains(n))) {
      return insufficient();
    }
    final ordered = verified.keys.toList()..sort();
    return {
      'answer': answer.trim(),
      'sources': [for (final n in ordered) verified[n]!],
      'generated': true,
    };
  });

  Future<void> close() async {
    closing = true;
    provider?.close();
    await tail;
  }
}
