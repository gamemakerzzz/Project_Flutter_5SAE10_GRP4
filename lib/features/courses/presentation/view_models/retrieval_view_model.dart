import 'package:flutter/foundation.dart';

import '../../data/courses_repository.dart';
import '../../models/course_models.dart';

class ChatTurn {
  const ChatTurn(this.question, this.answer);
  final String question;
  final RagAnswer answer;
}

class RetrievalViewModel extends ChangeNotifier {
  RetrievalViewModel(this.repository, this.courseId);
  final CoursesRepository repository;
  final String courseId;
  List<SourcePassage> results = [];
  final List<ChatTurn> turns = [];
  bool busy = false, searched = false, _disposed = false;
  String? error;
  int _generation = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> submit(String query, {required bool chat}) async {
    if (busy || query.trim().isEmpty) return;
    final generation = _generation;
    busy = true;
    error = null;
    _notify();
    try {
      if (chat) {
        final answer = await repository.ask(courseId, query.trim());
        if (!_disposed && generation == _generation) {
          turns.add(ChatTurn(query.trim(), answer));
        }
      } else {
        final next = await repository.search(courseId, query.trim());
        if (!_disposed && generation == _generation) {
          results = next;
          searched = true;
        }
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is CoursesException
            ? e.message
            : 'Could not retrieve course passages. Please retry.';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  void reset() {
    _generation++;
    turns.clear();
    results = [];
    searched = false;
    busy = false;
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
