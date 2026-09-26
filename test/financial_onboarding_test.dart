import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/services/auth_service.dart';
import 'package:goalsync/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/onboarding/presentation/pages/financial_onboarding_page.dart';
import 'package:goalsync/features/onboarding/services/financial_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetForTesting();
    FinancialProfileService.resetForTesting();
    await AuthService.instance.init();
    await FinancialProfileService.instance.init();
  });

  group('Financial Profile Model & Service Tests', () {
    test('Model serializes and deserializes correctly', () {
      final now = DateTime.now();
      final profile = FinancialProfile(
        userId: 'usr_123',
        age: 30,
        occupation: 'Salaried Employee',
        dependents: 2,
        monthlyIncome: 100000.0,
        incomeType: 'Salary',
        additionalIncome: 15000.0,
        currentSavings: 500000.0,
        monthlyFixedExpenses: 40000.0,
        monthlyVariableExpenses: 25000.0,
        existingLoanEmi: 12000.0,
        activeLoansCount: 1,
        completedAt: now,
      );

      final jsonStr = profile.toJson();
      final restored = FinancialProfile.fromJson(jsonStr);

      expect(restored.userId, 'usr_123');
      expect(restored.age, 30);
      expect(restored.occupation, 'Salaried Employee');
      expect(restored.dependents, 2);
      expect(restored.monthlyIncome, 100000.0);
      expect(restored.totalMonthlyIncome, 115000.0);
      expect(restored.totalMonthlyExpenses, 77000.0);
      expect(restored.isCompleted, isTrue);
    });

    test('FinancialProfileService saves and retrieves user profile', () async {
      final service = FinancialProfileService.instance;
      expect(service.isOnboardingCompleted('usr_456'), isFalse);

      final profile = FinancialProfile(
        userId: 'usr_456',
        age: 26,
        occupation: 'Freelancer / Consultant',
        dependents: 0,
        monthlyIncome: 70000.0,
        incomeType: 'Freelance',
        currentSavings: 150000.0,
        monthlyFixedExpenses: 25000.0,
        monthlyVariableExpenses: 15000.0,
        existingLoanEmi: 0.0,
        activeLoansCount: 0,
        completedAt: DateTime.now(),
      );

      final saved = await service.saveProfile(profile);
      expect(saved, isTrue);
      expect(service.isOnboardingCompleted('usr_456'), isTrue);

      final loaded = service.getProfile('usr_456');
      expect(loaded, isNotNull);
      expect(loaded!.age, 26);
      expect(loaded.monthlyIncome, 70000.0);
    });
  });

  group('Financial Onboarding UI & Validation Tests', () {
    testWidgets('Step 1 rejects invalid age and allows valid submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialOnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue with empty age
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Expect age error
      expect(find.text('Age is required.'), findsOneWidget);

      // Enter invalid age (e.g. 12)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 28'),
        '12',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter a valid age between 18 and 100.'),
        findsOneWidget,
      );

      // Enter valid age (28)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 28'),
        '28',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Now should advance to Step 2
      expect(find.text('Your monthly income'), findsOneWidget);
    });

    testWidgets('Step 2 rejects invalid income', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialOnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Pass Step 1
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 28'),
        '28',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 with empty income
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly income is required.'), findsOneWidget);

      // Enter valid income
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 85000'),
        '65000',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Now should advance to Step 3
      expect(find.text('Current financial position'), findsOneWidget);
    });

    testWidgets('Step 4 Review allows editing previous step',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialOnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 28'),
        '35',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 85000'),
        '95000',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 250000'),
        '400000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 35000'),
        '40000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 20000'),
        '25000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 15000 (or 0)'),
        '10000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 1 (or 0)'),
        '1',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4 Review
      expect(find.text('Review your profile'), findsOneWidget);
      expect(find.text('35 years'), findsOneWidget);

      // Tap "Edit" on the first card (About You)
      final editButtons = find.text('Edit');
      expect(editButtons, findsNWidgets(3));
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Should jump back to Step 1
      expect(find.text('Tell us about yourself'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('Completing onboarding navigates to Dashboard',
        (WidgetTester tester) async {
      // Set active user session
      await AuthService.instance.register(
        fullName: 'Sameer Joshi',
        phone: '9876541234',
        countryCode: '+91',
        email: 'sameer@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialOnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 28'),
        '31',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 85000'),
        '90000',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 250000'),
        '500000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 35000'),
        '30000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 20000'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 15000 (or 0)'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 1 (or 0)'),
        '0',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Finish Setup
      await tester.tap(find.text('Finish Setup'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.text('Welcome back, Sameer Joshi'), findsOneWidget);

      // Verify onboarding flag is set
      expect(
        FinancialProfileService.instance.isOnboardingCompleted(
          AuthService.instance.currentUser?.id,
        ),
        isTrue,
      );
    });
  });
}
