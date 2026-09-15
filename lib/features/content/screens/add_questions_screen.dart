import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/content_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/services/practice_content_service.dart';
import '../../../shared/providers/providers.dart';

class _QuestionData {
  final TextEditingController questionCtrl = TextEditingController();
  final List<TextEditingController> optionCtrls = List.generate(4, (_) => TextEditingController());
  int correctAnswer = 0;

  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) c.dispose();
  }
}

/// Manual "add your own questions" flow — no AI, saves straight into the
/// practice feed (and to Appwrite for durability), no linear quiz UI.
class AddQuestionsScreen extends ConsumerStatefulWidget {
  const AddQuestionsScreen({super.key});

  @override
  ConsumerState<AddQuestionsScreen> createState() => _AddQuestionsScreenState();
}

class _AddQuestionsScreenState extends ConsumerState<AddQuestionsScreen> {
  final _titleCtrl = TextEditingController();
  final List<_QuestionData> _questions = [];
  bool _isSaving = false;

  static const _primaryColor = Color(0xFF5B13EC);

  @override
  void initState() {
    super.initState();
    _addQuestion();
    _addQuestion();
    _addQuestion();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final q in _questions) q.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionData()));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum 3 questions required', style: GoogleFonts.plusJakartaSans()),
        ),
      );
      return;
    }
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showError('Please enter a topic title');
      return;
    }

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.questionCtrl.text.trim().isEmpty) {
        _showError('Question ${i + 1} text is empty');
        return;
      }
      for (int j = 0; j < 4; j++) {
        if (q.optionCtrls[j].text.trim().isEmpty) {
          _showError('Question ${i + 1}: Option ${String.fromCharCode(65 + j)} is empty');
          return;
        }
      }
    }

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    try {
      final contentService = ref.read(contentServiceProvider);
      final questionsData = _questions.map((q) => {
        'questionText': q.questionCtrl.text.trim(),
        'options': q.optionCtrls.map((c) => c.text.trim()).toList(),
        'correctAnswer': q.correctAnswer,
      }).toList();

      final result = await contentService.addManualQuestions(
        title: title,
        questions: questionsData,
      );

      final quizTitle = result['title']?.toString() ?? title;
      final questions = List<Map<String, dynamic>>.from(result['questions'] ?? []);

      await ref.read(practiceContentServiceProvider).addToQuestionPool(
            questions,
            topicId: result['quizId']?.toString() ?? '',
            topic: quizTitle,
          );
      await ref.read(feedControllerProvider.notifier).switchToTopic(quizTitle);

      if (mounted) {
        Navigator.pop(context);
        ref.read(tabIndexProvider.notifier).state = 0; // Practice tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${questions.length} questions to your feed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Failed to save: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.plusJakartaSans()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F8FC);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF120D1B);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Add Your Own Questions',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textMain),
        ),
        iconTheme: IconThemeData(color: textMain),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Add to Feed',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title field
          Text('Topic Title', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: textMain, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: TextField(
              controller: _titleCtrl,
              style: GoogleFonts.plusJakartaSans(color: textMain),
              decoration: InputDecoration(
                hintText: 'e.g. "Chapter 5: Cell Biology"',
                hintStyle: GoogleFonts.plusJakartaSans(color: textSub),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Questions
          ...List.generate(_questions.length, (i) => _buildQuestionCard(i, isDark, surfaceColor, textMain, textSub)),

          // Add question button
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add_circle_outline, color: _primaryColor),
            label: Text(
              'Add Question',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, bool isDark, Color surface, Color textMain, Color textSub) {
    final q = _questions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text('Question', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textMain)),
              const Spacer(),
              if (_questions.length > 3)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                  onPressed: () => _removeQuestion(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: q.questionCtrl,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textMain),
            decoration: InputDecoration(
              hintText: 'Enter your question...',
              hintStyle: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 13),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Options (tap radio to mark correct answer)',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSub),
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (j) {
            final label = String.fromCharCode(65 + j);
            final isCorrect = q.correctAnswer == j;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<int>(
                    value: j,
                    groupValue: q.correctAnswer,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => q.correctAnswer = v!),
                  ),
                  Expanded(
                    child: TextField(
                      controller: q.optionCtrls[j],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textMain,
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Option $label',
                        hintStyle: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 12),
                        filled: true,
                        fillColor: isCorrect
                            ? Colors.green.withOpacity(0.08)
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isCorrect ? Colors.green.withOpacity(0.4) : (isDark ? Colors.white12 : Colors.black12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isCorrect ? Colors.green.withOpacity(0.4) : (isDark ? Colors.white12 : Colors.black12)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
