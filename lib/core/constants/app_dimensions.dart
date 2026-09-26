/// GoalSync centralized spacing, sizing, radius, and layout constants.
///
/// Use these instead of magic numbers to keep the UI consistent and
/// easy to update globally.
abstract final class AppDimensions {
  // ─────────────────────────────────────────────────────────────
  // Spacing (8-pt grid system)
  // ─────────────────────────────────────────────────────────────

  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;
  static const double space96 = 96.0;

  // ─────────────────────────────────────────────────────────────
  // Border Radius
  // ─────────────────────────────────────────────────────────────

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radius3xl = 32.0;
  static const double radiusFull = 9999.0;

  // ─────────────────────────────────────────────────────────────
  // Icon Sizes
  // ─────────────────────────────────────────────────────────────

  static const double iconXs = 14.0;
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ─────────────────────────────────────────────────────────────
  // Elevation
  // ─────────────────────────────────────────────────────────────

  static const double elevationNone = 0.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // ─────────────────────────────────────────────────────────────
  // Animation Durations (ms)
  // ─────────────────────────────────────────────────────────────

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);

  // ─────────────────────────────────────────────────────────────
  // Responsive Breakpoints
  // ─────────────────────────────────────────────────────────────

  /// Mobile breakpoint max width.
  static const double breakpointMobile = 600.0;

  /// Tablet breakpoint max width.
  static const double breakpointTablet = 1024.0;

  /// Desktop breakpoint (anything above tablet).
  static const double breakpointDesktop = 1440.0;

  // ─────────────────────────────────────────────────────────────
  // Content Constraints
  // ─────────────────────────────────────────────────────────────

  /// Maximum content width for wide screens.
  static const double maxContentWidth = 480.0;

  /// Standard horizontal page padding.
  static const double pagePaddingH = space24;

  /// Standard vertical page padding.
  static const double pagePaddingV = space24;
}
