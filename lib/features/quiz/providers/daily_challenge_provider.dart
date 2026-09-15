import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ==================== MODELS ====================

/// Represents a single daily challenge question
class DailyChallengeQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? originalQuizId;
  final String? topic;

  const DailyChallengeQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.originalQuizId,
    this.topic,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'originalQuizId': originalQuizId,
      'topic': topic,
    };
  }

  factory DailyChallengeQuestion.fromJson(Map<String, dynamic> json) {
    return DailyChallengeQuestion(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctIndex: json['correctIndex'] as int,
      explanation: json['explanation'] as String? ?? '',
      originalQuizId: json['originalQuizId'] as String?,
      topic: json['topic'] as String?,
    );
  }
}

/// Represents the daily challenge state for a given day
class DailyChallengeState {
  final String date; // YYYY-MM-DD
  final int score;
  final int totalQuestions;
  final bool isCompleted;
  final DateTime? completedAt;
  final int xpEarned;
  final List<int> userAnswers;

  const DailyChallengeState({
    required this.date,
    this.score = 0,
    this.totalQuestions = 10,
    this.isCompleted = false,
    this.completedAt,
    this.xpEarned = 0,
    this.userAnswers = const [],
  });

  double get percentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'score': score,
      'totalQuestions': totalQuestions,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'xpEarned': xpEarned,
      'userAnswers': userAnswers,
    };
  }

  factory DailyChallengeState.fromJson(Map<String, dynamic> json) {
    return DailyChallengeState(
      date: json['date'] as String,
      score: json['score'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 10,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      xpEarned: json['xpEarned'] as int? ?? 0,
      userAnswers: json['userAnswers'] != null
          ? List<int>.from(json['userAnswers'] as List)
          : [],
    );
  }
}

/// Represents the 7-day streak calendar data
class StreakCalendarData {
  final List<StreakDay> days;
  final int currentStreak;
  final int longestStreak;

  const StreakCalendarData({
    required this.days,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  factory StreakCalendarData.empty() {
    return StreakCalendarData(
      days: List.generate(7, (index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        return StreakDay(
          date: date,
          isCompleted: false,
          isToday: index == 6,
        );
      }),
    );
  }
}

/// Represents a single day in the streak calendar
class StreakDay {
  final DateTime date;
  final bool isCompleted;
  final bool isToday;
  final int? score;
  final int? totalQuestions;

  const StreakDay({
    required this.date,
    this.isCompleted = false,
    this.isToday = false,
    this.score,
    this.totalQuestions,
  });
}

/// ==================== CONSTANTS ====================

class DailyChallengeKeys {
  static const String questionPool = 'daily_challenge_question_pool';
  static const String currentChallenge = 'daily_challenge_current';
  static const String challengeHistory = 'daily_challenge_history';
  static const String lastChallengeDate = 'daily_challenge_last_date';
  static const String currentStreak = 'daily_challenge_streak';
  static const String longestStreak = 'daily_challenge_longest_streak';
  static const String totalChallengesCompleted =
      'daily_challenge_total_completed';
  static const String totalXPEarned = 'daily_challenge_total_xp';
  static const String lastPoolRefreshDate = 'daily_challenge_pool_refresh_date';
}

/// ==================== SERVICE ====================

/// Manages daily challenge generation, caching, and persistence
class DailyChallengeService {
  static DailyChallengeService? _instance;
  static DailyChallengeService get instance => _instance ??= DailyChallengeService._();

  DailyChallengeService._();

  static const int questionsPerChallenge = 10;
  static const int baseXPReward = 50;
  static const int streakBonusXP = 10; // Extra XP per streak day
  static const int poolSize = 50; // Cache this many questions

  /// Get today's date string
  String get todayString => DateTime.now().toIso8601String().split('T').first;

  /// Check if a new challenge is available today
  Future<bool> isChallengeAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(DailyChallengeKeys.lastChallengeDate);
    return lastDate != todayString;
  }

  /// Generate today's daily challenge from cached quiz history
  Future<List<DailyChallengeQuestion>> generateDailyChallenge() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if already completed today
    if (!await isChallengeAvailable()) {
      return getCurrentChallenge();
    }

    // Get cached questions from quiz history
    final cachedQuestions = await _getCachedQuestions(prefs);

    if (cachedQuestions.isEmpty) {
      // Fallback: generate generic questions if no cached data
      return _generateFallbackQuestions();
    }

    // Shuffle and pick questions
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final shuffled = List<Map<String, dynamic>>.from(cachedQuestions)
      ..shuffle(random);

    final selected = shuffled.take(questionsPerChallenge).toList();

    // Convert to DailyChallengeQuestion
    final questions = selected.map((q) {
      return DailyChallengeQuestion(
        id: q['id'] ?? 'fallback_${random.nextInt(99999)}',
        questionText: q['questionText'] ?? q['question'] ?? 'Unknown question',
        options: List<String>.from(q['options'] ?? ['A', 'B', 'C', 'D']),
        correctIndex: q['correctIndex'] ?? q['correctAnswer'] ?? 0,
        explanation: q['explanation'] ?? '',
        originalQuizId: q['originalQuizId'] ?? q['quizId'],
        topic: q['topic'],
      );
    }).toList();

    // If we don't have enough questions, pad with fallback
    if (questions.length < questionsPerChallenge) {
      final fallback = _generateFallbackQuestions(
        count: questionsPerChallenge - questions.length,
      );
      questions.addAll(fallback);
    }

    // Save current challenge
    final challengeJson = questions.map((q) => q.toJson()).toList();
    await prefs.setString(
      DailyChallengeKeys.currentChallenge,
      jsonEncode(challengeJson),
    );

    return questions;
  }

  /// The full local question pool (all cached questions, not just today's
  /// 10), as typed models — the data source for the practice feed (ScrollPrep).
  Future<List<DailyChallengeQuestion>> getQuestionPool() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await _getCachedQuestions(prefs);
    final questions = <DailyChallengeQuestion>[];
    for (var i = 0; i < cached.length; i++) {
      final q = cached[i];
      questions.add(
        DailyChallengeQuestion(
          id: q['id']?.toString() ?? 'pool_$i',
          questionText: (q['questionText'] ?? q['question'] ?? '').toString(),
          options: List<String>.from(q['options'] ?? const ['A', 'B', 'C', 'D']),
          correctIndex: q['correctIndex'] ?? q['correctAnswer'] ?? 0,
          explanation: (q['explanation'] ?? '').toString(),
          originalQuizId: q['originalQuizId']?.toString() ?? q['quizId']?.toString(),
          topic: q['topic']?.toString(),
        ),
      );
    }
    return questions;
  }

  /// Get cached questions from quiz history (SharedPreferences)
  Future<List<Map<String, dynamic>>> _getCachedQuestions(
    SharedPreferences prefs,
  ) async {
    final cachedData = prefs.getString(DailyChallengeKeys.questionPool);
    if (cachedData == null || cachedData.isEmpty) {
      // Try to populate from quiz history
      await _populateQuestionPool(prefs);
      final newData = prefs.getString(DailyChallengeKeys.questionPool);
      if (newData == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(newData));
    }

    return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
  }

  /// Populate question pool from past quiz results
  Future<void> _populateQuestionPool(SharedPreferences prefs) async {
    // Get quiz history from Appwrite (stored locally after quiz completion)
    final quizHistoryJson = prefs.getString('quiz_history_local');
    if (quizHistoryJson == null) {
      // Try the quiz_results key used by QuizService
      final resultsJson = prefs.getString('quiz_results');
      if (resultsJson == null) return;

      final results = List<Map<String, dynamic>>.from(jsonDecode(resultsJson));
      final allQuestions = <Map<String, dynamic>>[];

      for (final result in results) {
        final questionsJson = result['questionsJson'];
        if (questionsJson != null) {
          final questions =
              List<Map<String, dynamic>>.from(jsonDecode(questionsJson));
          for (int i = 0; i < questions.length; i++) {
            allQuestions.add({
              'id': 'q_${result['quizId']}_$i',
              'questionText': questions[i]['questionText'] ??
                  questions[i]['question'] ??
                  '',
              'options': questions[i]['options'] ?? ['A', 'B', 'C', 'D'],
              'correctIndex': questions[i]['correctIndex'] ??
                  questions[i]['correctAnswer'] ??
                  0,
              'explanation': questions[i]['explanation'] ?? '',
              'originalQuizId': result['quizId'],
              'topic': result['quizTitle'] ?? result['topic'],
            });
          }
        }
      }

      if (allQuestions.isNotEmpty) {
        await prefs.setString(
          DailyChallengeKeys.questionPool,
          jsonEncode(allQuestions),
        );
        await prefs.setString(
          DailyChallengeKeys.lastPoolRefreshDate,
          todayString,
        );
      }
      return;
    }

    final history = List<Map<String, dynamic>>.from(jsonDecode(quizHistoryJson));
    await prefs.setString(
      DailyChallengeKeys.questionPool,
      jsonEncode(history),
    );
    await prefs.setString(
      DailyChallengeKeys.lastPoolRefreshDate,
      todayString,
    );
  }

  /// Add questions to the practice pool (called after quiz completion)
  Future<void> addToQuestionPool(List<Map<String, dynamic>> questions, {
    String? quizId,
    String? topic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _getCachedQuestions(prefs);

    final newQuestions = questions.map((q) {
      return {
        'id': q['id'] ?? '${quizId}_${existing.length + questions.indexOf(q)}',
        'questionText': q['questionText'] ?? q['question'] ?? '',
        'options': q['options'] ?? ['A', 'B', 'C', 'D'],
        'correctIndex':
            q['correctIndex'] ?? q['correctAnswer'] ?? q['correctOption'] ?? 0,
        'explanation': q['explanation'] ?? '',
        'originalQuizId': quizId ?? q['quizId'],
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
      DailyChallengeKeys.questionPool,
      jsonEncode(trimmed),
    );
  }

  /// Get fallback questions when no cached data is available
  List<DailyChallengeQuestion> _generateFallbackQuestions({int count = 10}) {
    final fallbackQuestions = [
      {
        'questionText': 'What is the capital of France?',
        'options': ['London', 'Paris', 'Berlin', 'Madrid'],
        'correctIndex': 1,
        'explanation': 'Paris has been the capital of France since 508 CE.',
      },
      {
        'questionText': 'Which planet is known as the Red Planet?',
        'options': ['Venus', 'Jupiter', 'Mars', 'Saturn'],
        'correctIndex': 2,
        'explanation': 'Mars appears red due to iron oxide on its surface.',
      },
      {
        'questionText': 'What is the largest ocean on Earth?',
        'options': ['Atlantic', 'Indian', 'Arctic', 'Pacific'],
        'correctIndex': 3,
        'explanation':
            'The Pacific Ocean covers about 63 million square miles.',
      },
      {
        'questionText': 'Who painted the Mona Lisa?',
        'options': ['Michelangelo', 'Raphael', 'Leonardo da Vinci', 'Donatello'],
        'correctIndex': 2,
        'explanation':
            'Leonardo da Vinci painted it between 1503-1519.',
      },
      {
        'questionText': 'What is the chemical symbol for gold?',
        'options': ['Go', 'Gd', 'Au', 'Ag'],
        'correctIndex': 2,
        'explanation': 'Au comes from the Latin word "aurum" meaning gold.',
      },
      {
        'questionText': 'Which gas do plants absorb from the atmosphere?',
        'options': ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'],
        'correctIndex': 2,
        'explanation': 'Plants use CO2 for photosynthesis.',
      },
      {
        'questionText': 'What is the speed of light approximately?',
        'options': [
          '300,000 km/s',
          '150,000 km/s',
          '500,000 km/s',
          '1,000,000 km/s'
        ],
        'correctIndex': 0,
        'explanation':
            'Light travels at approximately 299,792 km/s in vacuum.',
      },
      {
        'questionText': 'Which element has the atomic number 1?',
        'options': ['Helium', 'Hydrogen', 'Lithium', 'Carbon'],
        'correctIndex': 1,
        'explanation': 'Hydrogen is the lightest and most abundant element.',
      },
      {
        'questionText': 'What year did World War II end?',
        'options': ['1943', '1944', '1945', '1946'],
        'correctIndex': 2,
        'explanation': 'WWII ended in 1945 with Japan\'s surrender.',
      },
      {
        'questionText': 'What is the largest mammal?',
        'options': ['African Elephant', 'Blue Whale', 'Giraffe', 'Hippopotamus'],
        'correctIndex': 1,
        'explanation':
            'The Blue Whale can reach up to 100 feet in length.',
      },
      {
        'questionText': 'Which country has the most population?',
        'options': ['USA', 'China', 'India', 'Indonesia'],
        'correctIndex': 2,
        'explanation': 'India surpassed China as the most populous country in 2023.',
      },
      {
        'questionText': 'What is the hardest natural substance?',
        'options': ['Gold', 'Iron', 'Diamond', 'Platinum'],
        'correctIndex': 2,
        'explanation': 'Diamond scores 10 on the Mohs hardness scale.',
      },
      {
        'questionText': 'How many continents are there?',
        'options': ['5', '6', '7', '8'],
        'correctIndex': 2,
        'explanation': 'The 7 continents are: Asia, Africa, North America, South America, Antarctica, Europe, and Australia.',
      },
      {
        'questionText': 'What is the boiling point of water?',
        'options': ['90°C', '95°C', '100°C', '110°C'],
        'correctIndex': 2,
        'explanation': 'Water boils at 100°C (212°F) at sea level.',
      },
      {
        'questionText': 'Which organ pumps blood in the human body?',
        'options': ['Liver', 'Brain', 'Lungs', 'Heart'],
        'correctIndex': 3,
        'explanation': 'The heart pumps about 5 liters of blood per minute.',
      },
    ];

    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final shuffled = List<Map<String, dynamic>>.from(fallbackQuestions)
      ..shuffle(random);

    return shuffled.take(count).map((q) {
      return DailyChallengeQuestion(
        id: 'fallback_${random.nextInt(99999)}',
        questionText: q['questionText'] as String,
        options: List<String>.from(q['options'] as List),
        correctIndex: q['correctIndex'] as int,
        explanation: q['explanation'] as String? ?? '',
      );
    }).toList();
  }

  /// Get the current challenge questions
  Future<List<DailyChallengeQuestion>> getCurrentChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final challengeJson = prefs.getString(DailyChallengeKeys.currentChallenge);
    if (challengeJson == null) return [];

    final List<dynamic> decoded = jsonDecode(challengeJson);
    return decoded
        .map((q) => DailyChallengeQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  /// Save challenge results
  Future<DailyChallengeState> saveChallengeResult({
    required int score,
    required int totalQuestions,
    required List<int> userAnswers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = todayString;

    // Calculate XP (2x normal reward)
    final baseXP = baseXPReward * score ~/ totalQuestions;
    final currentStreak = await getStreak();
    final streakBonus = currentStreak * streakBonusXP;
    final totalXP = baseXP + streakBonus;

    final state = DailyChallengeState(
      date: today,
      score: score,
      totalQuestions: totalQuestions,
      isCompleted: true,
      completedAt: DateTime.now(),
      xpEarned: totalXP,
      userAnswers: userAnswers,
    );

    // Save today's result
    await prefs.setString(DailyChallengeKeys.lastChallengeDate, today);

    // Save to history
    final historyJson = prefs.getString(DailyChallengeKeys.challengeHistory);
    final List<Map<String, dynamic>> history = historyJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(historyJson))
        : [];

    // Remove existing entry for today if any
    history.removeWhere((entry) => entry['date'] == today);
    history.add(state.toJson());

    // Keep only last 90 days
    if (history.length > 90) {
      history.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      history.removeRange(90, history.length);
    }

    await prefs.setString(
      DailyChallengeKeys.challengeHistory,
      jsonEncode(history),
    );

    // Update total stats
    final totalCompleted =
        prefs.getInt(DailyChallengeKeys.totalChallengesCompleted) ?? 0;
    final totalXPAll = prefs.getInt(DailyChallengeKeys.totalXPEarned) ?? 0;
    await prefs.setInt(
      DailyChallengeKeys.totalChallengesCompleted,
      totalCompleted + 1,
    );
    await prefs.setInt(DailyChallengeKeys.totalXPEarned, totalXPAll + totalXP);

    return state;
  }

  /// Get current streak
  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(DailyChallengeKeys.currentStreak) ?? 0;
  }

  /// Get longest streak
  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(DailyChallengeKeys.longestStreak) ?? 0;
  }

  /// Update streak after completing today's challenge
  Future<int> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastDate = prefs.getString(DailyChallengeKeys.lastChallengeDate);
    int currentStreak = prefs.getInt(DailyChallengeKeys.currentStreak) ?? 0;
    int longestStreak = prefs.getInt(DailyChallengeKeys.longestStreak) ?? 0;

    if (lastDate == null) {
      currentStreak = 1;
    } else {
      final last = DateTime.parse(lastDate);
      final lastDay = DateTime(last.year, last.month, last.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 1) {
        currentStreak++;
      } else if (diff > 1) {
        currentStreak = 1; // Streak broken
      }
      // If diff == 0, already completed today, keep streak
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
      await prefs.setInt(DailyChallengeKeys.longestStreak, longestStreak);
    }

    await prefs.setInt(DailyChallengeKeys.currentStreak, currentStreak);
    return currentStreak;
  }

  /// Get 7-day streak calendar data
  Future<StreakCalendarData> getStreakCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(DailyChallengeKeys.challengeHistory);
    final List<Map<String, dynamic>> history = historyJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(historyJson))
        : [];

    final historyMap = <String, DailyChallengeState>{};
    for (final entry in history) {
      final state = DailyChallengeState.fromJson(entry);
      historyMap[state.date] = state;
    }

    final now = DateTime.now();
    final days = <StreakDay>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      final isToday = i == 0;
      final completed = historyMap[dateStr];

      days.add(StreakDay(
        date: date,
        isCompleted: completed?.isCompleted ?? false,
        isToday: isToday,
        score: completed?.score,
        totalQuestions: completed?.totalQuestions,
      ));
    }

    final currentStreak = await getStreak();
    final longestStreak = await getLongestStreak();

    return StreakCalendarData(
      days: days,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }

  /// Get motivational message based on performance
  String getMotivationalMessage(double percentage, int streak) {
    if (percentage >= 100) {
      return streak >= 7
          ? '🏆 PERFECT! You\'re on fire with a $streak-day streak!'
          : '🏆 PERFECT SCORE! Absolutely brilliant!';
    }
    if (percentage >= 80) {
      return streak >= 7
          ? '⭐ Amazing! $streak days strong and crushing it!'
          : '⭐ Excellent work! You\'re a natural!';
    }
    if (percentage >= 60) {
      return '💪 Great effort! Keep the momentum going!';
    }
    if (percentage >= 40) {
      return '📚 Good progress! Every question is a learning opportunity!';
    }
    return '🌱 Don\'t give up! Practice makes perfect!';
  }

  /// Get motivational subtitle for the challenge screen
  String getChallengeSubtitle(int streak, bool isCompleted) {
    if (isCompleted) {
      return 'Come back tomorrow for a new challenge!';
    }
    if (streak >= 7) {
      return '🔥 $streak Day Streak — You\'re Unstoppable!';
    }
    if (streak >= 3) {
      return '🔥 $streak Day Streak — Keep the Fire Burning!';
    }
    if (streak > 0) {
      return '$streak Day Streak — Let\'s Make It $streak+1!';
    }
    return 'Start your streak today!';
  }

  /// Get time remaining until next challenge
  Duration getTimeUntilNextChallenge() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}

/// ==================== PROVIDERS ====================

/// Provider for DailyChallengeService
final dailyChallengeServiceProvider = Provider<DailyChallengeService>((ref) {
  return DailyChallengeService.instance;
});

/// Provider for today's challenge questions
final dailyChallengeQuestionsProvider =
    FutureProvider<List<DailyChallengeQuestion>>((ref) async {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.generateDailyChallenge();
});

/// Provider for challenge availability (has the user completed today's?)
final isChallengeAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.isChallengeAvailable();
});

/// Provider for current streak
final dailyChallengeStreakProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.getStreak();
});

/// Provider for longest streak
final dailyChallengeLongestStreakProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.getLongestStreak();
});

/// Provider for 7-day streak calendar
final streakCalendarProvider = FutureProvider<StreakCalendarData>((ref) async {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.getStreakCalendar();
});

/// Provider for time until next challenge
final timeUntilNextChallengeProvider = Provider<Duration>((ref) {
  final service = ref.watch(dailyChallengeServiceProvider);
  return service.getTimeUntilNextChallenge();
});

/// Provider for total challenges completed
final totalChallengesCompletedProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(DailyChallengeKeys.totalChallengesCompleted) ?? 0;
});

/// Provider for total XP earned from daily challenges
final totalChallengeXPProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(DailyChallengeKeys.totalXPEarned) ?? 0;
});
