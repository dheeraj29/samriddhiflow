import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF00BFA6); // Teal
  static const Color backgroundLight = Color(0xFFF4F6F8);
  static const Color surfaceLight = Colors.white;
  static const Color backgroundDark = Color(0xFF1E1E2C);
  static const Color surfaceDark = Color(0xFF2D2D44);

  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);

  static const List<Color> chartPalette = [
    Color(0xFF6C63FF), // Primary
    Color(0xFF00BFA6), // Secondary
    Color(0xFFFFB74D), // Orange
    Color(0xFF4FC3F7), // Light Blue
    Color(0xFF9575CD), // Purple
    Color(0xFFFF8A65), // Deep Orange
    Color(0xFFAED581), // Light Green
  ];

  static const TextStyle offlineSafeTextStyle = TextStyle(
    fontFamily: 'AppFont', // Bundled Asset (Roboto)
    fontFamilyFallback: ['sans-serif'],
  );

  static const List<String> globalFontFallbacks = ['sans-serif'];

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surfaceLight,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundLight,
      // cardTheme removed to resolve type conflict
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'AppFont',
            fontFamilyFallback: globalFontFallbacks,
          ),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'AppFont',
            fontFamilyFallback: globalFontFallbacks,
          ),
      fontFamily: 'AppFont',
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: secondary,
        surface: surfaceDark,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundDark,
      // cardTheme removed to resolve type conflict
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'AppFont',
            fontFamilyFallback: globalFontFallbacks,
          ),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'AppFont',
            fontFamilyFallback: globalFontFallbacks,
          ),
      fontFamily: 'AppFont',
    );
  }
}
