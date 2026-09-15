import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quirzy/shared/services/settings_service.dart';
import '../../../routes/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/app_review_service.dart';
import '../../../shared/providers/user_stats_provider.dart';
import '../../l10n/app_localizations.dart';

// ==========================================
// REDESIGNED PROFILE SCREEN
// Full Dark/Light Theme Support
// ==========================================

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _userName = 'Practice Champ';
  String _userEmail = 'user@quirzy.com';
  String? _photoUrl;
  bool _isLoading = true;

  // Static colors
  static const primaryColor = Color(0xFF5B13EC);
  static const primaryLight = Color(0xFFEFE9FD);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final name = await _storage.read(key: 'user_name');
      final email = await _storage.read(key: 'user_email');
      final photoUrl = await _storage.read(key: 'user_photo_url');

      if (!mounted) return;
      setState(() {
        _userName = name?.isNotEmpty == true ? name! : 'Practice Champ';
        _userEmail = email?.isNotEmpty == true ? email! : 'user@quirzy.com';
        _photoUrl = photoUrl;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settingsState = ref.watch(settingsProvider);
    // Only watch specific stats we need for better performance
    final userStatsAsync = ref.watch(userStatsProvider);

    final currentStreak = userStatsAsync.asData?.value.currentStreak ?? 0;
    final totalXP = userStatsAsync.asData?.value.totalXP ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF664C9A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(textMain)
                        .animate()
                        .fade(duration: 600.ms)
                        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),
                  ),
                  SliverToBoxAdapter(
                    child: _buildProfileCard(
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child:
                        _buildStatsCards(
                              currentStreak: currentStreak,
                              totalXP: totalXP,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                              textMain: textMain,
                              textSub: textSub,
                            )
                            .animate(delay: 200.ms)
                            .fade(duration: 600.ms)
                            .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
                  ),
                  SliverToBoxAdapter(
                    child: _buildPreferencesSection(
                      settingsState,
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildNotificationsSection(
                      settingsState,
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildDataSection(
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSupportSection(
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildLogoutButton(isDark)
                        .animate(delay: 600.ms)
                        .fade(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 130)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(Color textMain) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textMain,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // Avatar
          Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: _photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _photoUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'Q',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'Q',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              )
              .animate(delay: 100.ms)
              .scale(
                duration: 600.ms,
                curve: Curves.easeOutBack,
                begin: const Offset(0.5, 0.5),
              )
              .shimmer(delay: 800.ms, duration: 1200.ms, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            _userName.split(' ').first, // Show only first name
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textSub,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatsCards({
    required int currentStreak,
    required int totalXP,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'STREAK',
              value: '$currentStreak Days',
              isPrimary: true,
              isDark: isDark,
              surfaceColor: surfaceColor,
              textMain: textMain,
              textSub: textSub,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.bolt_rounded,
              label: 'TOTAL XP',
              value: '$totalXP',
              isPrimary: false,
              isDark: isDark,
              surfaceColor: surfaceColor,
              textMain: textMain,
              textSub: textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isPrimary,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary
            ? (isDark
                  ? primaryColor.withOpacity(0.15)
                  : primaryLight.withOpacity(0.5))
            : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: isPrimary
            ? Border.all(color: primaryColor.withOpacity(isDark ? 0.3 : 0.1))
            : (isDark ? Border.all(color: const Color(0xFF2D2540)) : null),
        boxShadow: isPrimary || isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isPrimary ? primaryColor : textSub),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textSub,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isPrimary
                  ? (isDark ? Colors.white : primaryColor)
                  : textMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(
    SettingsService settingsState,
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return _buildSection(
      title: 'Preferences',
      textMain: textMain,
      children: [
        _buildSwitchTile(
          icon: Icons.dark_mode_rounded,
          title: 'Dark Mode',
          subtitle: 'Easier on the eyes',
          value: isDark,
          iconColor: const Color(0xFF6366F1),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onChanged: (val) =>
              ref.read(settingsProvider.notifier).toggleDarkMode(val),
        ),

        _buildLanguageDropdownTile(
          icon: Icons.language_rounded,
          title: AppLocalizations.of(context)!.commonLanguage,
          subtitle: settingsState.language,
          value: settingsState.language,
          items: const ['English', 'Hindi'],
          iconColor: const Color(0xFF10B981),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onChanged: (String? newValue) {
            if (newValue != null) {
              ref.read(settingsProvider.notifier).setLanguage(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(
    SettingsService settingsState,
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return _buildSection(
      title: 'Notifications',
      textMain: textMain,
      children: [
        _buildSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: 'Push Notifications',
          subtitle: 'Daily reminders & updates',
          value: settingsState.notificationsEnabled,
          iconColor: const Color(0xFFF59E0B),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onChanged: (val) =>
              ref.read(settingsProvider.notifier).toggleNotifications(val),
        ),
        _buildSwitchTile(
          icon: Icons.volume_up_rounded,
          title: 'Sound Effects',
          subtitle: 'Play sounds during practice',
          value: settingsState.soundEnabled,
          iconColor: const Color(0xFFEC4899),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onChanged: (val) =>
              ref.read(settingsProvider.notifier).toggleSound(val),
        ),
        _buildSettingTile(
          icon: Icons.tune_rounded,
          title: 'Notification Settings',
          subtitle: 'SRS reminders, streak alerts, exam countdown & more',
          iconColor: const Color(0xFF5B13EC),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () => context.push(AppRoutes.notificationSettings),
        ),
      ],
    );
  }

  Widget _buildDataSection(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return _buildSection(
      title: 'Data & Privacy',
      textMain: textMain,
      children: [
        _buildSettingTile(
          icon: Icons.download_rounded,
          title: 'Download My Data',
          subtitle: 'Export history as JSON',
          iconColor: const Color(0xFF3B82F6),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () {},
        ),
        _buildSettingTile(
          icon: Icons.delete_forever_rounded,
          title: 'Clear History',
          subtitle: 'Remove all practice records',
          iconColor: const Color(0xFFEF4444),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () => _showClearHistoryDialog(),
        ),
      ],
    );
  }

  Widget _buildSupportSection(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return _buildSection(
      title: 'Support',
      textMain: textMain,
      children: [
        _buildSettingTile(
          icon: Icons.info_outline_rounded,
          title: 'Quirzy Version',
          subtitle: '2.1.0',
          iconColor: primaryColor,
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () {},
        ),
        _buildSettingTile(
          icon: Icons.key_rounded,
          title: 'API Key Settings',
          subtitle: 'Use your own Gemini API key',
          iconColor: const Color(0xFF8B5CF6),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () => context.push(AppRoutes.apiKeySettings),
        ),
        _buildSettingTile(
          icon: Icons.star_outline_rounded,
          title: 'Rate App',
          subtitle: 'Enjoying Quirzy? Rate us on Play Store',
          iconColor: const Color(0xFFF59E0B),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () async {
            try {
              // Show custom review dialog
              await AppReviewService.showReviewDialog(context);
            } catch (e) {
              // Fallback to direct store opening
              try {
                final success = await AppReviewService().openStoreListing();
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open Play Store'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e2) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e2'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
        _buildSettingTile(
          icon: Icons.help_outline_rounded,
          title: 'Help & Feedback',
          subtitle: 'Get support or send feedback',
          iconColor: const Color(0xFF10B981),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textMain: textMain,
          textSub: textSub,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required Color textMain,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: children
                .animate(interval: 50.ms)
                .fade(duration: 400.ms)
                .slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: const Color(0xFF2D2540)) : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? iconColor.withOpacity(0.2)
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSub,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSub.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color iconColor,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF2D2540)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? iconColor.withOpacity(0.2)
                  : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
            // Native black/green styling instead of purple
            activeColor: isDark ? Colors.white : Colors.black,
            activeTrackColor: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Color iconColor,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF2D2540)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? iconColor.withOpacity(0.2)
                  : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: Icon(Icons.arrow_drop_down, color: textSub),
                dropdownColor: surfaceColor,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
                onChanged: onChanged,
                items: items.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        color: textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(isDark ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1730) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF120D1B),
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF664C9A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFF664C9A),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Store navigator reference before async operation
              final navigator = Navigator.of(context);
              final router = GoRouter.of(context);

              navigator.pop(); // Close dialog
              await ref.read(authProvider.notifier).logout();

              // Use stored router reference (safe even after widget disposal)
              router.go(AppRoutes.auth);
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1730) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear History?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF120D1B),
          ),
        ),
        content: Text(
          'This will permanently delete all your practice history. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF664C9A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFF664C9A),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'History cleared',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text(
              'Clear',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
