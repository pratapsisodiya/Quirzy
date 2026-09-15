import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/providers/home_stats_provider.dart';
import '../models/feed_models.dart';
import '../services/feed_bookmark_service.dart';
import '../services/feed_revision_service.dart';
import '../services/feed_stats_service.dart';
import '../services/practice_content_service.dart';
import '../services/xp_service.dart';

const int kFeedDailyTarget = 50;
const int kFeedBreakNudgeMinutes = 25;

final feedStatsServiceProvider = Provider<FeedStatsService>((ref) => FeedStatsService());
final feedBookmarkServiceProvider = Provider<FeedBookmarkService>((ref) => FeedBookmarkService());
final feedRevisionServiceProvider = Provider<FeedRevisionService>((ref) => FeedRevisionService());

/// The full local question pool the feed draws from — see
/// PracticeContentService.
final feedQuestionPoolProvider = FutureProvider<List<PracticeQuestion>>((ref) async {
  final service = ref.watch(practiceContentServiceProvider);
  return service.getQuestionPool();
});

/// Lanes available in the Lane Switcher, derived from per-topic storage +
/// local stats/bookmarks/revision state.
final feedLanesProvider = FutureProvider<List<FeedLane>>((ref) async {
  final contentService = ref.watch(practiceContentServiceProvider);
  final stats = ref.watch(feedStatsServiceProvider);
  final bookmarks = ref.watch(feedBookmarkServiceProvider);
  final revision = ref.watch(feedRevisionServiceProvider);

  final topicSummaries = await contentService.getTopicSummaries();
  final muted = await stats.getMutedTopics();

  final topicLanes = topicSummaries
      .where((t) => t.count > 0 && !muted.contains(t.topic))
      .map((t) => FeedLane(
            type: FeedLaneType.topic,
            id: 'topic:${t.topic}',
            label: t.topic,
            count: t.count,
            downloaded: t.downloaded,
          ))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final mixedCount = topicLanes.fold<int>(0, (sum, lane) => sum + lane.count);

  final weakTopics = await stats.getWeakTopics();
  final dueCount = await revision.getDueCount();
  final bookmarkCount = await bookmarks.getCount();

  return [
    FeedLane(type: FeedLaneType.mixed, id: 'mixed', label: 'Mixed', count: mixedCount),
    if (dueCount > 0)
      FeedLane(type: FeedLaneType.revision, id: 'revision', label: 'Revision Vault', count: dueCount),
    if (weakTopics.isNotEmpty)
      FeedLane(type: FeedLaneType.weakTopics, id: 'weak', label: 'My Weak Topics', count: weakTopics.length),
    if (bookmarkCount > 0)
      FeedLane(type: FeedLaneType.bookmarks, id: 'bookmarks', label: 'Bookmarks', count: bookmarkCount),
    ...topicLanes,
  ];
});

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(FeedController.new);

/// Drives the practice feed: lane composition, per-question answer/skip/
/// bookmark state, Focus Mode, session stats, and the local moderation +
/// spaced-repetition side effects that go with each answer.
class FeedController extends Notifier<FeedState> {
  List<PracticeQuestion> _fullPool = [];

  @override
  FeedState build() {
    Future.microtask(_init);
    return FeedState.initial();
  }

  Future<void> _init() async {
    try {
      _fullPool = await ref.read(feedQuestionPoolProvider.future);

      final prefs = await SharedPreferences.getInstance();
      final focusMode = prefs.getBool('feed_focus_mode') ?? true;
      final showHints = !(prefs.getBool('feed_hint_dismissed') ?? false);

      final laneId = prefs.getString('feed_last_lane_id') ?? 'mixed';
      final laneLabel = prefs.getString('feed_last_lane_label') ?? 'Mixed';
      final laneTypeName = prefs.getString('feed_last_lane_type') ?? FeedLaneType.mixed.name;
      final laneType = FeedLaneType.values.firstWhere(
        (t) => t.name == laneTypeName,
        orElse: () => FeedLaneType.mixed,
      );

      state = state.copyWith(focusMode: focusMode, showHints: showHints);
      await switchLane(
        FeedLane(type: laneType, id: laneId, label: laneLabel),
        restorePosition: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<List<PracticeQuestion>> _questionsForLane(FeedLane lane) async {
    final stats = ref.read(feedStatsServiceProvider);
    final muted = await stats.getMutedTopics();
    final reported = await stats.getReportedQuestions();
    final deprioritized = await stats.getDeprioritizedQuestions();

    List<PracticeQuestion> base = _fullPool.where((q) {
      if (reported.contains(q.id)) return false;
      final topic = q.topic;
      if (topic != null && muted.contains(topic)) return false;
      return true;
    }).toList();

    switch (lane.type) {
      case FeedLaneType.mixed:
        final list = base.where((q) => !deprioritized.contains(q.id)).toList();
        list.shuffle();
        return list;
      case FeedLaneType.topic:
        final list = base
            .where((q) => ((q.topic == null || q.topic!.trim().isEmpty) ? 'General' : q.topic!) == lane.label)
            .toList();
        list.shuffle();
        return list;
      case FeedLaneType.weakTopics:
        final weak = await stats.getWeakTopics();
        final list = base
            .where((q) => weak.contains((q.topic == null || q.topic!.trim().isEmpty) ? 'General' : q.topic!))
            .toList();
        list.shuffle();
        return list;
      case FeedLaneType.revision:
        final revision = ref.read(feedRevisionServiceProvider);
        return revision.getDueQuestions();
      case FeedLaneType.bookmarks:
        final bookmarks = ref.read(feedBookmarkServiceProvider);
        return bookmarks.getBookmarks();
    }
  }

  Future<void> switchLane(FeedLane lane, {bool restorePosition = false}) async {
    state = state.copyWith(loading: true, lane: lane);

    final questions = await _questionsForLane(lane);
    final bookmarkedIds = await ref.read(feedBookmarkServiceProvider).getBookmarkedIds();
    final cards = questions
        .map((q) => FeedCardState(question: q, bookmarked: bookmarkedIds.contains(q.id)))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    var startIndex = 0;
    if (restorePosition) {
      final ts = prefs.getInt('feed_lane_ts_${lane.id}');
      if (ts != null && DateTime.now().millisecondsSinceEpoch - ts < const Duration(hours: 24).inMilliseconds) {
        final saved = prefs.getInt('feed_lane_pos_${lane.id}') ?? 0;
        startIndex = cards.isEmpty ? 0 : saved.clamp(0, cards.length - 1);
      }
    }

    await prefs.setString('feed_last_lane_id', lane.id);
    await prefs.setString('feed_last_lane_label', lane.label);
    await prefs.setString('feed_last_lane_type', lane.type.name);

    state = state.copyWith(lane: lane, cards: cards, loading: false, startIndex: startIndex);
  }

  Future<void> reshuffleCurrentLane() => switchLane(state.lane);

  /// Refreshes the pool from storage (picking up questions just added
  /// elsewhere, e.g. a freshly generated/added topic) and switches straight
  /// to a lane for [topic].
  Future<void> switchToTopic(String topic) async {
    _fullPool = await ref.refresh(feedQuestionPoolProvider.future);
    ref.invalidate(feedLanesProvider);
    await switchLane(FeedLane(type: FeedLaneType.topic, id: 'topic:$topic', label: topic));
  }

  Future<void> savePosition(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feed_lane_pos_${state.lane.id}', index);
    await prefs.setInt('feed_lane_ts_${state.lane.id}', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setFocusMode(bool value) async {
    state = state.copyWith(focusMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feed_focus_mode', value);
  }

  Future<void> dismissHints() async {
    if (!state.showHints) return;
    state = state.copyWith(showHints: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feed_hint_dismissed', true);
  }

  Future<void> selectOption(int index, int optionIndex) async {
    if (index < 0 || index >= state.cards.length) return;
    final card = state.cards[index];
    if (card.isResolved) return;

    final correct = optionIndex == card.question.correctIndex;
    final cards = List<FeedCardState>.from(state.cards);
    cards[index] = card.copyWith(selectedOption: optionIndex);
    state = state.copyWith(
      cards: cards,
      sessionAnswered: state.sessionAnswered + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );

    await ref.read(feedStatsServiceProvider).recordAttempt(card.question.topic, correct);
    await ref.read(feedRevisionServiceProvider).recordOutcome(card.question, correct);

    if (correct) {
      await ref.read(xpServiceProvider).addXPToday(10);
      ref.invalidate(homeStatsProvider);
    }

    await _afterAttempt();
  }

  Future<void> skipCurrent(int index) async {
    if (index < 0 || index >= state.cards.length) return;
    final card = state.cards[index];
    if (card.isResolved) return;

    final cards = List<FeedCardState>.from(state.cards);
    cards[index] = card.copyWith(skipped: true);
    state = state.copyWith(cards: cards, sessionAnswered: state.sessionAnswered + 1);

    await _afterAttempt();
  }

  Future<void> _afterAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final key = 'feed_answered_count_$today';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);

    if (count >= kFeedDailyTarget && !state.dailyTargetCelebrated) {
      state = state.copyWith(dailyTargetCelebrated: true, pendingTargetBanner: true);
    }

    final elapsedMinutes = DateTime.now().difference(state.sessionStart).inMinutes;
    if (elapsedMinutes >= kFeedBreakNudgeMinutes && !state.breakNudgeShown) {
      state = state.copyWith(breakNudgeShown: true, pendingBreakNudge: true);
    }
  }

  void acknowledgeBreakNudge() {
    state = state.copyWith(pendingBreakNudge: false);
  }

  void acknowledgeTargetBanner() {
    state = state.copyWith(pendingTargetBanner: false);
  }

  Future<void> toggleBookmark(int index) async {
    if (index < 0 || index >= state.cards.length) return;
    final card = state.cards[index];
    final newValue = !card.bookmarked;

    final cards = List<FeedCardState>.from(state.cards);
    cards[index] = card.copyWith(bookmarked: newValue);
    state = state.copyWith(cards: cards);

    final bookmarks = ref.read(feedBookmarkServiceProvider);
    if (newValue) {
      await bookmarks.addBookmark(card.question);
    } else {
      await bookmarks.removeBookmark(card.question.id);
    }
    ref.invalidate(feedLanesProvider);
  }

  Future<void> muteTopic(String topic) async {
    await ref.read(feedStatsServiceProvider).muteTopic(topic);
    ref.invalidate(feedLanesProvider);
  }

  Future<void> reportQuestion(String questionId) async {
    await ref.read(feedStatsServiceProvider).reportQuestion(questionId);
    ref.invalidate(feedLanesProvider);
  }

  Future<void> markTooEasy(PracticeQuestion question) async {
    await ref.read(feedStatsServiceProvider).deprioritizeQuestion(question.id);
  }

  Future<void> markTooHard(PracticeQuestion question) async {
    // Surfaces the question again soon, same as a wrong answer would.
    await ref.read(feedRevisionServiceProvider).recordOutcome(question, false);
  }

  Future<void> recordWrongReason(String reason) async {
    await ref.read(feedStatsServiceProvider).recordWrongReason(reason);
  }

  List<PracticeQuestion> similarTo(PracticeQuestion question, {int limit = 3}) {
    final topic = question.topic;
    if (topic == null || topic.trim().isEmpty) return const [];
    return _fullPool
        .where((q) => q.id != question.id && q.topic == topic)
        .take(limit)
        .toList();
  }

  /// Inserts [question] right after [afterIndex] (or jumps to it if it's
  /// already in the lane) — used when tapping a "Similar" question in the
  /// Deep Dive drawer. Returns the index to scroll to.
  int insertNext(int afterIndex, PracticeQuestion question) {
    final cards = List<FeedCardState>.from(state.cards);
    final existing = cards.indexWhere((c) => c.question.id == question.id);
    if (existing != -1) return existing;

    final insertAt = (afterIndex + 1).clamp(0, cards.length);
    cards.insert(insertAt, FeedCardState(question: question));
    state = state.copyWith(cards: cards);
    return insertAt;
  }
}
