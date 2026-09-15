import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../../../shared/appwrite/appwrite_client.dart';

/// Service to generate a quiz from pasted study notes via Appwrite Function
class StudyQuizService {
  final Functions _fn = AppwriteClient.instance.functions;
  final Account _account = AppwriteClient.instance.account;

  Future<Map<String, dynamic>> generateQuizFromNotes({
    required String studyNotes,
    int questionCount = 10,
    String difficulty = 'medium',
  }) async {
    if (studyNotes.trim().length < 100) {
      throw Exception('Please provide at least 100 characters of study notes');
    }

    final user = await _account.get();

    final execution = await _fn.createExecution(
      functionId: AppwriteConfig.studyGenerateFunction,
      body: jsonEncode({
        'text': studyNotes,
        'userId': user.$id,
        'questionCount': questionCount,
        'difficulty': difficulty,
      }),
    );

    if (execution.status.name == 'completed') {
      final response = jsonDecode(execution.responseBody) as Map<String, dynamic>;
      if (response['error'] != null) throw Exception(response['error']);
      return response;
    }
    throw Exception('Study quiz generation failed');
  }
}
