/// GoalSync application-wide string constants.
///
/// Centralises all non-localised strings so that names, routes,
/// and asset paths have a single source of truth.
abstract final class AppStrings {
  // ─────────────────────────────────────────────────────────────
  // App Identity
  // ─────────────────────────────────────────────────────────────

  static const String appName = 'GoalSync';
  static const String appTagline = 'AI-Powered Financial Intelligence';
  static const String appVersion = '1.0.0';

  // ─────────────────────────────────────────────────────────────
  // Named Routes (populated as screens are built)
  // ─────────────────────────────────────────────────────────────

  static const String routeRoot = '/';

  // ─────────────────────────────────────────────────────────────
  // Asset Paths
  // ─────────────────────────────────────────────────────────────

  static const String assetImagesDir = 'assets/images/';
  static const String assetIconsDir = 'assets/icons/';
  static const String assetFontsDir = 'assets/fonts/';
}
