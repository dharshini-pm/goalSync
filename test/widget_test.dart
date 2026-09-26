import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/presentation/pages/sign_up_page.dart';
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

  testWidgets('GoalSync initial launch displays Welcome Page with branding & CTAs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GoalSyncApp());
    await tester.pump();

    // Verify Brand
    expect(find.text('GoalSync'), findsWidgets);
    expect(find.text('Your money changes.'), findsOneWidget);
    expect(find.text('Your goals should adapt.'), findsOneWidget);

    // Verify Financial Intelligence pipeline steps
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Financial State'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Conflicts'), findsOneWidget);
    expect(find.text('Scenarios'), findsOneWidget);

    // Verify CTAs
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('Get Started navigates to SignUpPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GoalSyncApp());
    await tester.pump();

    final getStartedButton = find.text('Get Started');
    await tester.ensureVisible(getStartedButton);
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('I already have an account navigates to LoginPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GoalSyncApp());
    await tester.pump();

    final loginCta = find.text('I already have an account');
    await tester.ensureVisible(loginCta);
    await tester.tap(loginCta);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email or Phone Number'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Full flow: Sign Up -> Dashboard with real name & 4 empty cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Enter full name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Rahul Sharma'),
      'Aditya Verma',
    );

    // Enter phone
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. 9876543210'),
      '9876543210',
    );

    // Enter email
    await tester.enterText(
      find.widgetWithText(TextFormField, 'name@example.com'),
      'aditya@example.com',
    );

    // Enter password
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create strong password'),
      'Password123',
    );

    // Enter confirm password
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Re-enter password'),
      'Password123',
    );

    await tester.pump();

    // Tap Create Account
    final createAccountBtn = find.text('Create Account');
    await tester.ensureVisible(createAccountBtn);
    await tester.tap(createAccountBtn);
    await tester.pumpAndSettle();

    // Verify on Dashboard with real user name
    expect(find.text('Welcome back, Aditya Verma'), findsOneWidget);
    expect(find.text('aditya@example.com'), findsOneWidget);

    // Verify 4 genuine empty state cards
    expect(find.text('FINANCIAL STATE'), findsOneWidget);
    expect(find.text('No financial data connected yet.'), findsOneWidget);
    expect(find.text('Set Up Financial Profile'), findsOneWidget);

    expect(find.text('YOUR GOALS'), findsOneWidget);
    expect(find.text('No financial goals created yet.'), findsOneWidget);
    expect(find.text('Create Your First Goal'), findsOneWidget);

    expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
    expect(find.text('No transactions available yet.'), findsOneWidget);

    expect(find.text('GOAL CONFLICTS'), findsOneWidget);
    expect(find.text('No conflicts detected.'), findsOneWidget);

    // Verify NO fake financial numbers or transactions exist
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('Bottom navigation tabs switch and Profile displays Logout',
      (WidgetTester tester) async {
    // Register user first
    await AuthService.instance.register(
      fullName: 'Priya Patel',
      phone: '9876543210',
      countryCode: '+91',
      email: 'priya@example.com',
      password: 'Password123',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Goals tab
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Goals module coming next'), findsOneWidget);

    // Switch to Activity tab
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity module coming next'), findsOneWidget);

    // Switch to AI tab
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('AI Copilot module coming next'), findsOneWidget);

    // Switch to Profile tab
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Priya Patel'), findsWidgets);
    expect(find.text('priya@example.com'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
