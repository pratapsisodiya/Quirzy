import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../../../shared/appwrite/appwrite_client.dart';

/// Generates and stores practice content — an AI topic generation call, or
/// manually-typed questions — backed by Appwrite. Output feeds straight
/// into the practice feed rather than a standalone quiz-taking flow.
class ContentService {
  final Databases _db = AppwriteClient.instance.databases;
  final Functions _fn = AppwriteClient.instance.functions;
  final Account _account = AppwriteClient.instance.account;

  /// AI-generates a set of questions for [topic] via the Appwrite function.
  Future<Map<String, dynamic>> generateTopicContent({
    required String topic,
    int questionCount = 15,
    String difficulty = 'medium',
  }) async {
    try {
      final user = await _account.get();

      final execution = await _fn.createExecution(
        functionId: AppwriteConfig.quizGenerateFunction,
        body: jsonEncode({
          'topic': topic,
          'questionCount': questionCount,
          'difficulty': difficulty,
          'userId': user.$id,
        }),
      );

      if (execution.status.name == 'completed') {
        final response = jsonDecode(execution.responseBody);
        if (response['error'] != null) throw Exception(response['error']);
        return response;
      }
      throw Exception('Topic generation failed');
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to generate topic');
    }
  }

  /// Saves manually-typed questions (no AI) as a new topic.
  Future<Map<String, dynamic>> addManualQuestions({
    required String title,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      final user = await _account.get();
      final now = DateTime.now().toIso8601String();

      final topic = await _db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.quizzesCollection,
        documentId: ID.unique(),
        data: {
          'title': title,
          'userId': user.$id,
          'createdAt': now,
          'updatedAt': now,
        },
      );

      final savedQuestions = <Map<String, dynamic>>[];
      for (int i = 0; i < questions.length; i++) {
        final q = await _db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.questionsCollection,
          documentId: ID.unique(),
          data: {
            'quizId': topic.$id,
            'questionText': questions[i]['questionText'] as String,
            'options': List<String>.from(questions[i]['options'] as List),
            'correctAnswer': questions[i]['correctAnswer'] as int,
            'questionNumber': i + 1,
          },
        );
        savedQuestions.add({
          'id': q.$id,
          'questionText': q.data['questionText'],
          'options': List<String>.from(q.data['options'] ?? []),
          'correctAnswer': q.data['correctAnswer'],
          'questionNumber': q.data['questionNumber'],
        });
      }

      return {
        'quizId': topic.$id,
        'title': topic.data['title'],
        'questionCount': savedQuestions.length,
        'questions': savedQuestions,
      };
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to save questions');
    }
  }
}
