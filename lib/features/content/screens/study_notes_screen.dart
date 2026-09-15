import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/content_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/services/practice_content_service.dart';
import '../../../shared/providers/providers.dart';
import '../../home/widgets/home_widgets.dart';

class StudyNotesScreen extends ConsumerStatefulWidget {
  const StudyNotesScreen({super.key});

  @override
  ConsumerState<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends ConsumerState<StudyNotesScreen> {
  final _notesController = TextEditingController();
  int _questionCount = 10;
  String _difficulty = 'medium';

  static const _primaryColor = Color(0xFF5B13EC);
  static const _counts = [5, 10, 15, 20];
  static const _difficulties = ['easy', 'medium', 'hard'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final notes = _notesController.text.trim();
    if (notes.length < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter at least 100 characters of notes (${notes.length}/100)',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizGenerationLoadingScreen()),
    );

    try {
      final service = ref.read(studyQuizServiceProvider);
      final result = await service.generateQuizFromNotes(
        studyNotes: notes,
        questionCount: _questionCount,
        difficulty: _difficulty,
      );

      final quizTitle = result['title']?.toString() ?? 'Study Notes';
      final questions = List<Map<String, dynamic>>.from(result['questions'] ?? []);

      await ref.read(practiceContentServiceProvider).addToQuestionPool(
            questions,
            topicId: result['quizId']?.toString() ?? '',
            topic: quizTitle,
          );
      await ref.read(feedControllerProvider.notifier).switchToTopic(quizTitle);

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        Navigator.pop(context); // back out of this screen
        ref.read(tabIndexProvider.notifier).state = 0; // Practice tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${questions.length} questions to your feed')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

    final charCount = _notesController.text.length;
    final hasEnough = charCount >= 100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Study Notes → Practice',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
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
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor.withOpacity(0.1),
                            const Color(0xFF8B5CF6).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Paste your study notes, lecture text, or any content — AI will turn it into practice questions for your feed.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textSub),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notes input
                    Text(
                      'Study Notes',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasEnough ? _primaryColor.withOpacity(0.4) : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 12,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textMain),
                        decoration: InputDecoration(
                          hintText: 'Paste your notes here...\n\nExample: "Photosynthesis is the process by which plants use sunlight, water, and carbon dioxide to produce oxygen and energy in the form of glucose..."',
                          hintStyle: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hasEnough ? 'Ready to generate' : '${100 - charCount} more characters needed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: hasEnough ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$charCount chars',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Question count selector
                    Text(
                      'Number of Questions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _counts.map((count) {
                        final selected = count == _questionCount;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _questionCount = count),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? _primaryColor : surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? _primaryColor : (isDark ? Colors.white12 : Colors.black12),
                                ),
                              ),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.white : textMain,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Difficulty selector
                    Text(
                      'Difficulty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _difficulties.map((diff) {
                        final selected = diff == _difficulty;
                        final color = diff == 'easy'
                            ? Colors.green
                            : diff == 'medium'
                                ? Colors.orange
                                : Colors.red;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _difficulty = diff),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? color.withOpacity(0.15) : surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? color : (isDark ? Colors.white12 : Colors.black12),
                                ),
                              ),
                              child: Text(
                                diff[0].toUpperCase() + diff.substring(1),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: selected ? color : textMain,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Generate button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasEnough ? _generate : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: _primaryColor.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add to Feed ($_questionCount Qs)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }
}
