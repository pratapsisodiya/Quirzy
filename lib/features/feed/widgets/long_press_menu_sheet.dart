import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/quiz_theme.dart';
import '../../quiz/providers/daily_challenge_provider.dart';
import '../providers/feed_providers.dart';

/// Long-press secondary menu (PRD §5.2): report a problem, rate the
/// question's difficulty, or mute its topic. All effects are local and
/// take hold from the next lane load onward.
class LongPressMenuSheet extends ConsumerWidget {
  final DailyChallengeQuestion question;

  const LongPressMenuSheet({super.key, required this.question});

  static Future<void> show(BuildContext context, DailyChallengeQuestion question) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LongPressMenuSheet(question: question),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = ref.read(feedControllerProvider.notifier);
    final topic = (question.topic == null || question.topic!.trim().isEmpty) ? 'General' : question.topic!;

    void notify(String message) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)),
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? QuizTheme.surfaceDark : QuizTheme.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.error_outline_rounded, color: QuizTheme.error),
              title: Text('Report a problem', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              subtitle: const Text('Wrong answer key, typo, or bad question'),
              onTap: () {
                controller.reportQuestion(question.id);
                notify('Reported — removed from your feed.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.thumb_up_rounded, color: QuizTheme.success),
              title: Text('Too easy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              onTap: () {
                controller.markTooEasy(question);
                notify("Got it — you'll see this less in Mixed.");
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_rounded, color: QuizTheme.warning),
              title: Text('Too hard', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              onTap: () {
                controller.markTooHard(question);
                notify('Added to your Revision Vault.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: QuizTheme.primary),
              title: Text('Mute "$topic"', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              onTap: () {
                controller.muteTopic(topic);
                notify('Muted — won\'t show up in Mixed anymore.');
              },
            ),
          ],
        ),
      ),
    );
  }
}
