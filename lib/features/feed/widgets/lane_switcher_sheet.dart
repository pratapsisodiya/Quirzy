import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/quiz_theme.dart';
import '../models/feed_models.dart';
import '../providers/feed_providers.dart';

IconData _iconForLane(FeedLaneType type) {
  switch (type) {
    case FeedLaneType.mixed:
      return Icons.explore_rounded;
    case FeedLaneType.topic:
      return Icons.layers_rounded;
    case FeedLaneType.weakTopics:
      return Icons.trending_up_rounded;
    case FeedLaneType.revision:
      return Icons.history_rounded;
    case FeedLaneType.bookmarks:
      return Icons.bookmark_rounded;
  }
}

/// Swipe-right drawer (PRD §5.2 / §F3): pick a lane, feed reloads there.
class LaneSwitcherSheet extends ConsumerWidget {
  const LaneSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LaneSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lanesAsync = ref.watch(feedLanesProvider);
    final currentLaneId = ref.watch(feedControllerProvider).lane.id;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: isDark ? QuizTheme.surfaceDark : QuizTheme.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Switch lane',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: lanesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Could not load lanes.', style: GoogleFonts.plusJakartaSans()),
                ),
                data: (lanes) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: lanes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final lane = lanes[i];
                    final selected = lane.id == currentLaneId;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(feedControllerProvider.notifier).switchLane(lane, restorePosition: true);
                          Navigator.of(context).pop();
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: selected ? QuizTheme.primary.withOpacity(0.08) : null,
                        leading: Icon(_iconForLane(lane.type), color: selected ? QuizTheme.primary : (isDark ? Colors.white54 : Colors.black45)),
                        title: Text(
                          lane.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? QuizTheme.primary : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        trailing: Text(
                          '${lane.count}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
