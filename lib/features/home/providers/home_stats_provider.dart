import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../feed/services/xp_service.dart';
import '../../content/providers/content_providers.dart';

class HomeStats {
  final int streak;
  final int xpToday;
  final int quizzesToday;

  const HomeStats({this.streak = 0, this.xpToday = 0, this.quizzesToday = 0});
}

final homeStatsProvider = FutureProvider<HomeStats>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final xpService = ref.read(xpServiceProvider);
  final generationLimitService = ref.read(generationLimitServiceProvider);

  final streak = prefs.getInt('daily_streak') ?? 0;
  final quizzesToday = await generationLimitService.getTodayCount();
  final xpToday = await xpService.getXPToday();

  return HomeStats(
    streak: streak,
    xpToday: xpToday,
    quizzesToday: quizzesToday,
  );
});
