import 'package:flutter/material.dart';

/// Murkot brand colors — fresh orange / mandarin juice
/// (RGB 252,191,52 / 241,137,30 from the logo sheet).
abstract final class MurkotColors {
  static const yellow = Color(0xFFFCBF34);
  static const orange = Color(0xFFF1891E);
  static const deepOrange = Color(0xFFE07010);
  static const cream = Color(0xFFFFF6E8);
  static const pulp = Color(0xFFFFE2A8);
  static const leaf = Color(0xFF5A8F3C);

  /// Warm dark surfaces — never pure black.
  static const night = Color(0xFF241910);
  static const nightElevated = Color(0xFF312418);

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

  /// Auth backdrop — multi-stop radial feel via sweep/linear combo.
  static const authGradientLight = RadialGradient(
    center: Alignment(-0.35, -0.55),
    radius: 1.35,
    colors: [
      Color(0xFFFFFBF3),
      cream,
      pulp,
      Color(0xFFFFC96A),
      Color(0xFFF5A43A),
    ],
    stops: [0.0, 0.28, 0.52, 0.78, 1.0],
  );

  static const authGradientDark = RadialGradient(
    center: Alignment(-0.3, -0.5),
    radius: 1.4,
    colors: [
      Color(0xFF3A2818),
      night,
      Color(0xFF1E160F),
      Color(0xFF2A1C10),
    ],
    stops: [0.0, 0.4, 0.75, 1.0],
  );
}

/// Local brand display font (Arial Rounded MT Bold).
const murkotFontFamily = 'ArialRoundedMTBold';

enum MurkotLightFlavor {
  /// ThemeMode.system → juicier orange scaffold.
  system,

  /// ThemeMode.light → cleaner cream / near-white.
  light,
}

ThemeData buildMurkotTheme(
  Brightness brightness, {
  MurkotLightFlavor lightFlavor = MurkotLightFlavor.system,
}) {
  final isLight = brightness == Brightness.light;
  final juiceLight = lightFlavor == MurkotLightFlavor.system;

  final scaffold = !isLight
      ? MurkotColors.night
      : juiceLight
          ? const Color(0xFFFFEED4)
          : MurkotColors.cream;

  final surface = !isLight
      ? MurkotColors.nightElevated
      : juiceLight
          ? const Color(0xFFFFF8EC)
          : const Color(0xFFFFFCF7);

  final scheme = ColorScheme.fromSeed(
    seedColor: MurkotColors.orange,
    brightness: brightness,
    primary: isLight ? MurkotColors.orange : MurkotColors.yellow,
    secondary: MurkotColors.yellow,
    surface: surface,
  ).copyWith(
    onSurface: isLight ? const Color(0xFF2A1A0C) : MurkotColors.cream,
  );

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: murkotFontFamily,
  );
  final textTheme = base.textTheme.apply(
    fontFamily: murkotFontFamily,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: murkotFontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MurkotColors.orange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? Colors.white.withValues(alpha: 0.92) : MurkotColors.nightElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: MurkotColors.yellow.withValues(alpha: 0.45),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
