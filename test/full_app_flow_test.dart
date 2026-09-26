import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/presentation/pages/login_page.dart';
import 'package:goalsync/features/auth/services/auth_service.dart';
import 'package:goalsync/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:goalsync/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetForTesting();
    await AuthService.instance.init();
  });

  group('Complete GoalSync App Flows', () {
    testWidgets('Login with wrong password shows error and remains on Login',
        (WidgetTester tester) async {
      // Register existing user
      await AuthService.instance.register(
        fullName: 'Karan Mehra',
        phone: '9876501234',
        countryCode: '+91',
        email: 'karan@example.com',
        password: 'Password123',
      );
      // Simulate logged out state
      await AuthService.instance.logout();

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter correct email but wrong password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter email or phone number'),
        'karan@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'WrongPassword1!',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // Expect error banner & remain on LoginPage
      expect(find.text('Invalid email/phone or password.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
    });

    testWidgets('Login with correct credentials navigates to Dashboard',
        (WidgetTester tester) async {
      await AuthService.instance.register(
        fullName: 'Karan Mehra',
        phone: '9876501234',
        countryCode: '+91',
        email: 'karan@example.com',
        password: 'Password123',
      );
      await AuthService.instance.logout();

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter email or phone number'),
        'karan@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'Password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Karan Mehra'), findsOneWidget);
      expect(find.byType(DashboardPage), findsOneWidget);
    });

    testWidgets('Logout flow: Dashboard -> Profile -> Logout -> Login',
        (WidgetTester tester) async {
      await AuthService.instance.register(
        fullName: 'Karan Mehra',
        phone: '9876501234',
        countryCode: '+91',
        email: 'karan@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Profile tab
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      // Tap Logout button
      final logoutBtn = find.text('Logout');
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Are you sure you want to log out of GoalSync on this device?'), findsOneWidget);

      // Tap confirm "Log Out" in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();

      // Verifies redirected to Login Page
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);

      // Verifies session state is cleared
      expect(AuthService.instance.isLoggedIn, isFalse);
    });

    testWidgets('Restart application while logged in automatically opens Dashboard',
        (WidgetTester tester) async {
      // Simulate persisted login session in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'goalsync_is_logged_in': true,
        'goalsync_current_user_id': 'usr_test_123',
        'goalsync_registered_users': [
          '{"id":"usr_test_123","fullName":"Anita Roy","phone":"9811223344","countryCode":"+91","email":"anita@example.com","passwordHash":"hash123","createdAt":"2026-01-01T00:00:00.000"}'
        ],
      });

      AuthService.resetForTesting();
      await AuthService.instance.init();

      expect(AuthService.instance.isLoggedIn, isTrue);
      expect(AuthService.instance.currentUser?.fullName, 'Anita Roy');

      // Launch root GoalSyncApp
      await tester.pumpWidget(const GoalSyncApp());
      await tester.pumpAndSettle();

      // Automatically shows DashboardPage
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.text('Welcome back, Anita Roy'), findsOneWidget);
    });

    testWidgets('Restart application after logout opens WelcomePage',
        (WidgetTester tester) async {
      // Session is false
      SharedPreferences.setMockInitialValues({
        'goalsync_is_logged_in': false,
      });

      AuthService.resetForTesting();
      await AuthService.instance.init();

      expect(AuthService.instance.isLoggedIn, isFalse);

      await tester.pumpWidget(const GoalSyncApp());
      await tester.pump();

      // Shows WelcomePage
      expect(find.text('Your money changes.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
    });
  });
}
