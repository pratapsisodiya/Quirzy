import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/content_providers.dart';
import 'study_material_screen.dart';

class StudyMaterialEntryScreen extends ConsumerStatefulWidget {
  const StudyMaterialEntryScreen({super.key});

  @override
  ConsumerState<StudyMaterialEntryScreen> createState() => _StudyMaterialEntryScreenState();
}

class _StudyMaterialEntryScreenState extends ConsumerState<StudyMaterialEntryScreen> {
  final _topicCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _showNotes = false;
  bool _isGenerating = false;

  static const _primaryColor = Color(0xFF5B13EC);

  @override
  void dispose() {
    _topicCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a topic', style: GoogleFonts.plusJakartaSans())),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isGenerating = true);

    try {
      final service = ref.read(studyMaterialServiceProvider);
      final material = await service.generateStudyMaterial(
        topic: topic,
        studyNotes: _showNotes && _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudyMaterialScreen(material: material)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('daily_limit_reached')
            ? 'Daily limit reached (1 free/day). Upgrade to Pro for unlimited!'
            : 'Failed to generate: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.plusJakartaSans()),
            backgroundColor: e.toString().contains('daily_limit') ? const Color(0xFF5B13EC) : Colors.red,
            action: e.toString().contains('daily_limit')
                ? SnackBarAction(label: 'Upgrade', textColor: Colors.white, onPressed: () {})
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

    final historyAsync = ref.watch(studyMaterialHistoryProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Study Set Generator', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textMain)),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AI Study Set', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Get Summary + Flashcards + Quiz', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('1 FREE/DAY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Topic input
                    Text('Topic', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: TextField(
                        controller: _topicCtrl,
                        style: GoogleFonts.plusJakartaSans(color: textMain),
                        decoration: InputDecoration(
                          hintText: 'e.g. "Newton\'s Laws of Motion", "Photosynthesis", "French Revolution"',
                          hintStyle: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: Icon(Icons.search_rounded, color: textSub),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Optional notes toggle
                    GestureDetector(
                      onTap: () => setState(() => _showNotes = !_showNotes),
                      child: Row(
                        children: [
                          Icon(_showNotes ? Icons.expand_less : Icons.expand_more, color: _primaryColor, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _showNotes ? 'Hide study notes' : 'Add your study notes (optional)',
                            style: GoogleFonts.plusJakartaSans(color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_showNotes) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: TextField(
                          controller: _notesCtrl,
                          maxLines: 8,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textMain),
                          decoration: InputDecoration(
                            hintText: 'Paste your notes here for more targeted content...',
                            hintStyle: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Recent history
                    Text('Recent Study Sets', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                    const SizedBox(height: 12),
                    historyAsync.when(
                      data: (history) {
                        if (history.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                            ),
                            child: Center(
                              child: Text('No study sets yet', style: GoogleFonts.plusJakartaSans(color: textSub)),
                            ),
                          );
                        }
                        return Column(
                          children: history.take(5).map((m) => GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyMaterialScreen(material: m))),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.menu_book_outlined, color: Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(m.topic, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: textMain, fontSize: 13)),
                                  ),
                                  Icon(Icons.chevron_right, color: textSub, size: 18),
                                ],
                              ),
                            ),
                          )).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isGenerating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Generate Study Set', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
