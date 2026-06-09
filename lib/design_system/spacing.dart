import 'package:flutter/widgets.dart';

/// Spacing scale (4dp base). No screen hand-rolls an [EdgeInsets] value —
/// use these tokens so layout stays consistent and sunlight-legible.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Minimum height for a primary touch target (one-hand-on-the-wheel UX).
  static const double minTouchTarget = 56;

  /// Standard screen edge padding.
  static const EdgeInsets screen = EdgeInsets.all(md);
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: md);

  /// Default corner radius for cards, sheets and buttons.
  static const double radius = 16;
  static const Radius radiusCircular = Radius.circular(radius);
}
