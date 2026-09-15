import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../shared/appwrite/leaderboard/leaderboard_service.dart';
import '../../../config/theme_config.dart';

/// Leaderboard Screen - Global rankings and competition
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final _leaderboardService = LeaderboardService();
  final _storage = const FlutterSecureStorage();
  
  List<Map<String, dynamic>> _topPlayers = [];
  Map<String, dynamic> _userRank = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final topPlayers = await _leaderboardService.getTopPlayers(limit: 50);
      final userId = await _storage.read(key: 'user_id') ?? '';
      final userRank = userId.isNotEmpty
          ? await _leaderboardService.getUserRank(userId: userId)
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _topPlayers = topPlayers;
          _userRank = Map<String, dynamic>.from(userRank);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? ThemeConfig.backgroundDark : ThemeConfig.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Leaderboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: isDark ? ThemeConfig.textPrimaryDark : ThemeConfig.textPrimaryLight,
          ),
        ),
        backgroundColor: isDark ? ThemeConfig.backgroundDark : ThemeConfig.backgroundLight,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.public), text: 'Global'),
            Tab(icon: Icon(Icons.people), text: 'Friends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGlobalLeaderboard(isDark),
                _buildFriendsLeaderboard(isDark),
              ],
            ),
    );
  }

  Widget _buildGlobalLeaderboard(bool isDark) {
    if (_topPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No rankings yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? ThemeConfig.textPrimaryDark : ThemeConfig.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start practicing to climb the leaderboard!',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? ThemeConfig.textSecondaryDark : ThemeConfig.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topPlayers.length + (_userRank.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show user's rank at the bottom if not in top list
        if (index == _topPlayers.length) {
          final position = _userRank['position'] as int? ?? -1;
          if (position > _topPlayers.length) {
            return _buildPlayerCard(
              position: position,
              userName: 'You',
              totalXP: _userRank['totalXP'] as int? ?? 0,
              rank: _userRank['rank'] as String? ?? 'Unranked',
              isCurrentUser: true,
              isDark: isDark,
            );
          }
          return const SizedBox.shrink();
        }

        final player = _topPlayers[index];
        return _buildPlayerCard(
          position: index + 1,
          userName: player['userName'] ?? 'Unknown',
          totalXP: player['totalXP'] as int? ?? 0,
          rank: player['rank'] as String? ?? 'Unranked',
          isCurrentUser: false,
          isDark: isDark,
        ).animate(delay: (index * 50).ms).fadeIn().slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildFriendsLeaderboard(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Friends Coming Soon!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? ThemeConfig.textPrimaryDark : ThemeConfig.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add friends to compete with them!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? ThemeConfig.textSecondaryDark : ThemeConfig.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required int position,
    required String userName,
    required int totalXP,
    required String rank,
    required bool isCurrentUser,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? ThemeConfig.primaryColor.withOpacity(0.1)
            : isDark
                ? ThemeConfig.surfaceDark
                : ThemeConfig.surfaceLight,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusLarge),
        border: isCurrentUser
            ? Border.all(color: ThemeConfig.primaryColor, width: 2)
            : isDark
                ? Border.all(color: Colors.white10)
                : null,
      ),
      child: Row(
        children: [
          // Rank Number
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: position <= 3
                  ? [
                      const Color(0xFFFFD700), // Gold
                      const Color(0xFFC0C0C0), // Silver
                      const Color(0xFFCD7F32), // Bronze
                    ][position - 1]
                  : isDark
                      ? Colors.white10
                      : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Text(
              '$position',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: position <= 3 ? Colors.white : ThemeConfig.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? ThemeConfig.textPrimaryDark : ThemeConfig.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rank,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? ThemeConfig.textSecondaryDark : ThemeConfig.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // XP
          Text(
            '$totalXP XP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
