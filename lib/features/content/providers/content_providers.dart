import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/services.dart';
import '../services/study_material_service.dart';

/// Provider for [ContentService] singleton
final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService();
});

/// Provider to check if user can generate a new topic today (daily limit)
final canGenerateTopicProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final lastDate = prefs.getString('last_quiz_generation_date');
  final today = DateTime.now().toIso8601String().split('T').first;

  // Reset if it's a new day
  if (lastDate != today) {
    return true;
  }

  final quizCount = prefs.getInt('daily_quiz_generation_count') ?? 0;
  return quizCount < 2; // Free users get 2 topics per day
});

/// Tracks how many topics a free user has generated today (rate limit).
class GenerationLimitService {
  Future<void> recordUsage({required String topicId, required String topic}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;

    final lastDate = prefs.getString('last_quiz_generation_date');
    if (lastDate != today) {
      await prefs.setString('last_quiz_generation_date', today);
      await prefs.setInt('daily_quiz_generation_count', 1);
    } else {
      final count = (prefs.getInt('daily_quiz_generation_count') ?? 0) + 1;
      await prefs.setInt('daily_quiz_generation_count', count);
    }
  }

  Future<int> getTodayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('last_quiz_generation_date');
    final today = DateTime.now().toIso8601String().split('T').first;

    if (lastDate != today) return 0;
    return prefs.getInt('daily_quiz_generation_count') ?? 0;
  }

  Future<bool> hasReachedDailyLimit() async {
    final count = await getTodayCount();
    return count >= 2; // Free limit: 2 topics per day
  }
}

final generationLimitServiceProvider = Provider<GenerationLimitService>((ref) {
  return GenerationLimitService();
});

final studyQuizServiceProvider = Provider<StudyQuizService>((ref) => StudyQuizService());
final studyMaterialServiceProvider = Provider<StudyMaterialService>((ref) => StudyMaterialService());

final studyMaterialHistoryProvider = FutureProvider<List<StudyMaterial>>((ref) async {
  return ref.read(studyMaterialServiceProvider).getStudyHistory();
});
