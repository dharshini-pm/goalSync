import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// GoalSync typography system.
///
/// Built on the [Inter](https://fonts.google.com/specimen/Inter) typeface
/// for maximum readability and a premium SaaS feel.
///
/// Scale follows Material 3 naming conventions with GoalSync-specific
/// weight and letter-spacing tuning.
abstract final class AppTypography {
  // ─────────────────────────────────────────────────────────────
  // Light Theme Text Theme
  // ─────────────────────────────────────────────────────────────

  static TextTheme get lightTextTheme => GoogleFonts.interTextTheme(
        _buildTextTheme(
          primary: AppColors.textPrimaryLight,
          secondary: AppColors.textSecondaryLight,
          tertiary: AppColors.textTertiaryLight,
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // Dark Theme Text Theme
  // ─────────────────────────────────────────────────────────────

  static TextTheme get darkTextTheme => GoogleFonts.interTextTheme(
        _buildTextTheme(
          primary: AppColors.textPrimaryDark,
          secondary: AppColors.textSecondaryDark,
          tertiary: AppColors.textTertiaryDark,
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // Internal Builder
  // ─────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      // ── Display ──────────────────────────────────────────────
      displayLarge: _style(
        size: 57,
        weight: FontWeight.w700,
        color: primary,
        letterSpacing: -1.5,
        height: 1.12,
      ),
      displayMedium: _style(
        size: 45,
        weight: FontWeight.w700,
        color: primary,
        letterSpacing: -1.0,
        height: 1.16,
      ),
      displaySmall: _style(
        size: 36,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.5,
        height: 1.22,
      ),

      // ── Headline ─────────────────────────────────────────────
      headlineLarge: _style(
        size: 32,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.5,
        height: 1.25,
      ),
      headlineMedium: _style(
        size: 28,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.25,
        height: 1.29,
      ),
      headlineSmall: _style(
        size: 24,
        weight: FontWeight.w600,
        color: primary,
        height: 1.33,
      ),

      // ── Title ────────────────────────────────────────────────
      titleLarge: _style(
        size: 20,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      titleMedium: _style(
        size: 16,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: _style(
        size: 14,
        weight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.1,
        height: 1.43,
      ),

      // ── Body ─────────────────────────────────────────────────
      bodyLarge: _style(
        size: 16,
        weight: FontWeight.w400,
        color: primary,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: _style(
        size: 14,
        weight: FontWeight.w400,
        color: secondary,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: _style(
        size: 12,
        weight: FontWeight.w400,
        color: tertiary,
        letterSpacing: 0.4,
        height: 1.33,
      ),

      // ── Label ────────────────────────────────────────────────
      labelLarge: _style(
        size: 14,
        weight: FontWeight.w500,
        color: primary,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: _style(
        size: 12,
        weight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: _style(
        size: 11,
        weight: FontWeight.w500,
        color: tertiary,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Style Factory
  // ─────────────────────────────────────────────────────────────

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0.0,
    double height = 1.0,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
  }
}
