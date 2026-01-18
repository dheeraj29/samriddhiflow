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

  // Safe font style for critical offline UI elements (avoids FOIT)
  static const TextStyle offlineSafeTextStyle = TextStyle(
    fontFamily: 'system-ui', // Native OS font (SF Pro on iOS)
    fontFamilyFallback: [
      '.SF Pro Text',
      '.SF UI Text',
      'SF Compact',
      'Google Sans Flex',
      'Google Sans',
      'Roboto',
      'Segoe UI',
      'Arial',
      'Verdana',
      'sans-serif'
    ],
  );

  static const List<String> globalFontFallbacks = [
    'system-ui',
    '.SF Pro Text',
    '.SF UI Text',
    'SF Compact',
    'Google Sans Flex',
    'Google Sans',
    'Roboto',
    'Segoe UI',
    'Arial',
    'Verdana',
    'sans-serif'
  ];

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
        background: backgroundLight,
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
            fontFamilyFallback: globalFontFallbacks,
          ),
        ),
      ),
      // textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      // Fallback to system font for offline safety (unless we bundle Outfit locally)
      typography: Typography.material2021(platform: TargetPlatform.android),
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: null,
            fontFamilyFallback: globalFontFallbacks,
          ),
      fontFamily: null,
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
        background: backgroundDark,
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
            fontFamilyFallback: globalFontFallbacks,
          ),
        ),
      ),
      // textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      typography: Typography.material2021(platform: TargetPlatform.android),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: null,
            fontFamilyFallback: globalFontFallbacks,
          ),
      fontFamily: null,
    );
  }
}
