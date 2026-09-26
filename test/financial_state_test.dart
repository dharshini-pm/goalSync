import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/services/auth_service.dart';
import 'package:goalsync/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:goalsync/features/financial_state/presentation/pages/financial_state_page.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_service.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/onboarding/services/financial_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinancialProfile makeProfile({
  String userId = 'user_1',
  double monthlyIncome = 80000,
  double additionalIncome = 10000,
  double currentSavings = 200000,
  double fixedExpenses = 20000,
  double variableExpenses = 15000,
  double loanEmi = 5000,
}) {
  return FinancialProfile(
    userId: userId,
    age: 30,
    occupation: 'Engineer',
    dependents: 2,
    monthlyIncome: monthlyIncome,
    incomeType: 'Salary',
    additionalIncome: additionalIncome,
    currentSavings: currentSavings,
    monthlyFixedExpenses: fixedExpenses,
    monthlyVariableExpenses: variableExpenses,
    existingLoanEmi: loanEmi,
    activeLoansCount: 1,
    completedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetForTesting();
    FinancialProfileService.resetForTesting();
    GoalService.resetForTesting();
    await AuthService.instance.init();
    await FinancialProfileService.instance.init();
    await GoalService.instance.init();
  });

  // Pure model calculation tests
  group('FinancialProfile model calculations', () {
    test('totalMonthlyIncome = primary + additional', () {
      final p = makeProfile(monthlyIncome: 80000, additionalIncome: 10000);
      expect(p.totalMonthlyIncome, 90000);
    });

    test('totalMonthlyExpenses = fixed + variable + loan', () {
      final p = makeProfile(
          fixedExpenses: 20000, variableExpenses: 15000, loanEmi: 5000);
      expect(p.totalMonthlyExpenses, 40000);
    });

    test('monthly surplus calculation', () {
      final p = makeProfile(
        monthlyIncome: 80000,
        additionalIncome: 10000,
        fixedExpenses: 20000,
        variableExpenses: 15000,
        loanEmi: 5000,
      );
      final surplus = p.totalMonthlyIncome - p.totalMonthlyExpenses;
      expect(surplus, 50000);
    });

    test('monthly deficit when expenses exceed income', () {
      final p = makeProfile(
        monthlyIncome: 20000,
        additionalIncome: 0,
        fixedExpenses: 15000,
        variableExpenses: 10000,
        loanEmi: 5000,
      );
      final surplus = p.totalMonthlyIncome - p.totalMonthlyExpenses;
      expect(surplus, lessThan(0));
    });

    test('zero values are valid and treated as zero, not missing', () {
      final p = makeProfile(
        monthlyIncome: 50000,
        additionalIncome: 0,
        fixedExpenses: 0,
        variableExpenses: 0,
        loanEmi: 0,
      );
      expect(p.additionalIncome, 0);
      expect(p.totalMonthlyExpenses, 0);
      expect(p.totalMonthlyIncome, 50000);
    });

    test('profile serialisation roundtrip preserves all values', () {
      final p = makeProfile();
      final restored = FinancialProfile.fromJson(p.toJson());
      expect(restored.monthlyIncome, p.monthlyIncome);
      expect(restored.additionalIncome, p.additionalIncome);
      expect(restored.currentSavings, p.currentSavings);
      expect(restored.monthlyFixedExpenses, p.monthlyFixedExpenses);
      expect(restored.monthlyVariableExpenses, p.monthlyVariableExpenses);
      expect(restored.existingLoanEmi, p.existingLoanEmi);
    });
  });

  // Dashboard Financial State card widget tests
  group('Dashboard Financial State card', () {
    testWidgets('shows empty state when onboarding not completed',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Test User',
        phone: '9000000001',
        countryCode: '+91',
        email: 'test@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(home: DashboardPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('FINANCIAL STATE'), findsOneWidget);
      expect(find.text('No financial data connected yet.'), findsOneWidget);
      expect(find.text('Set Up Financial Profile'), findsOneWidget);
    });

    testWidgets('shows financial summary when onboarding completed',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Test User 2',
        phone: '9000000002',
        countryCode: '+91',
        email: 'test2@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );

      await tester.pumpWidget(
        const MaterialApp(home: DashboardPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('FINANCIAL STATE'), findsOneWidget);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Outflow'), findsWidgets);
      expect(find.text('No financial data connected yet.'), findsNothing);
    });

    testWidgets('tapping summary card opens FinancialStatePage',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Test User 3',
        phone: '9000000003',
        countryCode: '+91',
        email: 'test3@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );

      await tester.pumpWidget(
        const MaterialApp(home: DashboardPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap to view detailed financial state'));
      await tester.pumpAndSettle();

      expect(find.byType(FinancialStatePage), findsOneWidget);
    });
  });

  // FinancialStatePage widget tests
  group('FinancialStatePage', () {
    testWidgets('shows empty state when no profile', (tester) async {
      await AuthService.instance.register(
        fullName: 'No Profile',
        phone: '9000000004',
        countryCode: '+91',
        email: 'noprofile@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Financial Data Yet'), findsOneWidget);
      expect(find.text('Set Up Financial Profile'), findsOneWidget);
    });

    testWidgets('shows all section headers when profile exists',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Has Profile',
        phone: '9000000005',
        countryCode: '+91',
        email: 'hasprofile@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('FINANCIAL OVERVIEW'), findsOneWidget);
      expect(find.text('EXPENSE BREAKDOWN'), findsOneWidget);
      expect(find.text('FINANCIAL SUMMARY'), findsOneWidget);
      expect(find.text('GOAL COMMITMENTS'), findsOneWidget);
    });

    testWidgets('shows correct stat card labels', (tester) async {
      await AuthService.instance.register(
        fullName: 'Overview User',
        phone: '9000000006',
        countryCode: '+91',
        email: 'overview@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId, monthlyIncome: 80000, additionalIncome: 10000),
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Income'), findsWidgets);
      expect(find.text('Monthly Outflow'), findsWidgets);
      expect(find.text('Monthly Surplus'), findsWidgets);
      expect(find.text('Current Savings'), findsWidgets);
    });

    testWidgets('shows expense breakdown labels', (tester) async {
      await AuthService.instance.register(
        fullName: 'Expense User',
        phone: '9000000007',
        countryCode: '+91',
        email: 'expense@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fixed Expenses'), findsWidgets);
      expect(find.text('Variable Expenses'), findsWidgets);
      expect(find.text('Loan / EMI'), findsWidgets);
    });

    testWidgets('shows no-goals message when goals list is empty',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'No Goals User',
        phone: '9000000008',
        countryCode: '+91',
        email: 'nogoals@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No goals created yet. Add goals from the Goals tab.'),
        findsOneWidget,
      );
    });

    testWidgets('shows goal name in Goal Commitments section',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Goals User',
        phone: '9000000009',
        countryCode: '+91',
        email: 'goalsuser@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(
        makeProfile(userId: userId),
      );
      await GoalService.instance.createGoal(
        userId: userId,
        name: 'Europe Trip',
        category: GoalCategory.travel,
        targetAmountRaw: '200000',
        currentAmountRaw: '50000',
        targetDate: DateTime.now().add(const Duration(days: 365)),
        priority: GoalPriority.important,
      );

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Europe Trip'), findsOneWidget);
    });

    testWidgets('shows Monthly Deficit label when expenses exceed income',
        (tester) async {
      await AuthService.instance.register(
        fullName: 'Deficit User',
        phone: '9000000010',
        countryCode: '+91',
        email: 'deficit@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;
      await FinancialProfileService.instance.saveProfile(makeProfile(
        userId: userId,
        monthlyIncome: 20000,
        additionalIncome: 0,
        fixedExpenses: 15000,
        variableExpenses: 10000,
        loanEmi: 5000,
      ));

      await tester.pumpWidget(
        const MaterialApp(home: FinancialStatePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Deficit'), findsOneWidget);
    });
  });
}
