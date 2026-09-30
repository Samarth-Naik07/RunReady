import 'package:flutter/material.dart';

/// RunReady's light and dark Material 3 themes.
///
/// Both come from the same blue accent. Widgets read colors from the theme
/// (`colorScheme`, `cardColor`, `scaffoldBackgroundColor`) rather than
/// hard-coding them, so they work in either mode.
abstract final class AppTheme {
  /// The RunReady blue.
  static const accent = Color(0xFF3D8BF2);

  /// Soft blue-grey page background in light mode.
  static const _lightBackground = Color(0xFFE4EBF3);

  /// Light mode: soft blue-grey background with white cards.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: Colors.white,
    );
  }

  /// Dark mode: dark blue-tinted background with slightly lighter cards.
  ///
  /// The primary color is left to Material 3, which picks a lighter blue from
  /// the same seed so it stays readable on dark surfaces.
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: colorScheme.surfaceContainerHigh,
    );
  }
}
