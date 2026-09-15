import 'package:appwrite/appwrite.dart';
import '../../../shared/appwrite/appwrite_client.dart';

/// Profile/Settings Service using Appwrite
class ProfileService {
  final Databases _db = AppwriteClient.instance.databases;
  final Account _account = AppwriteClient.instance.account;

  static const String settingsCollection = 'user_settings';
  static const String quizResultsCollection = 'quiz_results';
  static const String quizzesCollection = 'quizzes';
  static const String usersCollection = 'users';

  // Get User Settings
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final user = await _account.get();

      try {
        final settings = await _db.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: settingsCollection,
          documentId: user.$id,
        );
        return settings.data;
      } catch (_) {
        // Create default settings
        final defaultSettings = {
          'userId': user.$id,
          'notificationsEnabled': true,
          'soundEnabled': true,
          'darkMode': false,
          'language': 'English',
        };

        await _db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: settingsCollection,
          documentId: user.$id,
          data: defaultSettings,
        );

        return defaultSettings;
      }
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch settings');
    }
  }

  // Update Settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      final user = await _account.get();

      await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: settingsCollection,
        documentId: user.$id,
        data: settings,
      );
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to update settings');
    }
  }

  // Get Quiz History
  Future<List<Map<String, dynamic>>> getQuizHistory() async {
    try {
      final user = await _account.get();

      final results = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: quizResultsCollection,
        queries: [
          Query.equal('userId', user.$id),
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );

      return results.documents.map((doc) {
        return {
          'id': doc.$id,
          'title': doc.data['title'] ?? doc.data['quizTitle'] ?? 'Quiz',
          'score': doc.data['score'] ?? 0,
          'totalQuestions': doc.data['totalQuestions'] ?? 10,
          'percentage': doc.data['percentage'] ?? 0,
          'createdAt': doc.data['createdAt'],
        };
      }).toList();
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch quiz history');
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final user = await _account.get();

      final results = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: quizResultsCollection,
        queries: [Query.equal('userId', user.$id)],
      );

      final quizzes = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: quizzesCollection,
        queries: [Query.equal('userId', user.$id)],
      );

      double totalScore = 0;
      int perfectScores = 0;
      int totalPoints = 0;

      for (final doc in results.documents) {
        final percentage = (doc.data['percentage'] ?? 0).toDouble();
        totalScore += percentage;
        if (percentage == 100) perfectScores++;
        totalPoints += (doc.data['score'] ?? 0) as int;
      }

      final averageScore = results.total > 0 ? totalScore / results.total : 0;

      return {
        'totalQuizzes': results.total,
        'averageScore': averageScore.round(),
        'perfectScores': perfectScores,
        'totalPoints': totalPoints,
        'createdQuizzes': quizzes.total,
      };
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch statistics');
    }
  }

  // Clear History
  Future<void> clearHistory() async {
    try {
      final user = await _account.get();

      final results = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: quizResultsCollection,
        queries: [Query.equal('userId', user.$id)],
      );

      for (final doc in results.documents) {
        await _db.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: quizResultsCollection,
          documentId: doc.$id,
        );
      }
    } on AppwriteException catch (e) {
      throw Exception(e.message ?? 'Failed to clear history');
    }
  }
}
