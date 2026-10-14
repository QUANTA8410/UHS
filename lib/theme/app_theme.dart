import 'package:flutter/material.dart';

class AppTheme {
  static const Color googleBlue = Color(0xFF1A73E8);
  static const Color activeAmber = Color(0xFFF9AB00);
  static const Color coolingCyan = Color(0xFF0097A7);
  static const Color heatingCoral = Color(0xFFE8710A);
  static const Color applianceGreen = Color(0xFF34A853);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: googleBlue,
      brightness: Brightness.light,
      surface: const Color(0xFFF8F9FA),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      color: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      backgroundColor: Colors.white,
      indicatorColor: googleBlue.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: googleBlue,
      brightness: Brightness.dark,
      surface: const Color(0xFF1F1F1F),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      color: const Color(0xFF1E1E1E),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      backgroundColor: const Color(0xFF1E1E1E),
      indicatorColor: googleBlue.withValues(alpha: 0.24),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}
