import '../../quiz/providers/daily_challenge_provider.dart';

/// The kind of lane a [FeedLane] represents — mirrors ScrollPrep's lane list
/// (Mixed, per-topic, weak topics, revision vault, bookmarks).
enum FeedLaneType { mixed, topic, weakTopics, revision, bookmarks }

/// One entry in the Lane Switcher (swipe-right / lane-chip tap).
class FeedLane {
  final FeedLaneType type;
  final String id;
  final String label;
  final int count;

  const FeedLane({
    required this.type,
    required this.id,
    required this.label,
    this.count = 0,
  });

  static const mixedDefault = FeedLane(
    type: FeedLaneType.mixed,
    id: 'mixed',
    label: 'Mixed',
  );

  FeedLane copyWith({int? count}) => FeedLane(
    type: type,
    id: id,
    label: label,
    count: count ?? this.count,
  );
}

/// Per-question state within the currently loaded lane: has it been
/// answered, skipped, or bookmarked.
class FeedCardState {
  final DailyChallengeQuestion question;
  final int? selectedOption;
  final bool skipped;
  final bool bookmarked;

  const FeedCardState({
    required this.question,
    this.selectedOption,
    this.skipped = false,
    this.bookmarked = false,
  });

  bool get isResolved => selectedOption != null || skipped;
  bool get isCorrect =>
      selectedOption != null && selectedOption == question.correctIndex;

  FeedCardState copyWith({
    int? selectedOption,
    bool? skipped,
    bool? bookmarked,
  }) {
    return FeedCardState(
      question: question,
      selectedOption: selectedOption ?? this.selectedOption,
      skipped: skipped ?? this.skipped,
      bookmarked: bookmarked ?? this.bookmarked,
    );
  }
}

/// State owned by [FeedController].
class FeedState {
  final FeedLane lane;
  final List<FeedCardState> cards;
  final bool loading;
  final String? error;
  final bool focusMode;
  final int sessionAnswered;
  final int sessionCorrect;
  final DateTime sessionStart;
  final bool breakNudgeShown;
  final bool pendingBreakNudge;
  final bool dailyTargetCelebrated;
  final bool pendingTargetBanner;
  final bool showHints;
  final int startIndex;

  FeedState({
    required this.lane,
    this.cards = const [],
    this.loading = true,
    this.error,
    this.focusMode = true,
    this.sessionAnswered = 0,
    this.sessionCorrect = 0,
    DateTime? sessionStart,
    this.breakNudgeShown = false,
    this.pendingBreakNudge = false,
    this.dailyTargetCelebrated = false,
    this.pendingTargetBanner = false,
    this.showHints = true,
    this.startIndex = 0,
  }) : sessionStart = sessionStart ?? DateTime.now();

  factory FeedState.initial() => FeedState(lane: FeedLane.mixedDefault);

  double get sessionAccuracy =>
      sessionAnswered == 0 ? 0 : (sessionCorrect / sessionAnswered) * 100;

  FeedState copyWith({
    FeedLane? lane,
    List<FeedCardState>? cards,
    bool? loading,
    String? error,
    bool? focusMode,
    int? sessionAnswered,
    int? sessionCorrect,
    bool? breakNudgeShown,
    bool? pendingBreakNudge,
    bool? dailyTargetCelebrated,
    bool? pendingTargetBanner,
    bool? showHints,
    int? startIndex,
  }) {
    return FeedState(
      lane: lane ?? this.lane,
      cards: cards ?? this.cards,
      loading: loading ?? this.loading,
      error: error,
      focusMode: focusMode ?? this.focusMode,
      sessionAnswered: sessionAnswered ?? this.sessionAnswered,
      sessionCorrect: sessionCorrect ?? this.sessionCorrect,
      sessionStart: sessionStart,
      breakNudgeShown: breakNudgeShown ?? this.breakNudgeShown,
      pendingBreakNudge: pendingBreakNudge ?? this.pendingBreakNudge,
      dailyTargetCelebrated:
          dailyTargetCelebrated ?? this.dailyTargetCelebrated,
      pendingTargetBanner: pendingTargetBanner ?? this.pendingTargetBanner,
      showHints: showHints ?? this.showHints,
      startIndex: startIndex ?? this.startIndex,
    );
  }
}
