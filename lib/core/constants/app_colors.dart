import 'package:flutter/material.dart';

/// GoalSync centralized color palette.
///
/// Brand identity: Premium AI FinTech + Digital Intelligence + Modern SaaS.
/// All colors are defined here as a single source of truth.
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────────
  // Brand Core
  // ─────────────────────────────────────────────────────────────

  /// Deep Navy – primary brand anchor, used as dark background & text on light.
  static const Color deepNavy = Color(0xFF071A2B);

  /// Electric Cyan – primary accent / interactive highlight.
  static const Color electricCyan = Color(0xFF00D9FF);

  /// Mint – secondary accent / success / positive indicators.
  static const Color mint = Color(0xFF5FFFD2);

  // ─────────────────────────────────────────────────────────────
  // Brand Variants
  // ─────────────────────────────────────────────────────────────

  /// Slightly lighter navy for layered surfaces in dark mode.
  static const Color navyLight = Color(0xFF0D2640);

  /// Mid navy for cards / elevated containers in dark mode.
  static const Color navyMid = Color(0xFF102E4A);

  /// Deep navy with very subtle blue tint for dark mode dividers.
  static const Color navyBorder = Color(0xFF1A3A55);

  /// Cyan with reduced opacity – used for glow effects & subtle highlights.
  static const Color cyanGlow = Color(0x2900D9FF);

  /// Mint with reduced opacity – used for positive badge backgrounds.
  static const Color mintGlow = Color(0x295FFFD2);

  /// Darker cyan shade for pressed/active states.
  static const Color cyanDark = Color(0xFF00AACB);

  /// Darker mint shade for pressed/active states.
  static const Color mintDark = Color(0xFF2ECFA8);

  // ─────────────────────────────────────────────────────────────
  // Light Theme Surfaces
  // ─────────────────────────────────────────────────────────────

  /// Light theme background – soft blue-tinted, not pure white.
  static const Color lightBackground = Color(0xFFEFF5FB);

  /// Light theme scaffold – very subtle blue tint.
  static const Color lightScaffold = Color(0xFFF4F8FD);

  /// Light theme surface (cards, sheets).
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light theme surface variant (input backgrounds, chips).
  static const Color lightSurfaceVariant = Color(0xFFE3EDF7);

  /// Light theme secondary surface.
  static const Color lightSurface2 = Color(0xFFF0F6FC);

  // ─────────────────────────────────────────────────────────────
  // Dark Theme Surfaces
  // ─────────────────────────────────────────────────────────────

  /// Dark theme background – Deep Navy.
  static const Color darkBackground = deepNavy;

  /// Dark theme scaffold – same as background for seamless feel.
  static const Color darkScaffold = deepNavy;

  /// Dark theme surface (cards, sheets) – slightly lighter navy.
  static const Color darkSurface = navyLight;

  /// Dark theme surface variant (input backgrounds, chips).
  static const Color darkSurfaceVariant = navyMid;

  /// Dark theme secondary surface.
  static const Color darkSurface2 = Color(0xFF0F2438);

  // ─────────────────────────────────────────────────────────────
  // Text Colors
  // ─────────────────────────────────────────────────────────────

  /// Primary text on light surfaces.
  static const Color textPrimaryLight = Color(0xFF071A2B);

  /// Secondary text on light surfaces.
  static const Color textSecondaryLight = Color(0xFF4A6580);

  /// Tertiary / hint text on light surfaces.
  static const Color textTertiaryLight = Color(0xFF8AAABF);

  /// Primary text on dark surfaces.
  static const Color textPrimaryDark = Color(0xFFE8F4FF);

  /// Secondary text on dark surfaces.
  static const Color textSecondaryDark = Color(0xFF8AAABF);

  /// Tertiary / hint text on dark surfaces.
  static const Color textTertiaryDark = Color(0xFF4A6580);

  // ─────────────────────────────────────────────────────────────
  // Semantic Colors
  // ─────────────────────────────────────────────────────────────

  /// Success – aligned with mint brand color.
  static const Color success = Color(0xFF1FD4A4);

  /// Warning – warm amber that contrasts well on both themes.
  static const Color warning = Color(0xFFFFB830);

  /// Error – refined red that avoids the generic look.
  static const Color error = Color(0xFFFF4D6A);

  /// Info – aligned with electric cyan.
  static const Color info = electricCyan;

  // ─────────────────────────────────────────────────────────────
  // Gradients (defined as list of stops for use in LinearGradient)
  // ─────────────────────────────────────────────────────────────

  /// Primary brand gradient: Deep Navy → slightly lighter navy.
  static const List<Color> gradientNavy = [
    deepNavy,
    navyLight,
  ];

  /// Accent gradient: Electric Cyan → Mint.
  static const List<Color> gradientAccent = [
    electricCyan,
    mint,
  ];

  /// Subtle card highlight gradient for light theme.
  static const List<Color> gradientCardLight = [
    lightSurface,
    lightSurface2,
  ];

  /// Subtle card highlight gradient for dark theme.
  static const List<Color> gradientCardDark = [
    navyLight,
    navyMid,
  ];
}
