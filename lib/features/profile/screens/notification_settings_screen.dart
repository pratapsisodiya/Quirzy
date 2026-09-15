import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/smart_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _purple = Color(0xFF5B13EC);

  final _svc = SmartNotificationService();
  bool _loading = true;
  Map<String, bool> _prefs = {};
  int _studyHour = 20;
  int _studyMinute = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _svc.getChannelPrefs();
    final (h, m) = await _svc.getStudyTime();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _studyHour = h;
      _studyMinute = m;
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _prefs[key] = value);
    await _svc.setChannelPref(key, value);

    // Re-schedule study time when turned back on
    if (key == 'notif_study_time' && value) {
      await _svc.scheduleStudyTimeReminder(
          hour: _studyHour, minute: _studyMinute);
    }
  }

  Future<void> _pickStudyTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _studyHour, minute: _studyMinute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _purple,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _studyHour = picked.hour;
      _studyMinute = picked.minute;
      _prefs['notif_study_time'] = true;
    });
    await _svc.scheduleStudyTimeReminder(
        hour: picked.hour, minute: picked.minute);
  }

  String _fmt(int h, int m) {
    final suffix = h < 12 ? 'AM' : 'PM';
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub =
        isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _header(
                  'What other apps miss',
                  'Most apps send hourly spam. ExamAI sends only what matters.',
                  textMain,
                  textSub,
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                _section(
                  'Revision',
                  isDark,
                  surfaceColor,
                  textMain,
                  textSub,
                  [
                    _channelTile(
                      icon: Icons.style_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Revision Due Reminders',
                      subtitle:
                          'Tells you how many practice questions are due and estimated time',
                      prefKey: 'notif_srs',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                  ],
                ).animate(delay: 80.ms).fadeIn(),

                _section(
                  'Streak & Motivation',
                  isDark,
                  surfaceColor,
                  textMain,
                  textSub,
                  [
                    _channelTile(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Streak Protection',
                      subtitle:
                          'Alert at 9 PM if you haven\'t studied yet — saves your streak',
                      prefKey: 'notif_streak',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                    _channelTile(
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'Exam Countdown',
                      subtitle:
                          'Weekly tip with days left to your target exam',
                      prefKey: 'notif_exam_countdown',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                  ],
                ).animate(delay: 140.ms).fadeIn(),

                _section(
                  'Progress & Insights',
                  isDark,
                  surfaceColor,
                  textMain,
                  textSub,
                  [
                    _channelTile(
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: 'Weekly Digest',
                      subtitle:
                          'Sunday morning: questions practiced, streak',
                      prefKey: 'notif_weekly_digest',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                    _channelTile(
                      icon: Icons.wb_twilight_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Re-engagement',
                      subtitle: 'Gentle nudge after 48 hours of inactivity',
                      prefKey: 'notif_re_engage',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(),

                _section(
                  'Study Time Reminder',
                  isDark,
                  surfaceColor,
                  textMain,
                  textSub,
                  [
                    _channelTile(
                      icon: Icons.alarm_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: 'Daily Study Alarm',
                      subtitle: 'Fires every day at your chosen time',
                      prefKey: 'notif_study_time',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                    if (_prefs['notif_study_time'] == true)
                      _timePicker(
                          isDark, surfaceColor, textMain, textSub),
                  ],
                ).animate(delay: 260.ms).fadeIn(),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Notifications respect your schedule. No hourly spam, ever.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSub,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _header(
      String title, String subtitle, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _purple.withOpacity(0.12),
            const Color(0xFF06B6D4).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: _purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textMain)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: textSub, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textSub,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _channelTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String prefKey,
    required bool isDark,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    final enabled = _prefs[prefKey] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textMain)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: textSub, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: enabled,
            onChanged: (val) => _toggle(prefKey, val),
            activeColor: _purple,
            activeTrackColor: _purple.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _timePicker(bool isDark, Color surfaceColor, Color textMain,
      Color textSub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _purple.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: _purple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reminder at ${_fmt(_studyHour, _studyMinute)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textMain),
            ),
          ),
          GestureDetector(
            onTap: _pickStudyTime,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Change',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
