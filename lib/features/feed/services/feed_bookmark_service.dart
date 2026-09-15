import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../quiz/providers/daily_challenge_provider.dart';

/// Manual "double-tap to save" bookmarks for the practice feed.
/// Stores full question snapshots so a bookmark survives the pool it
/// came from trimming/rotating.
class FeedBookmarkService {
  static const _key = 'feed_bookmarks';

  Future<List<DailyChallengeQuestion>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => DailyChallengeQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<DailyChallengeQuestion> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<DailyChallengeQuestion>> getBookmarks() => _load();

  Future<Set<String>> getBookmarkedIds() async =>
      (await _load()).map((e) => e.id).toSet();

  Future<int> getCount() async => (await _load()).length;

  Future<void> addBookmark(DailyChallengeQuestion question) async {
    final items = await _load();
    if (items.any((e) => e.id == question.id)) return;
    items.insert(0, question);
    await _save(items);
  }

  Future<void> removeBookmark(String questionId) async {
    final items = await _load();
    items.removeWhere((e) => e.id == questionId);
    await _save(items);
  }
}
