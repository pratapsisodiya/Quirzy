import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import 'home_screen.dart';
import '../../feed/screens/feed_screen.dart';
import '../../flashcards/screens/screens.dart';
import '../../profile/screens/screens.dart';
import '../../onboarding/screens/screens.dart';
import '../../quiz/screens/mock_test_setup_screen.dart';

import '../../../shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/quirzy_navigation_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Exam Selection
    if (prefs.getString('selected_exam') == null) {
      if (mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ExamSelectionScreen()));
      }
    }

    // 3. Notifications
    NotificationService().init();
    NotificationService().scheduleHourlyNotification();
  }

  // Screens list — Practice (the ScrollPrep-style feed) is the default tab.
  List<Widget> get _screens => const [
    RepaintBoundary(child: FeedScreen()),
    RepaintBoundary(child: HomeScreen()),
    RepaintBoundary(child: MockTestSetupScreen()),
    RepaintBoundary(child: HistoryScreen()),
    RepaintBoundary(child: FlashcardsScreen()),
    RepaintBoundary(child: ProfileSettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: QuirzyNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          HapticFeedback.lightImpact();
          ref.read(tabIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}
