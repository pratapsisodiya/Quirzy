import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../l10n/app_localizations.dart';
import '../../home/widgets/home_widgets.dart' show AdService, QuizGenerationLoadingScreen;
import '../providers/flashcard_providers.dart';
import '../widgets/flashcard_widgets.dart';
import '../../../shared/providers/exam_provider.dart';
import '../../onboarding/screens/screens.dart';
import '../services/srs_service.dart';
import 'srs_review_screen.dart';

// ==========================================
// REDESIGNED FLASHCARDS SCREEN
// Full Dark/Light Theme Support
// ==========================================

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _topicController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _flashcardSets = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  int _selectedTab = 0;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _userName = 'Practice Champ';
  String? _photoUrl;

  // Static colors
  static const primaryColor = Color(0xFF5B13EC);
  static const primaryLight = Color(0xFFEFE9FD);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    // FlashcardCacheService.init() is optional - Hive handles this via main.dart
    await _loadFlashcardSets();
  }

  Future<void> _loadUserData() async {
    final name = await _storage.read(key: 'user_name');
    final photoUrl = await _storage.read(key: 'user_photo_url');
    if (mounted) {
      setState(() {
        if (name != null) _userName = name;
        _photoUrl = photoUrl;
      });
    }
  }

  Future<void> _loadFlashcardSets({bool forceRefresh = false}) async {
    try {
      final flashcardService = ref.read(flashcardServiceProvider);
      final sets = await flashcardService.getMyFlashcardSets();
      if (!mounted) return;
      setState(() {
        _flashcardSets = sets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateFlashcards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter a topic', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    _focusNode.unfocus();

    // Check daily limit (53 free flashcards per day)
    final adService = AdService();
    if (!adService.isFlashcardLimitReached()) {
      // Still have free flashcards
      adService.incrementFlashcardCount();
      _startFlashcardGeneration(topic);
    } else {
      // Limit reached - show ad
      adService.showRewardedAd(
        onRewardEarned: () {
          if (mounted) {
            _startFlashcardGeneration(topic);
          }
        },
        onAdFailed: () {
          // Fallback: Proceed even if ad fails
          if (mounted) {
            _startFlashcardGeneration(topic);
          }
        },
      );
    }
  }

  Future<void> _startFlashcardGeneration(String topic) async {
    // Show AI Generation Loading Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuizGenerationLoadingScreen(
          title: 'Creating Flashcards...',
          subtitle: 'AI is distilling key concepts\ninto bite-sized cards.',
        ),
      ),
    );

    try {
      final flashcardService = ref.read(flashcardServiceProvider);
      final result = await flashcardService.generateFlashcards(
        topic: topic,
        cardCount: 10,
      );

      if (!mounted) return;

      // Pop loading screen
      Navigator.pop(context);

      _topicController.clear();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FlashcardStudyScreen(
                setId: result['id'],
                title: result['title'] ?? topic,
                cards: List<Map<String, dynamic>>.from(result['cards'] ?? []),
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ).then((_) => _loadFlashcardSets());
    } catch (e) {
      if (!mounted) return;
      // Pop loading screen on error
      Navigator.pop(context);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  void _openFlashcardSet(Map<String, dynamic> set) async {
    HapticFeedback.lightImpact();
    if (!mounted) return;

    if (set['isPremium'] == true) {
      _showPremiumDialog(set['title'] as String);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    try {
      final flashcardService = ref.read(flashcardServiceProvider);
      final fullSet = await flashcardService.getFlashcardSetById(set['id'] as String);
      if (!mounted) return;
      Navigator.pop(context);

      final cards = List<Map<String, dynamic>>.from(fullSet['cards'] ?? []);
      final setId = fullSet['id'] as String;
      final title = fullSet['title'] as String;

      // Get SRS stats for this set
      final srs = SrsService();
      final stats = await srs.getSetStats(setId, cards.length);
      final dueCount = stats['due'] ?? 0;

      if (!mounted) return;
      _showStudyModeSheet(
        setId: setId,
        title: title,
        cards: cards,
        dueCount: dueCount,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Failed to load flashcards', isError: true);
    }
  }

  void _showStudyModeSheet({
    required String setId,
    required String title,
    required List<Map<String, dynamic>> cards,
    required int dueCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Study All
            _modeCard(
              icon: Icons.style_rounded,
              color: primaryColor,
              title: 'Study All',
              subtitle: '${cards.length} cards — free review, no schedule',
              isDark: isDark,
              textMain: textMain,
              textSub: textSub,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardStudyScreen(
                      setId: setId,
                      title: title,
                      cards: cards,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Spaced Repetition
            _modeCard(
              icon: Icons.repeat_rounded,
              color: const Color(0xFF10B981),
              title: 'Spaced Review',
              subtitle: dueCount > 0
                  ? '$dueCount card${dueCount != 1 ? 's' : ''} due today — SRS algorithm'
                  : 'All caught up! No cards due today',
              badge: dueCount > 0 ? '$dueCount due' : null,
              badgeColor: const Color(0xFFEF4444),
              isDark: isDark,
              textMain: textMain,
              textSub: textSub,
              onTap: dueCount > 0
                  ? () async {
                      Navigator.pop(context);
                      final srs = SrsService();
                      final dueIndices =
                          await srs.getDueIndices(setId, cards.length);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SrsReviewScreen(
                            setId: setId,
                            title: title,
                            cards: cards,
                            dueIndices: dueIndices,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color textMain,
    required Color textSub,
    required VoidCallback? onTap,
    String? badge,
    Color? badgeColor,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
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
                        fontWeight: FontWeight.bold,
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
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF171717) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF664C9A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadFlashcardSets(forceRefresh: true),
          child:
              CustomScrollView(
                    slivers: [
                      // App Bar
                      SliverToBoxAdapter(
                        child: _buildAppBar(
                          isDark,
                          surfaceColor,
                          textMain,
                          textSub,
                        ),
                      ),

                      // Hero Section
                      SliverToBoxAdapter(
                        child: _buildHeroSection(textMain, textSub, isDark),
                      ),

                      // Create Section (Input)
                      SliverToBoxAdapter(
                        child: _buildCreateSection(
                          isDark,
                          surfaceColor,
                          textMain,
                          textSub,
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildGenerateButton()),

                      // Categories Section - Premium Redesign
                      SliverToBoxAdapter(
                        child: _buildCategoriesSection(
                          isDark,
                          textMain,
                          textSub,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // Stats Cards
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _buildStatsCards(
                            isDark,
                            surfaceColor,
                            textMain,
                            textSub,
                          ),
                        ),
                      ),

                      // Collection Header with Custom Tabs
                      SliverToBoxAdapter(
                        child: _buildTabBar(isDark, surfaceColor, textSub),
                      ),

                      // The List (conditionally filtered)
                      _buildFlashcardsList(
                        isDark,
                        surfaceColor,
                        textMain,
                        textSub,
                      ),

                      // Bottom Padding
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 100),
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark, Color surfaceColor, Color textSub) {
    final tabs = ['Recommended', 'My Library', 'Recent'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFF3F4F6),
        ),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final isSelected = _selectedTab == entry.key;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : textSub,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFlashcardsList(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: ShimmerPlaceholders.historyList(itemCount: 3),
        ),
      );
    }

    // Filter Logic
    // Filter Logic
    List<Map<String, dynamic>> filteredSets = [];
    final selectedExam = ref.watch(examProvider);

    if (_selectedTab == 0) {
      // Recommended / Exam Specific
      if (selectedExam == null) {
        // Show prompts to select exam
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExamSelectionScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Select Your Goal',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose an exam to get tailored flashcards.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        // Return categorized content
        final sections = _getExamData(selectedExam);
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final subject = sections.keys.elementAt(index);
            final sets = sections[subject]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        subject,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                ),
                ...sets.map(
                  (set) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildFlashcardSetCard(
                      set,
                      isDark,
                      surfaceColor,
                      textMain,
                      textSub,
                    ),
                  ),
                ),
              ],
            );
          }, childCount: sections.length),
        );
      }
    } else {
      filteredSets = List.from(_flashcardSets);
      if (_selectedTab == 2) {
        // Recent (Tab index 2 in new list: Rec, MyLib, Fav? No. Tabs: Rec, My, Fav?)
        // Tabs: ['Recommended', 'My Library', 'Recent'] -> Indices: 0, 1, 2.
        // Wait, 'Recent' is index 2.
        filteredSets = filteredSets.take(5).toList();
      } else if (_selectedTab == 1) {
        // My Library (All user sets)
        // No filter needed.
      }
    }

    if (filteredSets.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(textMain, textSub),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return _buildFlashcardSetCard(
                filteredSets[index],
                isDark,
                surfaceColor,
                textMain,
                textSub,
              )
              .animate(delay: (400 + (index * 80)).ms)
              .fade(duration: 400.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
        }, childCount: filteredSets.length),
      ),
    );
  }

  Widget _buildFlashcardSetCard(
    Map<String, dynamic> set,
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    final title = set['title'] ?? 'Untitled Set';
    final cardCount = set['cardCount'] ?? set['cards']?.length ?? 0;
    final isFavorite = set['isFavorite'] == true;

    return GestureDetector(
      onTap: () => _openFlashcardSet(set),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? Border.all(color: Colors.white10) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Wave background pattern (subtle)
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.style,
                  size: 100,
                  color: primaryColor.withOpacity(0.05),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$cardCount Cards',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Favorite Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            // Logic to toggle favorite would go here
                            _showSnackBar('Added to favorites', isError: false);
                          },
                          child: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFavorite
                                ? Colors.orange
                                : textSub.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Tap to study',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSub,
                          ),
                        ),
                        const Spacer(),
                        FutureBuilder<Map<String, int>>(
                          future: () async {
                            final id = set['id'] as String?;
                            final count = (set['cardCount'] ?? 0) as int;
                            if (id == null || count == 0) return <String, int>{};
                            return SrsService().getSetStats(id, count);
                          }(),
                          builder: (context, snap) {
                            final due = snap.data?['due'] ?? 0;
                            if (due == 0) {
                              return const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey);
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$due due',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textMain, Color textSub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.style_rounded,
              size: 64,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Flashcards',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create your first set above to get started!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: textSub,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [primaryColor, Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _photoUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'Q',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.flashcardsTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.yourCollection,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSub,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Color textMain, Color textSub, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: AppLocalizations.of(context)!.studySmarter1),
                    TextSpan(
                      text: AppLocalizations.of(context)!.studySmarter2,
                      style: TextStyle(
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fade(duration: 700.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.studySmarterSubtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSection(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.whatsTheTopic,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            focusNode: _focusNode,
            maxLines: 2,
            minLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: textMain,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? surfaceColor : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              hintText: "e.g., 'Photosynthesis' or paste your notes here...",
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: textSub.withOpacity(0.6),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child:
          GestureDetector(
                onTap: _isGenerating ? null : _generateFlashcards,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGenerating)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      else ...[
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generate Flashcards',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.02,
                duration: 1000.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(delay: 500.ms, duration: 2000.ms, color: Colors.white12),
    );
  }

  Widget _buildCategoriesSection(bool isDark, Color textMain, Color textSub) {
    final categories = [
      {
        'title': 'Science',
        'subtitle': 'Biology, Physics, Chemistry',
        'icon': Icons.science_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
        'count': '150+ Cards',
      },
      {
        'title': 'Languages',
        'subtitle': 'Vocabulary & Grammar',
        'icon': Icons.translate_rounded,
        'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        'count': '200+ Cards',
      },
      {
        'title': 'Mathematics',
        'subtitle': 'Formulas & Theorems',
        'icon': Icons.functions_rounded,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        'count': '120+ Cards',
      },
      {
        'title': 'History',
        'subtitle': 'Dates & Events',
        'icon': Icons.history_edu_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        'count': '180+ Cards',
      },
      {
        'title': 'Coding',
        'subtitle': 'Syntax & Algorithms',
        'icon': Icons.code_rounded,
        'gradient': [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
        'count': '250+ Cards',
      },
      {
        'title': 'Aptitude',
        'subtitle': 'Logic & Reasoning',
        'icon': Icons.psychology_rounded,
        'gradient': [const Color(0xFFEC4899), const Color(0xFFDB2777)],
        'count': '100+ Cards',
      },
      {
        'title': 'Geography',
        'subtitle': 'Maps & Countries',
        'icon': Icons.public_rounded,
        'gradient': [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
        'count': '90+ Cards',
      },
      {
        'title': 'Economics',
        'subtitle': 'Markets & Finance',
        'icon': Icons.trending_up_rounded,
        'gradient': [const Color(0xFF64748B), const Color(0xFF475569)],
        'count': '80+ Cards',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore Categories',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 16),
          child: Text(
            'Tap to explore or generate flashcards',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textSub),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final gradientColors = cat['gradient'] as List<Color>;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _topicController.text = cat['title'] as String;
                  _focusNode.requestFocus();
                },
                child:
                    Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 16, bottom: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Background Icon
                              Positioned(
                                right: -15,
                                bottom: -15,
                                child: Icon(
                                  cat['icon'] as IconData,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        cat['icon'] as IconData,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      cat['title'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cat['count'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate(delay: (100 * index).ms)
                        .fade(duration: 400.ms)
                        .slideX(begin: 0.2, end: 0, curve: Curves.easeOut),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(
    bool isDark,
    Color surfaceColor,
    Color textMain,
    Color textSub,
  ) {
    final totalSets = _flashcardSets.length;
    final totalCards = _flashcardSets.fold<int>(
      0,
      (sum, set) =>
          sum + ((set['cardCount'] ?? set['cards']?.length ?? 0) as int),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, value, child) => Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              ),
              child: Container(
                height: 96,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? primaryColor.withOpacity(0.15)
                      : primaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withOpacity(isDark ? 0.3 : 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MY SETS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSub,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '$totalSets',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) => Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              ),
              child: Container(
                height: 96,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: isDark
                      ? Border.all(color: const Color(0xFF2D2540))
                      : null,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL CARDS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSub,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '$totalCards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _getExamData(String exam) {
    final subjects = _getSubjectsForExam(exam);
    final data = <String, List<Map<String, dynamic>>>{};

    for (final subject in subjects) {
      data[subject] = [
        {
          'id': '${exam}_${subject}_1',
          'title': '$subject - Key Concepts',
          'cardCount': 20 + Random().nextInt(30),
          'isPremium': true,
        },
        {
          'id': '${exam}_${subject}_2',
          'title': '$subject - Practice Set',
          'cardCount': 40 + Random().nextInt(20),
          'isPremium': true,
        },
        {
          'id': '${exam}_${subject}_3',
          'title': 'Advanced $subject',
          'cardCount': 50,
          'isPremium': true,
        },
      ];
    }
    return data;
  }

  List<String> _getSubjectsForExam(String exam) {
    switch (exam.toLowerCase()) {
      case 'jee':
        return ['Physics', 'Chemistry', 'Mathematics'];
      case 'neet':
        return ['Biology', 'Physics', 'Chemistry'];
      case 'mba':
      case 'cat':
      case 'gmat':
      case 'gre':
        return ['Quantitative', 'Verbal Ability', 'Logical Reasoning'];
      case '10th':
      case '12th':
        return ['Science', 'Mathematics', 'English', 'Social Studies'];
      case 'ielts':
        return ['Reading', 'Writing', 'Listening', 'Speaking'];
      default:
        return ['General Knowledge', 'Aptitude'];
    }
  }

  void _showPremiumDialog(String itemName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Premium Content 💎',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Unlock "$itemName" and thousands of other expert-curated materials with Quirzy Pro.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Subscription feature coming soon! 🚀');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B13EC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Get Premium',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
