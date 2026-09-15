import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../../shared/providers/providers.dart';
import 'success_screen.dart';
import '../../features/profile/screens/screens.dart';
import '../../features/l10n/app_localizations.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _orbController;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  late final Animation<double> _fadeContent;
  late final Animation<Offset> _slideContent;
  late final Animation<double> _fadeButtons;
  late final Animation<Offset> _slideButtons;

  bool _isPrivacyPolicyAccepted = false;
  bool _isGoogleLoading = false;
  bool _hasShowcaseBeenShown = false;

  final GlobalKey _checkboxKey = GlobalKey();

  static const _purple = Color(0xFF5B13EC);
  static const _blue = Color(0xFF2563EB);
  static const _cyan = Color(0xFF06B6D4);
  static const _pink = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeContent = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideContent = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _fadeButtons = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _slideButtons = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _orbController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _orbController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _showConsentRequiredMessage() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please accept the Privacy Policy to continue',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _triggerShowcase(BuildContext showcaseContext) {
    if (mounted) ShowCaseWidget.of(showcaseContext).startShowCase([_checkboxKey]);
  }

  Future<void> _handleGoogleSignIn(BuildContext showcaseContext) async {
    if (!_isPrivacyPolicyAccepted) {
      _showConsentRequiredMessage();
      _triggerShowcase(showcaseContext);
      return;
    }
    if (_isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(authProvider.notifier).googleSignIn();
      if (!mounted) return;

      if (ref.read(authProvider).value != null) {
        try {
          await ref.read(notificationProvider.notifier).sendTokenAfterLogin();
        } catch (e) {
          debugPrint('⚠️ Could not send FCM token: $e');
        }
        if (!mounted) return;

        ref.read(tabIndexProvider.notifier).state = 0;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              onComplete: () => context.go(AppRoutes.home),
              message: 'Signed In!',
              subtitle: 'Welcome back to ExamAI',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isAuthLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final isProcessing = isAuthLoading || _isGoogleLoading;

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_hasShowcaseBeenShown && !_isPrivacyPolicyAccepted) {
          _hasShowcaseBeenShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && showcaseContext.mounted) {
                _triggerShowcase(showcaseContext);
              }
            });
          });
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF080814) : const Color(0xFFF5F3FF),
          body: Stack(
            children: [
              // ── ANIMATED COLOR ORB BACKGROUND ───────────────────────────
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, _) {
                  final t = _orbController.value;
                  return Stack(
                    children: [
                      // Top-left: purple orb
                      Positioned(
                        left: -80 + sin(t * pi) * 40,
                        top: -60 + cos(t * pi) * 30,
                        child: _blurOrb(320, _purple, isDark ? 0.55 : 0.35),
                      ),
                      // Top-right: cyan orb
                      Positioned(
                        right: -60 + cos(t * pi) * 35,
                        top: size.height * 0.05 + sin(t * pi) * 25,
                        child: _blurOrb(260, _cyan, isDark ? 0.40 : 0.25),
                      ),
                      // Center-left: pink orb
                      Positioned(
                        left: -40 + sin(t * pi * 1.3) * 30,
                        top: size.height * 0.38 + cos(t * pi * 1.3) * 20,
                        child: _blurOrb(220, _pink, isDark ? 0.35 : 0.20),
                      ),
                      // Bottom-right: blue orb
                      Positioned(
                        right: -50 + cos(t * pi * 0.8) * 25,
                        bottom: size.height * 0.12 + sin(t * pi * 0.8) * 20,
                        child: _blurOrb(300, _blue, isDark ? 0.45 : 0.28),
                      ),
                      // Bottom-center: purple small
                      Positioned(
                        left: size.width * 0.3,
                        bottom: -40 + sin(t * pi * 1.5) * 20,
                        child: _blurOrb(180, _purple, isDark ? 0.30 : 0.18),
                      ),
                    ],
                  );
                },
              ),

              // ── FROSTED GLASS OVERLAY ────────────────────────────────────
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.45)
                      : Colors.white.withOpacity(0.30),
                ),
              ),

              // ── CONTENT ──────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // Language button
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, top: 8),
                        child: _buildLanguageButton(isDark),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),

                            // ── LOGO + HEADLINE ───────────────────────────
                            FadeTransition(
                              opacity: _fadeContent,
                              child: SlideTransition(
                                position: _slideContent,
                                child: Column(
                                  children: [
                                    // App icon badge
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [_purple, Color(0xFF9333EA)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _purple.withOpacity(0.5),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // App name
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [_purple, _cyan, _pink],
                                        stops: [0.0, 0.5, 1.0],
                                      ).createShader(bounds),
                                      child: Text(
                                        'ExamAI',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -1.5,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    Text(
                                      AppLocalizations.of(context)!.welcomeTitle,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.85)
                                            : const Color(0xFF1E1B4B),
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context)!.welcomeSubtitle,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

                            // ── FLOATING FEATURE CARDS ────────────────────
                            FadeTransition(
                              opacity: _fadeContent,
                              child: AnimatedBuilder(
                                animation: _floatAnimation,
                                builder: (context, _) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _featureChip(
                                        Icons.bolt_rounded,
                                        'Practice Feed',
                                        _blue,
                                        isDark,
                                        offset: _floatAnimation.value * 0.8,
                                      ),
                                      const SizedBox(width: 10),
                                      _featureChip(
                                        Icons.auto_awesome_rounded,
                                        'AI Topics',
                                        _purple,
                                        isDark,
                                        offset: -_floatAnimation.value * 0.6,
                                      ),
                                      const SizedBox(width: 10),
                                      _featureChip(
                                        Icons.menu_book_rounded,
                                        'Study Sets',
                                        _cyan,
                                        isDark,
                                        offset: _floatAnimation.value,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── EXAM BADGES ───────────────────────────────
                            FadeTransition(
                              opacity: _fadeContent,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: ['JEE', 'NEET', 'CAT', 'GRE', 'CUET', 'GMAT', 'IELTS']
                                    .map((exam) => _examBadge(exam, isDark))
                                    .toList(),
                              ),
                            ),

                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),

                    // ── BOTTOM SIGN-IN SECTION ────────────────────────────
                    FadeTransition(
                      opacity: _fadeButtons,
                      child: SlideTransition(
                        position: _slideButtons,
                        child: _buildBottomSection(isDark, isProcessing, showcaseContext),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blurOrb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label, Color color, bool isDark,
      {required double offset}) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _examBadge(String name, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _purple.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF4C1D95),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isDark, bool isProcessing, BuildContext showcaseContext) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.72),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.8),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Text(
                'Start your journey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Free to start. Pro for unlimited access.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Privacy checkbox
              _buildPrivacyCheckbox(isDark, showcaseContext),
              const SizedBox(height: 20),

              // Google sign-in button
              _GoogleSignInButton(
                isLoading: isProcessing,
                isDark: isDark,
                onTap: () => _handleGoogleSignIn(showcaseContext),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyCheckbox(bool isDark, BuildContext showcaseContext) {
    return Showcase(
      key: _checkboxKey,
      title: AppLocalizations.of(context)!.required,
      description: AppLocalizations.of(context)!.acceptPrivacy,
      targetBorderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isPrivacyPolicyAccepted = !_isPrivacyPolicyAccepted);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isPrivacyPolicyAccepted
                ? _purple.withOpacity(isDark ? 0.15 : 0.06)
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPrivacyPolicyAccepted
                  ? _purple.withOpacity(0.5)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _isPrivacyPolicyAccepted ? _purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _isPrivacyPolicyAccepted
                        ? _purple
                        : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                    width: 2,
                  ),
                ),
                child: _isPrivacyPolicyAccepted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context)
                      .push(_createRoute(const PrivacyPolicyScreen())),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: AppLocalizations.of(context)!.iAgreeToThe),
                        TextSpan(
                          text: AppLocalizations.of(context)!.privacyPolicy,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          ),
                        ),
                        TextSpan(text: AppLocalizations.of(context)!.and),
                        TextSpan(
                          text: AppLocalizations.of(context)!.terms,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(bool isDark) {
    final currentLang = ref.watch(settingsProvider.select((s) => s.language));
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.white60,
            ),
          ),
          child: IconButton(
            iconSize: 18,
            icon: Text(
              currentLang == 'English' ? 'EN' : 'HI',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              ),
            ),
            onPressed: () {
              final newLang = currentLang == 'English' ? 'Hindi' : 'English';
              ref.read(settingsProvider.notifier).setLanguage(newLang);
            },
          ),
        ),
      ),
    );
  }
}

// ── GOOGLE SIGN-IN BUTTON ──────────────────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.isDark
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF5B13EC), Color(0xFF9333EA)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: widget.isDark ? const Color(0xFF1A1A2E) : null,
            borderRadius: BorderRadius.circular(18),
            border: widget.isDark
                ? Border.all(color: Colors.white.withOpacity(0.12), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B13EC).withOpacity(widget.isDark ? 0.3 : 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.isDark ? Colors.white70 : Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google G logo
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset('assets/icon/google_icon.png'),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppLocalizations.of(context)!.continueWithGoogle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
