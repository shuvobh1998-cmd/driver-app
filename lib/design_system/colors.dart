import 'package:flutter/material.dart';

/// Single source of truth for color. No screen hand-rolls a [Color];
/// everything flows through [AppColors] and the [ColorScheme] built from it.
///
/// Status colors are paired with an icon + label everywhere they are used so
/// state is never communicated by color alone (sunlight + accessibility).
abstract final class AppColors {
  // Brand
  static const Color brand = Color(0xFF0B6E4F); // deep green — "go / earnings"
  static const Color brandDark = Color(0xFF34C759);
  static const Color accent = Color(0xFFFFB300); // amber — attention / money

  // Semantic status
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Neutrals — light
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1A1C1E);
  static const Color lightOutline = Color(0xFFD3D7DC);

  // Neutrals — dark
  static const Color darkBackground = Color(0xFF121417);
  static const Color darkSurface = Color(0xFF1D2024);
  static const Color darkOnSurface = Color(0xFFE3E5E8);
  static const Color darkOutline = Color(0xFF3A3F45);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Color(0xFF1A1C1E),
    error: danger,
    onError: Colors.white,
    surface: lightSurface,
    onSurface: lightOnSurface,
    outline: lightOutline,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: brandDark,
    onPrimary: Color(0xFF06251A),
    secondary: accent,
    onSecondary: Color(0xFF1A1C1E),
    error: Color(0xFFEF5350),
    onError: Color(0xFF3A0000),
    surface: darkSurface,
    onSurface: darkOnSurface,
    outline: darkOutline,
  );
}
