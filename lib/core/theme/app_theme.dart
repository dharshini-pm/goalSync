import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_typography.dart';

/// GoalSync centralized theme configuration.
///
/// Provides [lightTheme] and [darkTheme] that share the same brand identity
/// (Deep Navy, Electric Cyan, Mint) while feeling native to each brightness.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ThemeMode.system,
/// )
/// ```
abstract final class AppTheme {
  // ─────────────────────────────────────────────────────────────
  // Color Schemes
  // ─────────────────────────────────────────────────────────────

  static ColorScheme get _lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        // Primary
        primary: AppColors.electricCyan,
        onPrimary: AppColors.deepNavy,
        primaryContainer: AppColors.cyanGlow,
        onPrimaryContainer: AppColors.deepNavy,
        // Secondary
        secondary: AppColors.mint,
        onSecondary: AppColors.deepNavy,
        secondaryContainer: AppColors.mintGlow,
        onSecondaryContainer: AppColors.deepNavy,
        // Tertiary
        tertiary: AppColors.deepNavy,
        onTertiary: AppColors.lightSurface,
        tertiaryContainer: AppColors.lightSurfaceVariant,
        onTertiaryContainer: AppColors.deepNavy,
        // Error
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: Color(0xFFFFDADE),
        onErrorContainer: Color(0xFF410014),
        // Surface
        surface: AppColors.lightSurface,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.textSecondaryLight,
        // Outline
        outline: Color(0xFFBBD0E0),
        outlineVariant: Color(0xFFD8E8F2),
        // Misc
        shadow: AppColors.deepNavy,
        scrim: AppColors.deepNavy,
        inverseSurface: AppColors.deepNavy,
        onInverseSurface: AppColors.textPrimaryDark,
        inversePrimary: AppColors.electricCyan,
      );

  static ColorScheme get _darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        // Primary
        primary: AppColors.electricCyan,
        onPrimary: AppColors.deepNavy,
        primaryContainer: AppColors.navyMid,
        onPrimaryContainer: AppColors.electricCyan,
        // Secondary
        secondary: AppColors.mint,
        onSecondary: AppColors.deepNavy,
        secondaryContainer: AppColors.navyMid,
        onSecondaryContainer: AppColors.mint,
        // Tertiary
        tertiary: AppColors.lightSurface,
        onTertiary: AppColors.deepNavy,
        tertiaryContainer: AppColors.navyLight,
        onTertiaryContainer: AppColors.textPrimaryDark,
        // Error
        error: AppColors.error,
        onError: AppColors.deepNavy,
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDADE),
        // Surface
        surface: AppColors.darkSurface,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurfaceVariant: AppColors.textSecondaryDark,
        // Outline
        outline: AppColors.navyBorder,
        outlineVariant: AppColors.navyMid,
        // Misc
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.lightSurface,
        onInverseSurface: AppColors.textPrimaryLight,
        inversePrimary: AppColors.cyanDark,
      );

  // ─────────────────────────────────────────────────────────────
  // Light Theme
  // ─────────────────────────────────────────────────────────────

  static ThemeData get lightTheme => _buildTheme(
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: AppColors.lightScaffold,
        textTheme: AppTypography.lightTextTheme,
      );

  // ─────────────────────────────────────────────────────────────
  // Dark Theme
  // ─────────────────────────────────────────────────────────────

  static ThemeData get darkTheme => _buildTheme(
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: AppColors.darkScaffold,
        textTheme: AppTypography.darkTextTheme,
      );

  // ─────────────────────────────────────────────────────────────
  // Internal Theme Builder
  // ─────────────────────────────────────────────────────────────

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required TextTheme textTheme,
  }) {
    final bool isLight = colorScheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:
            isLight ? AppColors.lightScaffold : AppColors.deepNavy,
        foregroundColor:
            isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: isLight
            ? AppColors.electricCyan.withAlpha(30)
            : AppColors.electricCyan.withAlpha(20),
        centerTitle: false,
        titleTextStyle: isLight
            ? AppTypography.lightTextTheme.titleLarge
            : AppTypography.darkTextTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Card ─────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isLight ? AppColors.lightSurface : AppColors.darkSurface,
        elevation: AppDimensions.elevationSm,
        shadowColor: isLight
            ? AppColors.deepNavy.withAlpha(18)
            : Colors.black.withAlpha(60),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(
            color: isLight
                ? const Color(0xFFD8E8F2)
                : AppColors.navyBorder,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricCyan,
          foregroundColor: AppColors.deepNavy,
          disabledBackgroundColor: isLight
              ? const Color(0xFFCCE9F0)
              : AppColors.navyBorder,
          disabledForegroundColor: isLight
              ? AppColors.textTertiaryLight
              : AppColors.textTertiaryDark,
          elevation: AppDimensions.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Filled Button ────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricCyan,
          foregroundColor: AppColors.deepNavy,
          elevation: AppDimensions.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Text Button ──────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricCyan,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button ──────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricCyan,
          side: const BorderSide(color: AppColors.electricCyan, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.lightSurfaceVariant
            : AppColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isLight
                ? const Color(0xFFD8E8F2)
                : AppColors.navyBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isLight
                ? const Color(0xFFD8E8F2)
                : AppColors.navyBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.electricCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: isLight
            ? AppTypography.lightTextTheme.bodyMedium
            : AppTypography.darkTextTheme.bodyMedium,
        labelStyle: isLight
            ? AppTypography.lightTextTheme.bodyMedium
            : AppTypography.darkTextTheme.bodyMedium,
      ),

      // ── Chip ─────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? AppColors.lightSurfaceVariant
            : AppColors.darkSurfaceVariant,
        selectedColor: AppColors.cyanGlow,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(
          color: isLight ? const Color(0xFFD8E8F2) : AppColors.navyBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space6,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isLight ? const Color(0xFFD8E8F2) : AppColors.navyBorder,
        thickness: 1,
        space: 1,
      ),

      // ── Navigation Bar ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        indicatorColor: AppColors.cyanGlow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.electricCyan);
          }
          return IconThemeData(
            color: isLight
                ? AppColors.textSecondaryLight
                : AppColors.textSecondaryDark,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base =
              isLight ? AppTypography.lightTextTheme : AppTypography.darkTextTheme;
          if (states.contains(WidgetState.selected)) {
            return base.labelSmall
                ?.copyWith(color: AppColors.electricCyan, fontWeight: FontWeight.w600);
          }
          return base.labelSmall;
        }),
        elevation: AppDimensions.elevationSm,
        surfaceTintColor: Colors.transparent,
        shadowColor: isLight
            ? AppColors.deepNavy.withAlpha(18)
            : Colors.black.withAlpha(60),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        selectedItemColor: AppColors.electricCyan,
        unselectedItemColor: isLight
            ? AppColors.textSecondaryLight
            : AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationLg,
      ),

      // ── Floating Action Button ────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.electricCyan,
        foregroundColor: AppColors.deepNavy,
        elevation: AppDimensions.elevationMd,
        shape: CircleBorder(),
      ),

      // ── Dialog ───────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        elevation: AppDimensions.elevationXl,
        shadowColor:
            isLight ? AppColors.deepNavy.withAlpha(30) : Colors.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        ),
        titleTextStyle: isLight
            ? AppTypography.lightTextTheme.titleLarge
            : AppTypography.darkTextTheme.titleLarge,
        contentTextStyle: isLight
            ? AppTypography.lightTextTheme.bodyMedium
            : AppTypography.darkTextTheme.bodyMedium,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.elevationXl,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radius2xl),
          ),
        ),
      ),

      // ── Switch ───────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.deepNavy;
          }
          return isLight ? AppColors.textTertiaryLight : AppColors.navyBorder;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricCyan;
          }
          return isLight
              ? AppColors.lightSurfaceVariant
              : AppColors.darkSurfaceVariant;
        }),
      ),

      // ── Progress Indicator ───────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.electricCyan,
        linearTrackColor: AppColors.cyanGlow,
        circularTrackColor: AppColors.cyanGlow,
      ),

      // ── Snack Bar ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isLight ? AppColors.deepNavy : AppColors.navyLight,
        contentTextStyle: AppTypography.darkTextTheme.bodyMedium,
        actionTextColor: AppColors.electricCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        elevation: AppDimensions.elevationLg,
      ),

      // ── Page Transitions ─────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
