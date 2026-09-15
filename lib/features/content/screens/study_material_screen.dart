import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/study_material_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  final StudyMaterial material;

  const StudyMaterialScreen({super.key, required this.material});

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentFlashcard = 0;
  bool _isFlipped = false;

  // Mini quiz state
  List<int?> _quizAnswers = [];
  bool _quizSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _quizAnswers = List.filled(widget.material.quiz.length, null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.material.topic,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textMain, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text('Study Set', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF10B981))),
          ],
        ),
        iconTheme: IconThemeData(color: textMain),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: const Color(0xFF10B981),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Summary'),
            Tab(icon: Icon(Icons.style_rounded, size: 18), text: 'Flashcards'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Practice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(isDark),
          _buildFlashcardsTab(isDark),
          _buildPracticeTab(isDark),
        ],
      ),
    );
  }

  // ── SUMMARY TAB ──────────────────────────────────────────────────────────

  Widget _buildSummaryTab(bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text('Key Concepts', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...widget.material.summary.asMap().entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entry.key + 1}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                  ),
                ),
                Expanded(
                  child: Text(entry.value, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textMain, height: 1.5)),
                ),
              ],
            ),
          ).animate(delay: (entry.key * 80).ms).fadeIn().slideX(begin: 0.05, end: 0);
        }),
      ],
    );
  }

  // ── FLASHCARDS TAB ────────────────────────────────────────────────────────

  Widget _buildFlashcardsTab(bool isDark) {
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cards = widget.material.flashcards;

    if (cards.isEmpty) {
      return Center(child: Text('No flashcards', style: GoogleFonts.plusJakartaSans(color: textSub)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_currentFlashcard + 1} / ${cards.length}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: textSub)),
              Text('Tap card to flip', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSub)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isFlipped = !_isFlipped);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isFlipped
                    ? _flashcardFace(
                        key: const ValueKey('back'),
                        text: cards[_currentFlashcard]['back'] as String? ?? '',
                        label: 'Definition',
                        color: const Color(0xFF5B13EC),
                        isDark: isDark,
                      )
                    : _flashcardFace(
                        key: const ValueKey('front'),
                        text: cards[_currentFlashcard]['front'] as String? ?? '',
                        label: 'Concept',
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _currentFlashcard > 0
                      ? () => setState(() { _currentFlashcard--; _isFlipped = false; })
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('← Prev', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: textMain)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentFlashcard < cards.length - 1
                      ? () => setState(() { _currentFlashcard++; _isFlipped = false; })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Next →', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flashcardFace({
    required Key key,
    required String text,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF120D1B), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.touch_app_rounded, color: color.withOpacity(0.4), size: 24),
        ],
      ),
    );
  }

  // ── PRACTICE QUIZ TAB ────────────────────────────────────────────────────

  Widget _buildPracticeTab(bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final quiz = widget.material.quiz;

    if (quiz.isEmpty) {
      return Center(child: Text('No practice questions', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white54 : Colors.black45)));
    }

    final correctCount = _quizSubmitted
        ? quiz.asMap().entries.where((e) => _quizAnswers[e.key] == e.value['correctAnswer']).length
        : 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_quizSubmitted) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: correctCount >= quiz.length * 0.8 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: correctCount >= quiz.length * 0.8 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  correctCount >= quiz.length * 0.8 ? Icons.check_circle_rounded : Icons.star_half_rounded,
                  color: correctCount >= quiz.length * 0.8 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  '$correctCount / ${quiz.length} correct',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold,
                    color: correctCount >= quiz.length * 0.8 ? Colors.green : Colors.orange),
                ),
              ],
            ),
          ),
        ],
        ...quiz.asMap().entries.map((entry) {
          final qi = entry.key;
          final q = entry.value;
          final selected = _quizAnswers[qi];
          final correctAnswer = q['correctAnswer'] as int? ?? 0;
          final options = (q['options'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Text(
                    'Q${qi + 1}. ${q['questionText']}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textMain, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
                const SizedBox(height: 8),
                ...options.asMap().entries.map((optEntry) {
                  final oi = optEntry.key;
                  final opt = optEntry.value;
                  Color? borderColor;
                  Color? bgColor;
                  IconData? trailingIcon;

                  if (_quizSubmitted) {
                    if (oi == correctAnswer) {
                      borderColor = Colors.green;
                      bgColor = Colors.green.withOpacity(0.08);
                      trailingIcon = Icons.check_circle_rounded;
                    } else if (oi == selected && selected != correctAnswer) {
                      borderColor = Colors.red;
                      bgColor = Colors.red.withOpacity(0.08);
                      trailingIcon = Icons.cancel_rounded;
                    }
                  } else if (oi == selected) {
                    borderColor = const Color(0xFF5B13EC);
                    bgColor = const Color(0xFF5B13EC).withOpacity(0.08);
                  }

                  return GestureDetector(
                    onTap: _quizSubmitted ? null : () => setState(() => _quizAnswers[qi] = oi),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: bgColor ?? surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor ?? (isDark ? Colors.white12 : Colors.black12)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${String.fromCharCode(65 + oi)}. ',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: borderColor ?? textMain, fontSize: 13),
                          ),
                          Expanded(
                            child: Text(opt, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textMain)),
                          ),
                          if (trailingIcon != null) Icon(trailingIcon, color: borderColor, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ).animate(delay: (qi * 60).ms).fadeIn();
        }),
        const SizedBox(height: 8),
        if (!_quizSubmitted)
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _quizSubmitted = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B13EC),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Submit Answers', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
          )
        else
          OutlinedButton(
            onPressed: () => setState(() {
              _quizAnswers = List.filled(quiz.length, null);
              _quizSubmitted = false;
            }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF5B13EC)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Try Again', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF5B13EC), fontSize: 15)),
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}
