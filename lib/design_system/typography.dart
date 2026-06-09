import 'package:flutter/material.dart';

/// Type scale. Body text is never below 16sp (sunlight readability), and
/// money is rendered with a tabular-friendly weight so ₹ figures stay aligned.
abstract final class AppText {
  static const String _family = 'Roboto';

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: _family,
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: TextStyle(
      fontFamily: _family,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontFamily: _family,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: _family,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 17,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 16, // floor for body text
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Emphasis style for ₹ amounts (earnings, fare, wallet).
  static const TextStyle money = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
