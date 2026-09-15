import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/theme/quiz_theme.dart';
import '../../quiz/providers/daily_challenge_provider.dart';
import '../../quiz/widgets/option_card.dart';
import '../models/feed_models.dart';
import 'question_timer.dart';

const List<String> kWrongAnswerReasons = [
  'Silly mistake',
  "Didn't know",
  'Ran out of time',
  'Misread it',
];

/// One full-bleed question card — the reels-style unit of the practice
/// feed (PRD §5.1). Vertical swiping is owned by the enclosing PageView;
/// this widget only handles gestures scoped to the question body: double
/// tap to bookmark, long press to pause + open the action menu, and a
/// horizontal drag to open Deep Dive / the Lane Switcher. The options
/// list sits outside that gesture region so answering stays instant.
class FeedQuestionCard extends StatefulWidget {
  final FeedCardState cardState;
  final bool showGestureHint;
  final int positionInLane;
  final int laneLength;
  final double sessionAccuracy;
  final int sessionAnswered;
  final ValueChanged<int> onSelectOption;
  final VoidCallback onSkip;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onOpenDeepDive;
  final VoidCallback onOpenLaneSwitcher;
  final VoidCallback onLongPressMenu;
  final ValueChanged<String> onWrongReason;

  const FeedQuestionCard({
    super.key,
    required this.cardState,
    required this.showGestureHint,
    required this.positionInLane,
    required this.laneLength,
    required this.sessionAccuracy,
    required this.sessionAnswered,
    required this.onSelectOption,
    required this.onSkip,
    required this.onBookmarkToggle,
    required this.onOpenDeepDive,
    required this.onOpenLaneSwitcher,
    required this.onLongPressMenu,
    required this.onWrongReason,
  });

  @override
  State<FeedQuestionCard> createState() => _FeedQuestionCardState();
}

class _FeedQuestionCardState extends State<FeedQuestionCard> {
  bool _paused = false;
  DateTime? _pressStart;
  bool _showHeart = false;
  bool _showPeek = false;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    if (widget.cardState.isResolved) {
      _startPeek();
    }
  }

  @override
  void didUpdateWidget(covariant FeedQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.cardState.isResolved && widget.cardState.isResolved) {
      _startPeek();
    }
  }

  void _startPeek() {
    setState(() => _showPeek = true);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showPeek = false);
    });
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    widget.onBookmarkToggle();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _pressStart = DateTime.now();
    setState(() => _paused = true);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() => _paused = false);
    final start = _pressStart;
    _pressStart = null;
    if (start != null && DateTime.now().difference(start).inMilliseconds >= 1200) {
      widget.onLongPressMenu();
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      widget.onOpenDeepDive();
    } else if (velocity > 250) {
      widget.onOpenLaneSwitcher();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final card = widget.cardState;
    final question = card.question;
    final resolved = card.isResolved;
    final laneLabel = (question.topic == null || question.topic!.trim().isEmpty) ? 'General' : question.topic!;
    final mutedText = isDark ? Colors.white60 : Colors.black54;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, isDark, laneLabel, card),
            const SizedBox(height: 6),
            _buildProgressBar(context, isDark),
            const SizedBox(height: 14),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _handleDoubleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressEnd: _handleLongPressEnd,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: _buildQuestionBody(context, isDark, question),
              ),
            ),
            const SizedBox(height: 14),
            ..._buildOptions(context, isDark, question, card, resolved),
            if (resolved && _showPeek) _buildPeek(context, isDark, question, card),
            if (resolved && !card.isCorrect && !card.skipped) _buildWrongReasons(context, isDark),
            const SizedBox(height: 10),
            _buildFooter(context, mutedText, resolved),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, String laneLabel, FeedCardState card) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onOpenLaneSwitcher,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: QuizTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, size: 15, color: QuizTheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      laneLabel,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: QuizTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: card.bookmarked ? 'Remove bookmark' : 'Bookmark',
          onPressed: widget.onBookmarkToggle,
          icon: Icon(
            Icons.bookmark_rounded,
            color: card.bookmarked ? QuizTheme.primary : (isDark ? Colors.white60 : Colors.black45),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Solution',
          onPressed: widget.onOpenDeepDive,
          icon: Icon(Icons.menu_book_rounded, color: isDark ? Colors.white60 : Colors.black45),
        ),
        QuestionTimer(paused: _paused, color: isDark ? Colors.white60 : Colors.black45),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, bool isDark) {
    final total = widget.laneLength == 0 ? 1 : widget.laneLength;
    final progress = (widget.positionInLane / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation(QuizTheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${widget.positionInLane}/${widget.laneLength}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBody(BuildContext context, bool isDark, DailyChallengeQuestion question) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: QuizTheme.cardDecoration(isDark: isDark),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                question.questionText,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ),
        if (widget.showGestureHint)
          Positioned(
            bottom: 10,
            child: Text(
              'swipe left · solution      swipe right · lanes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
              ),
            ),
          ),
        AnimatedOpacity(
          opacity: _showHeart ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: _showHeart ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.bookmark_rounded, color: QuizTheme.primary.withOpacity(0.85), size: 84),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOptions(
    BuildContext context,
    bool isDark,
    DailyChallengeQuestion question,
    FeedCardState card,
    bool resolved,
  ) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    final options = <Widget>[];
    for (var i = 0; i < question.options.length; i++) {
      final isSelected = card.selectedOption == i;
      final isCorrectOption = i == question.correctIndex;
      options.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionCard(
            option: question.options[i],
            label: labels[i % labels.length],
            isSelected: resolved ? (isSelected || isCorrectOption) : isSelected,
            isCorrect: resolved ? isCorrectOption : null,
            isDark: isDark,
            onTap: resolved ? null : () {
              HapticFeedback.selectionClick();
              widget.onSelectOption(i);
            },
          ),
        ),
      );
    }
    return options;
  }

  Widget _buildPeek(BuildContext context, bool isDark, DailyChallengeQuestion question, FeedCardState card) {
    final explanation = question.explanation.trim();
    if (explanation.isEmpty) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _showPeek ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (card.isCorrect ? QuizTheme.success : QuizTheme.error).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          explanation,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildWrongReasons(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kWrongAnswerReasons.map((reason) {
          final selected = _selectedReason == reason;
          return GestureDetector(
            onTap: _selectedReason == null
                ? () {
                    setState(() => _selectedReason = reason);
                    widget.onWrongReason(reason);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? QuizTheme.primary.withOpacity(0.12)
                    : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? QuizTheme.primary : Colors.transparent),
              ),
              child: Text(
                reason,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? QuizTheme.primary : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, Color mutedText, bool resolved) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.sessionAnswered == 0
                ? 'Answer to start your session accuracy'
                : 'Session · ${widget.sessionAccuracy.round()}% accuracy',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: mutedText),
          ),
        ),
        if (!resolved)
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onSkip();
            },
            child: Text(
              'Skip ›',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: QuizTheme.primary),
            ),
          ),
      ],
    );
  }
}
