import 'package:flutter/material.dart';
import 'core/core.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/auth/services/auth_service.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  runApp(const GoalSyncApp());
}

/// Root application widget for GoalSync.
///
/// Wires the centralized [AppTheme] into [MaterialApp], supports Light/Dark/System
/// modes, and automatically routes based on authentication state:
/// - Authenticated  -> [DashboardPage]
/// - Unauthenticated -> [WelcomePage]
///
/// Financial Onboarding is accessed exclusively via the Dashboard.
class GoalSyncApp extends StatelessWidget {
  final Widget? home;

  const GoalSyncApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService.instance.isLoggedIn;
    final Widget initialScreen =
        isAuthenticated ? const DashboardPage() : const WelcomePage();

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // ── Root ───────────────────────────────────────────────
      home: home ?? initialScreen,
    );
  }
}
