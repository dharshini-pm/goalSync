import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/intelligence.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_service.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/onboarding/services/financial_profile_service.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';
import 'package:goalsync/features/transactions/services/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FinancialProfileService profileService;
  late GoalService goalService;
  late TransactionService transactionService;
  late GoalIntelligenceService goalIntelligenceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FinancialProfileService.resetForTesting();
    GoalService.resetForTesting();
    TransactionService.resetForTesting();
    GoalIntelligenceService.resetForTesting();

    profileService = FinancialProfileService.instance;
    goalService = GoalService.instance;
    transactionService = TransactionService.instance;
    goalIntelligenceService = GoalIntelligenceService.instance;

    await profileService.init();
    await goalService.init();
    await transactionService.init();
  });

  Future<void> setupUserProfile({
    required String userId,
    double monthlyIncome = 100000,
    double fixedExpenses = 40000,
    double variableExpenses = 20000,
    double loanEmi = 10000,
    double currentSavings = 50000,
  }) async {
    final profile = FinancialProfile(
      userId: userId,
      age: 29,
      occupation: 'Software Engineer',
      dependents: 0,
      monthlyIncome: monthlyIncome,
      incomeType: 'Salary',
      additionalIncome: 0,
      currentSavings: currentSavings,
      monthlyFixedExpenses: fixedExpenses,
      monthlyVariableExpenses: variableExpenses,
      existingLoanEmi: loanEmi,
      activeLoansCount: loanEmi > 0 ? 1 : 0,
      completedAt: DateTime(2026, 1, 1),
    );
    await profileService.saveProfile(profile);
  }

  group('Goal Intelligence and Transaction Pattern Integration Tests', () {
    // 1. Goal Intelligence snapshot includes transaction patterns
    test('1. Goal Intelligence snapshot includes transaction patterns', () async {
      const userId = 'user_with_patterns';
      await setupUserProfile(userId: userId);

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '450',
        type: TransactionType.debit,
        merchantName: 'SWIGGY*ORDER123',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 6, 1),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 2),
      );

      expect(snapshot.transactionPatterns, isNotNull);
      expect(snapshot.transactionPatterns!.totalTransactionCount, 1);
      expect(snapshot.totalTransactionCount, 1);
    });

    // 2. Empty transactions produce a valid empty pattern snapshot
    test('2. Empty transactions produce a valid empty pattern snapshot', () async {
      const userId = 'user_empty_tx';
      await setupUserProfile(userId: userId);

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 1, 1),
      );

      expect(snapshot.transactionPatterns, isNotNull);
      expect(snapshot.transactionPatterns!.totalTransactionCount, 0);
      expect(snapshot.transactionPatterns!.totalIncome, 0.0);
      expect(snapshot.transactionPatterns!.totalExpenses, 0.0);
      expect(snapshot.transactionPatterns!.categoryTotals, isEmpty);
      expect(snapshot.transactionPatterns!.merchantTotals, isEmpty);
      expect(snapshot.transactionPatterns!.recurringCandidates, isEmpty);
      expect(snapshot.totalTransactionCount, 0);
      expect(snapshot.totalTransactionExpenses, 0.0);
    });

    // 3. Transaction totals are correctly reflected
    test('3. Transaction totals are correctly reflected in GoalIntelligenceSnapshot', () async {
      const userId = 'user_totals_check';
      await setupUserProfile(userId: userId);

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '85000',
        type: TransactionType.credit,
        merchantName: 'Tech Corp Salary',
        category: TransactionCategories.salaryAndIncome,
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime(2026, 6, 1),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '1500',
        type: TransactionType.debit,
        merchantName: 'Swiggy',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 6, 5),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '3500',
        type: TransactionType.debit,
        merchantName: 'Amazon',
        category: TransactionCategories.shopping,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 6, 10),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 15),
      );

      expect(snapshot.totalTransactionCount, 3);
      expect(snapshot.totalTransactionIncome, 85000.0);
      expect(snapshot.totalTransactionExpenses, 5000.0);
      expect(snapshot.averageExpense, 2500.0);
      expect(snapshot.largestExpense, 3500.0);
    });

    // 4. Category totals are available through Goal Intelligence
    test('4. Category totals are available through Goal Intelligence', () async {
      const userId = 'user_categories';
      await setupUserProfile(userId: userId);

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '1200',
        type: TransactionType.debit,
        merchantName: 'Zomato',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 6, 2),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '1800',
        type: TransactionType.debit,
        merchantName: 'Swiggy',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 6, 4),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '600',
        type: TransactionType.debit,
        merchantName: 'Uber',
        category: TransactionCategories.transport,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 6, 6),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 10),
      );

      expect(
        snapshot.categoryTotals[TransactionCategories.foodAndDining],
        3000.0,
      );
      expect(
        snapshot.categoryTotals[TransactionCategories.transport],
        600.0,
      );
    });

    // 5. Merchant totals are available through Goal Intelligence
    test('5. Merchant totals are available through Goal Intelligence', () async {
      const userId = 'user_merchants';
      await setupUserProfile(userId: userId);

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '500',
        type: TransactionType.debit,
        merchantName: 'AMAZON PAY',
        category: TransactionCategories.shopping,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 6, 1),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '1500',
        type: TransactionType.debit,
        merchantName: 'Amazon.in',
        category: TransactionCategories.shopping,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 6, 3),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 5),
      );

      expect(snapshot.merchantTotals['Amazon'], 2000.0);
    });

    // 6. Recurring candidates are available through Goal Intelligence
    test('6. Recurring candidates are available through Goal Intelligence', () async {
      const userId = 'user_recurring';
      await setupUserProfile(userId: userId);

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '649',
        type: TransactionType.debit,
        merchantName: 'Netflix',
        category: TransactionCategories.entertainment,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 4, 1),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '649',
        type: TransactionType.debit,
        merchantName: 'Netflix.com',
        category: TransactionCategories.entertainment,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 5, 1),
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '649',
        type: TransactionType.debit,
        merchantName: 'Netflix Entertainment',
        category: TransactionCategories.entertainment,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 6, 1),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 2),
      );

      expect(snapshot.recurringCandidates.isNotEmpty, isTrue);
      final netflix = snapshot.recurringCandidates.firstWhere(
        (c) => c.merchant == 'Netflix',
      );
      expect(netflix.occurrenceCount, 3);
      expect(netflix.averageAmount, 649.0);
      expect(netflix.confidence, IntelligenceConfidence.high);
    });

    // 7. Existing financial state calculations remain unchanged
    test('7. Existing financial state calculations remain completely unchanged', () async {
      const userId = 'user_fin_state';
      await setupUserProfile(
        userId: userId,
        monthlyIncome: 120000,
        fixedExpenses: 50000,
        variableExpenses: 25000,
        loanEmi: 15000,
        currentSavings: 80000,
      );

      await transactionService.createTransaction(
        userId: userId,
        amountRaw: '2000',
        type: TransactionType.debit,
        merchantName: 'Swiggy',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 6, 1),
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 10),
      );

      // Income = 120,000, Expenses = 50,000 + 25,000 + 15,000 = 90,000, Surplus = 30,000
      expect(snapshot.financialState.totalMonthlyIncome, 120000.0);
      expect(snapshot.financialState.totalMonthlyExpenses, 90000.0);
      expect(snapshot.financialState.monthlySurplus, 30000.0);
      expect(snapshot.financialState.currentSavings, 80000.0);
      expect(snapshot.financialState.savingsRate, closeTo(25.0, 0.01));
      expect(snapshot.financialState.isDeficit, isFalse);
    });

    // 8. Existing goal feasibility calculations remain unchanged
    test('8. Existing goal feasibility calculations remain completely unchanged', () async {
      const userId = 'user_feasibility';
      await setupUserProfile(userId: userId); // 30,000 monthly surplus

      await goalService.createGoal(
        userId: userId,
        name: 'Emergency Fund Goal',
        category: GoalCategory.emergencyFund,
        targetAmountRaw: '100000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1), // 10 months -> 10,000/mo (33% of surplus)
        priority: GoalPriority.essential,
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 1, 1),
      );

      expect(snapshot.totalGoals, 1);
      expect(snapshot.achievableGoals, 1);
      expect(snapshot.overallGoalCapacityStatus, 'healthy');
      expect(snapshot.goalFeasibilityResults.length, 1);
      expect(
        snapshot.goalFeasibilityResults.first.status,
        GoalFeasibilityStatus.comfortable,
      );
      expect(
        snapshot.goalFeasibilityResults.first.requiredMonthlyContribution,
        10000.0,
      );
    });

    // 9. Existing conflict detection remains unchanged
    test('9. Existing conflict detection remains completely unchanged', () async {
      const userId = 'user_conflict';
      // Surplus = 10,000
      await setupUserProfile(
        userId: userId,
        monthlyIncome: 60000,
        fixedExpenses: 30000,
        variableExpenses: 15000,
        loanEmi: 5000,
      );

      // Goal requires 25,000/month (exceeds surplus of 10,000)
      await goalService.createGoal(
        userId: userId,
        name: 'Huge Car Downpayment',
        category: GoalCategory.vehicle,
        targetAmountRaw: '250000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1), // 10 months from Jan -> 25,000/mo
        priority: GoalPriority.important,
      );

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 1, 1),
      );

      expect(snapshot.overallGoalCapacityStatus, 'conflicted');
      expect(snapshot.conflicts.isNotEmpty, isTrue);
      expect(
        snapshot.conflicts.any(
          (c) => c.type == ConflictType.singleGoalSurplusExceeded,
        ),
        isTrue,
      );
    });

    // 10. Original TransactionModel objects remain unchanged
    test('10. Original TransactionModel objects remain completely unchanged', () async {
      const userId = 'user_immutability';
      await setupUserProfile(userId: userId);

      final res = await transactionService.createTransaction(
        userId: userId,
        amountRaw: '450.00',
        type: TransactionType.debit,
        merchantName: 'SWIGGY*ORDER123',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        notes: 'Immutable check',
        dateTime: DateTime(2026, 6, 1),
      );

      final tx = res.transaction!;
      final txJsonBefore = tx.toJson();

      final snapshot = await goalIntelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 6, 2),
      );

      final userTransactions = transactionService.getTransactionsForUser(userId);
      expect(userTransactions.isNotEmpty, isTrue);
      final storedTx = userTransactions.firstWhere((t) => t.id == tx.id);
      expect(storedTx.toJson(), txJsonBefore);
      expect(storedTx.merchantName, 'SWIGGY*ORDER123');
      expect(storedTx.amount, 450.0);
      expect(snapshot.merchantTotals['Swiggy'], 450.0);
    });
  });
}
