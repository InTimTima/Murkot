import 'package:flutter/material.dart';

/// Murkot brand colors — fresh orange / mandarin juice.
abstract final class MurkotColors {
  static const yellow = Color(0xFFFCBF34);
  static const orange = Color(0xFFF1891E);
  static const deepOrange = Color(0xFFE07010);
  static const cream = Color(0xFFFFF6E8);
  static const pulp = Color(0xFFFFE2A8);
  static const leaf = Color(0xFF5A8F3C);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [yellow, orange, deepOrange],
  );

  static const softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cream, pulp, Color(0xFFFFD27A)],
  );
}

ThemeData buildMurkotTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: MurkotColors.orange,
    brightness: brightness,
    primary: brightness == Brightness.light
        ? MurkotColors.orange
        : MurkotColors.yellow,
    secondary: MurkotColors.yellow,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? MurkotColors.cream
        : const Color(0xFF1A140C),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: brightness == Brightness.light
          ? MurkotColors.cream
          : const Color(0xFF1A140C),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: MurkotColors.orange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.white
          : Colors.grey.shade900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: MurkotColors.yellow.withValues(alpha: 0.45),
    ),
  );
}
