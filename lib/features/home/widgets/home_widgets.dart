import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';

/// AdService - Manages ad display and free quiz limits
class AdService {
  static AdService? _instance;
  static const int _freeQuizLimit = 3;
  int _quizCount = 0;
  bool _initialized = false;

  factory AdService() {
    _instance ??= AdService._internal();
    return _instance!;
  }

  AdService._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _quizCount = prefs.getInt('daily_quiz_count') ?? 0;

    // Reset count if it's a new day
    final lastDate = prefs.getString('last_quiz_date');
    final today = DateTime.now().toIso8601String().split('T').first;
    if (lastDate != today) {
      _quizCount = 0;
      await prefs.setString('last_quiz_date', today);
      await prefs.setInt('daily_quiz_count', 0);
    }
    _initialized = true;
  }

  bool isLimitReached() => _quizCount >= _freeQuizLimit;

  int getRemainingFreeQuizzes() =>
      (_freeQuizLimit - _quizCount).clamp(0, _freeQuizLimit);

  void incrementQuizCount() async {
    _quizCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_quiz_count', _quizCount);
  }

  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdFailed,
  }) {
    // TODO: Integrate with google_mobile_ads for production
    // For now, just reward the user
    onRewardEarned();
  }

  bool isFlashcardLimitReached() => false;
  void incrementFlashcardCount() {}
}

/// DailyRewardSheet - Shows daily login reward
class DailyRewardSheet extends StatelessWidget {
  final int day;
  final int xpReward;
  final VoidCallback onClaim;

  const DailyRewardSheet({
    super.key,
    required this.day,
    required this.xpReward,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '🎉 Day $day Streak!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You earned $xpReward XP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onClaim();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B13EC),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Claim Reward',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// QuizGenerationLoadingScreen - Shows while quiz is being generated
class QuizGenerationLoadingScreen extends StatelessWidget {
  final String? title;
  final String? subtitle;

  const QuizGenerationLoadingScreen({super.key, this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: Color(0xFF5B13EC),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title ?? 'Generating...',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? 'AI is crafting questions for you',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// StudyInputScreen - For deep study input
class StudyInputScreen extends StatelessWidget {
  const StudyInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Mode')),
      body: const Center(child: Text('Study Input Screen - Coming Soon')),
    );
  }
}

class QuizConfigSheet extends StatefulWidget {
  final String topic;
  final Function(int count, String difficulty) onGenerate;

  const QuizConfigSheet({
    super.key,
    required this.topic,
    required this.onGenerate,
  });

  @override
  State<QuizConfigSheet> createState() => _QuizConfigSheetState();
}

class _QuizConfigSheetState extends State<QuizConfigSheet> {
  int _questionCount = 10;
  String _difficulty = 'Medium';
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<int> _counts = [5, 10, 15, 20];

  static const primaryColor = Color(0xFF5B13EC);

  String _getLocalizedDifficulty(BuildContext context, String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return AppLocalizations.of(context)!.difficultyEasy;
      case 'Medium':
        return AppLocalizations.of(context)!.difficultyMedium;
      case 'Hard':
        return AppLocalizations.of(context)!.difficultyHard;
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            localizations.configureQuizTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${localizations.topicLabel}: ${widget.topic}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Difficulty Selector
          Text(
            localizations.difficultyLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: _difficulties.map((diff) {
                return ButtonSegment<String>(
                  value: diff,
                  label: Text(
                    _getLocalizedDifficulty(context, diff),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              selected: {_difficulty},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _difficulty = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return primaryColor;
                  }
                  return isDark ? Colors.white10 : Colors.grey.shade100;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return textColor;
                }),
              ),
              showSelectedIcon: false,
            ),
          ),

          const SizedBox(height: 24),

          // Question Count Selector
          Text(
            localizations.questionCountLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: _counts.map((count) {
                return ButtonSegment<int>(
                  value: count,
                  label: Text(
                    count.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              selected: {_questionCount},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _questionCount = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return primaryColor;
                  }
                  return isDark ? Colors.white10 : Colors.grey.shade100;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return textColor;
                }),
              ),
              showSelectedIcon: false,
            ),
          ),

          const SizedBox(height: 40),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => widget.onGenerate(_questionCount, _difficulty),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Text(
                localizations.startGeneratingButton,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
