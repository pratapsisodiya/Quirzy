import 'package:flutter/material.dart';

class PracticeTheme {
  // Brand Colors
  // Brand Colors (Neural Bulb Palette)
  static const Color primary = Color(0xFF6200EA); // Electric Violet
  static const Color secondary = Color(0xFF00E5FF); // Cyber Cyan
  static const Color accent = Color(0xFFFF2E63); // Idea Magenta
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFFF7675);

  // Power-up Colors
  static const Color color5050 = Color(0xFF74B9FF);
  static const Color colorFreeze = Color(0xFF81ECEC);
  static const Color colorShield = Color(0xFF55EFC4);

  // Surface Colors
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color backgroundDark = Color(0xFF120E1A); // Deep Void Purple

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF6200EA),
    Color(0xFF7C4DFF), // Lighter Violet for gradient
  ];
  static const List<Color> successGradient = [
    Color(0xFF00B894),
    Color(0xFF55EFC4),
  ];
  static const List<Color> errorGradient = [
    Color(0xFFFF7675),
    Color(0xFFFAB1A0),
  ];
  static const List<Color> warningGradient = [
    Color(0xFFFDCB6E),
    Color(0xFFFFEAA7),
  ];

  static LinearGradient getGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Decorations
  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? borderColor,
    bool isSelected = false,
  }) {
    return BoxDecoration(
      color: isDark ? surfaceDark : surfaceLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? (isDark ? Colors.white10 : Colors.black12),
        width: isSelected ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: (borderColor ?? Colors.black).withOpacity(
            isSelected ? 0.3 : 0.05,
          ),
          blurRadius: isSelected ? 12 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
