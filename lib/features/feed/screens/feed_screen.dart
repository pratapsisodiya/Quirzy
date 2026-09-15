import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/providers.dart';
import '../../../shared/theme/quiz_theme.dart';
import '../../quiz/providers/daily_challenge_provider.dart';
import '../models/feed_models.dart';
import '../providers/feed_providers.dart';
import '../widgets/deep_dive_sheet.dart';
import '../widgets/feed_question_card.dart';
import '../widgets/lane_switcher_sheet.dart';
import '../widgets/long_press_menu_sheet.dart';

/// ScrollPrep's core loop: one question per screen, vertical infinite feed.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int newIndex, FeedState feedState) {
    final controller = ref.read(feedControllerProvider.notifier);

    if (feedState.focusMode && newIndex > _currentIndex) {
      final leavingIndex = _currentIndex;
      final stillBlocked = leavingIndex < feedState.cards.length && !feedState.cards[leavingIndex].isResolved;
      if (stillBlocked) {
        HapticFeedback.heavyImpact();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              leavingIndex,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer or skip this question to continue'),
            duration: Duration(milliseconds: 1400),
          ),
        );
        return;
      }
    }

    if (newIndex == _currentIndex) return;
    setState(() => _currentIndex = newIndex);
    if (ref.read(feedControllerProvider).showHints) {
      controller.dismissHints();
    }
    controller.savePosition(newIndex);
  }

  void _openDeepDive(DailyChallengeQuestion question, int index) {
    DeepDiveSheet.show(context, question, index);
  }

  void _openLaneSwitcher() {
    LaneSwitcherSheet.show(context);
  }

  void _openLongPressMenu(DailyChallengeQuestion question) {
    LongPressMenuSheet.show(context, question);
  }

  void _showBreakNudge(FeedState feedState) {
    final controller = ref.read(feedControllerProvider.notifier);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take 5?'),
        content: Text("You've done ${feedState.sessionAnswered} questions this session."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('5 more min'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(tabIndexProvider.notifier).state = 1; // Home tab
            },
            child: const Text('Take a break'),
          ),
        ],
      ),
    ).then((_) => controller.acknowledgeBreakNudge());
  }

  void _showTargetBanner() {
    final controller = ref.read(feedControllerProvider.notifier);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Daily target reached — $kFeedDailyTarget questions today!'),
        backgroundColor: QuizTheme.success,
        duration: const Duration(seconds: 3),
      ),
    );
    controller.acknowledgeTargetBanner();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<FeedState>(feedControllerProvider, (previous, next) {
      // Fires once a lane finishes (re)loading — covers the very first
      // load, every lane switch, and a reshuffle — so the page view always
      // lands on the right starting card.
      final justLoaded = (previous?.loading ?? false) && !next.loading;
      if (justLoaded) {
        _currentIndex = next.startIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(next.startIndex);
          }
        });
      }
      if (next.pendingBreakNudge && !(previous?.pendingBreakNudge ?? false)) {
        _showBreakNudge(next);
      }
      if (next.pendingTargetBanner && !(previous?.pendingTargetBanner ?? false)) {
        _showTargetBanner();
      }
    });

    if (feedState.loading && feedState.cards.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (feedState.cards.isEmpty) {
      return _buildEmptyState(isDark);
    }

    final itemCount = feedState.cards.length + 1; // + end-of-lane sentinel

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        itemCount: itemCount,
        onPageChanged: (i) => _handlePageChanged(i, feedState),
        itemBuilder: (context, index) {
          if (index == feedState.cards.length) {
            return _buildEndOfLane(feedState, controller, isDark);
          }
          final card = feedState.cards[index];
          return RepaintBoundary(
            key: ValueKey('feed_card_${card.question.id}_$index'),
            child: FeedQuestionCard(
              cardState: card,
              showGestureHint: feedState.showHints && index == 0,
              positionInLane: index + 1,
              laneLength: feedState.cards.length,
              sessionAccuracy: feedState.sessionAccuracy,
              sessionAnswered: feedState.sessionAnswered,
              onSelectOption: (opt) => controller.selectOption(index, opt),
              onSkip: () => controller.skipCurrent(index),
              onBookmarkToggle: () => controller.toggleBookmark(index),
              onOpenDeepDive: () => _openDeepDive(card.question, index),
              onOpenLaneSwitcher: _openLaneSwitcher,
              onLongPressMenu: () => _openLongPressMenu(card.question),
              onWrongReason: controller.recordWrongReason,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 20),
              Text(
                'Your practice feed is empty',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Generate or take a quiz first — every question you attempt joins this feed for reels-style revision.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: QuizTheme.primary),
                onPressed: () => ref.read(tabIndexProvider.notifier).state = 1,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('Go to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndOfLane(FeedState feedState, FeedController controller, bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 56, color: QuizTheme.primary),
            const SizedBox(height: 18),
            Text(
              "You're all caught up",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You finished every question in "${feedState.lane.label}" for now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: QuizTheme.primary),
              onPressed: () => controller.reshuffleCurrentLane(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Replay this lane'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _openLaneSwitcher,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Browse another lane'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
