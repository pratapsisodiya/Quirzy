/// Services barrel export
library;

// Re-export from shared/services for now
// TODO: Move actual files to core/services/
export 'package:quirzy/shared/services/cache_service.dart';
export 'package:quirzy/shared/services/settings_service.dart';
export 'package:quirzy/shared/services/share_service.dart';
export 'package:quirzy/shared/services/study_streak_service.dart';
export 'package:quirzy/shared/services/spaced_repetition_service.dart';
export 'package:quirzy/shared/services/reminder_service.dart';
export 'package:quirzy/shared/services/app_review_service.dart';
export 'package:quirzy/shared/services/deep_link_service.dart';

// Appwrite Services
export 'package:quirzy/shared/appwrite/appwrite_services.dart';

// Feature Services (excluding Achievement which conflicts)
// export 'package:quirzy/shared/features/quiz_experience_features.dart';
