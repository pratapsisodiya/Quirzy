import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_models.dart';

class PracticeContentKeys {
  static const String questionPool = 'daily_challenge_question_pool';
  static const String lastPoolRefreshDate = 'daily_challenge_pool_refresh_date';
}

/// The feed's local content pool: builds and grows the set of practice
/// questions drawn from everything the user has generated or added, and
/// serves it to the feed as typed [PracticeQuestion]s.
class PracticeContentService {
  static PracticeContentService? _instance;
  static PracticeContentService get instance =>
      _instance ??= PracticeContentService._();

  PracticeContentService._();

  String get todayString => DateTime.now().toIso8601String().split('T').first;

  /// The full local question pool, as typed models — the data source for
  /// the practice feed.
  Future<List<PracticeQuestion>> getQuestionPool() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await _getCachedQuestions(prefs);
    final questions = <PracticeQuestion>[];
    for (var i = 0; i < cached.length; i++) {
      final q = cached[i];
      questions.add(
        PracticeQuestion(
          id: q['id']?.toString() ?? 'pool_$i',
          questionText: (q['questionText'] ?? q['question'] ?? '').toString(),
          options: List<String>.from(q['options'] ?? const ['A', 'B', 'C', 'D']),
          correctIndex: q['correctIndex'] ?? q['correctAnswer'] ?? 0,
          explanation: (q['explanation'] ?? '').toString(),
          sourceTopicId: q['sourceTopicId']?.toString() ?? q['originalQuizId']?.toString() ?? q['quizId']?.toString(),
          topic: q['topic']?.toString(),
        ),
      );
    }
    return questions;
  }

  Future<List<Map<String, dynamic>>> _getCachedQuestions(
    SharedPreferences prefs,
  ) async {
    final cachedData = prefs.getString(PracticeContentKeys.questionPool);
    if (cachedData == null || cachedData.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
  }

  /// Adds newly generated/added questions to the practice pool — called
  /// right after a topic is generated or manual questions are added, so
  /// the feed always has fresh content to practice.
  Future<void> addToQuestionPool(
    List<Map<String, dynamic>> questions, {
    String? topicId,
    String? topic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _getCachedQuestions(prefs);

    final newQuestions = questions.map((q) {
      return {
        'id': q['id'] ?? '${topicId}_${existing.length + questions.indexOf(q)}',
        'questionText': q['questionText'] ?? q['question'] ?? '',
        'options': q['options'] ?? ['A', 'B', 'C', 'D'],
        'correctIndex':
            q['correctIndex'] ?? q['correctAnswer'] ?? q['correctOption'] ?? 0,
        'explanation': q['explanation'] ?? '',
        'sourceTopicId': topicId ?? q['topicId'],
        'topic': topic ?? q['topic'],
      };
    }).toList();

    // Merge and deduplicate (by ID)
    final existingIds = existing.map((q) => q['id'] as String).toSet();
    final uniqueNew = newQuestions.where((q) => !existingIds.contains(q['id']));
    final merged = [...existing, ...uniqueNew];

    // Keep only the most recent questions (limit pool size)
    final trimmed = merged.length > 200
        ? merged.sublist(merged.length - 200)
        : merged;

    await prefs.setString(
      PracticeContentKeys.questionPool,
      jsonEncode(trimmed),
    );
    await prefs.setString(PracticeContentKeys.lastPoolRefreshDate, todayString);
  }
}

/// Provider for [PracticeContentService]
final practiceContentServiceProvider = Provider<PracticeContentService>((ref) {
  return PracticeContentService.instance;
});
