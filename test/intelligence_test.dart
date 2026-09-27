import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/intelligence.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';

void main() {
  group('Financial State Engine Tests', () {
    test('income calculation - combines primary salary and additional income', () {
      final total = FinancialStateEngine.calculateTotalIncome(
        monthlyIncome: 85000,
        additionalIncome: 15000,
      );
      expect(total, 100000.0);
    });

    test('income calculation - handles zero additional income', () {
      final total = FinancialStateEngine.calculateTotalIncome(
        monthlyIncome: 75000,
        additionalIncome: 0,
      );
      expect(total, 75000.0);
    });

    test('expense calculation - combines fixed, variable, and EMI commitments', () {
      final total = FinancialStateEngine.calculateTotalExpenses(
        fixedExpenses: 30000,
        variableExpenses: 18000,
        loanEmi: 12000,
      );
      expect(total, 60000.0);
    });

    test('expense calculation - handles zero loan EMI correctly', () {
      final total = FinancialStateEngine.calculateTotalExpenses(
        fixedExpenses: 25000,
        variableExpenses: 15000,
        loanEmi: 0,
      );
      expect(total, 40000.0);
    });

    test('surplus calculation - positive cash flow surplus', () {
      final surplus = FinancialStateEngine.calculateMonthlySurplus(
        totalIncome: 100000,
        totalExpenses: 65000,
      );
      expect(surplus, 35000.0);
    });

    test('surplus calculation - cash flow deficit when expenses exceed income', () {
      final surplus = FinancialStateEngine.calculateMonthlySurplus(
        totalIncome: 50000,
        totalExpenses: 62000,
      );
      expect(surplus, -12000.0);
    });

    test('surplus calculation - exact break-even returns zero', () {
      final surplus = FinancialStateEngine.calculateMonthlySurplus(
        totalIncome: 60000,
        totalExpenses: 60000,
      );
      expect(surplus, 0.0);
    });

    test('savings rate calculation - standard positive rate', () {
      final rate = FinancialStateEngine.calculateSavingsRate(
        totalIncome: 100000,
        monthlySurplus: 35000,
      );
      expect(rate, 35.0);

      final fraction = FinancialStateEngine.calculateSavingsRateFraction(
        totalIncome: 100000,
        monthlySurplus: 35000,
      );
      expect(fraction, 0.35);
    });

    test('savings rate calculation - deficit or zero income yields 0.0%', () {
      expect(
        FinancialStateEngine.calculateSavingsRate(
          totalIncome: 50000,
          monthlySurplus: -10000,
        ),
        0.0,
      );
      expect(
        FinancialStateEngine.calculateSavingsRate(
          totalIncome: 0,
          monthlySurplus: 10000,
        ),
        0.0,
      );
    });

    test('available monthly amount - handles commitments and deficit', () {
      // Free surplus with zero commitments
      expect(
        FinancialStateEngine.calculateAvailableMonthlyAmount(
          monthlySurplus: 25000,
          committedMonthlyGoals: 0,
        ),
        25000.0,
      );

      // Surplus with partial commitment
      expect(
        FinancialStateEngine.calculateAvailableMonthlyAmount(
          monthlySurplus: 25000,
          committedMonthlyGoals: 10000,
        ),
        15000.0,
      );

      // Commitments exceeding surplus clamped to 0.0
      expect(
        FinancialStateEngine.calculateAvailableMonthlyAmount(
          monthlySurplus: 25000,
          committedMonthlyGoals: 30000,
        ),
        0.0,
      );

      // Deficit always returns 0.0 available
      expect(
        FinancialStateEngine.calculateAvailableMonthlyAmount(
          monthlySurplus: -5000,
        ),
        0.0,
      );
    });

    test('transaction actuals - calculates inflow, outflow, and net cash flow', () {
      final now = DateTime(2026, 9, 26);
      final transactions = [
        TransactionModel(
          id: 'tx_1',
          userId: 'u1',
          amount: 85000,
          type: TransactionType.credit,
          merchantName: 'Tech Corp Salary',
          category: TransactionCategories.salaryAndIncome,
          paymentMethod: PaymentMethod.netBanking,
          dateTime: now,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionModel(
          id: 'tx_2',
          userId: 'u1',
          amount: 12000,
          type: TransactionType.debit,
          merchantName: 'Apartment Rent',
          category: TransactionCategories.billsAndUtilities,
          paymentMethod: PaymentMethod.upi,
          dateTime: now,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionModel(
          id: 'tx_3',
          userId: 'u1',
          amount: 4500,
          type: TransactionType.debit,
          merchantName: 'Supermarket Groceries',
          category: TransactionCategories.groceries,
          paymentMethod: PaymentMethod.card,
          dateTime: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final inflow = FinancialStateEngine.calculateTransactionInflow(transactions);
      final outflow = FinancialStateEngine.calculateTransactionOutflow(transactions);
      final net = FinancialStateEngine.calculateNetTransactionCashFlow(transactions);

      expect(inflow, 85000.0);
      expect(outflow, 16500.0);
      expect(net, 68500.0);
    });

    test('computeState produces comprehensive, valid snapshot from profile', () {
      final now = DateTime(2026, 9, 26);
      final profile = FinancialProfile(
        userId: 'user_123',
        age: 28,
        occupation: 'Product Designer',
        dependents: 1,
        monthlyIncome: 90000,
        incomeType: 'Salary',
        additionalIncome: 10000,
        currentSavings: 180000,
        monthlyFixedExpenses: 30000,
        monthlyVariableExpenses: 20000,
        existingLoanEmi: 10000,
        activeLoansCount: 1,
        completedAt: now,
      );

      final snapshot = FinancialStateEngine.computeState(
        profile: profile,
        asOfDate: now,
      );

      expect(snapshot.userId, 'user_123');
      expect(snapshot.totalMonthlyIncome, 100000.0);
      expect(snapshot.totalMonthlyExpenses, 60000.0);
      expect(snapshot.monthlySurplus, 40000.0);
      expect(snapshot.savingsRate, 40.0);
      expect(snapshot.isDeficit, isFalse);
      expect(snapshot.expenseToIncomeRatio, 0.60);
      expect(snapshot.debtToIncomeRatio, 0.10);
      expect(snapshot.emergencyFundMonths, 3.0); // 180,000 / 60,000 = 3.0 months

      // Test serialization roundtrip
      final jsonStr = snapshot.toJson();
      final restored = FinancialStateSnapshot.fromJson(jsonStr);
      expect(restored.totalMonthlyIncome, snapshot.totalMonthlyIncome);
      expect(restored.monthlySurplus, snapshot.monthlySurplus);
      expect(restored.debtToIncomeRatio, snapshot.debtToIncomeRatio);
      expect(restored.emergencyFundMonths, snapshot.emergencyFundMonths);
    });
  });

  group('Goal Feasibility Foundation Tests', () {
    test('calculateRemainingAmount - clamped to zero when fully funded', () {
      expect(
        GoalFeasibilityEngine.calculateRemainingAmount(
          targetAmount: 100000,
          currentAmount: 35000,
        ),
        65000.0,
      );

      expect(
        GoalFeasibilityEngine.calculateRemainingAmount(
          targetAmount: 50000,
          currentAmount: 55000,
        ),
        0.0,
      );
    });

    test('required monthly goal contribution - accurately divides remaining amount', () {
      final asOf = DateTime(2026, 1, 1);
      final targetDate = DateTime(2026, 11, 1); // ~10 months away (304 days)

      final req = GoalFeasibilityEngine.calculateRequiredMonthlyContribution(
        targetAmount: 150000,
        currentAmount: 50000, // 100,000 remaining
        targetDate: targetDate,
        asOfDate: asOf,
      );

      final months = GoalFeasibilityEngine.calculateMonthsRemaining(
        targetDate: targetDate,
        asOfDate: asOf,
      );
      expect(months, 10);
      expect(req, 10000.0);
    });

    test('required monthly contribution - returns zero when already funded', () {
      final req = GoalFeasibilityEngine.calculateRequiredMonthlyContribution(
        targetAmount: 50000,
        currentAmount: 50000,
        targetDate: DateTime(2027, 1, 1),
      );
      expect(req, 0.0);
    });

    test('goal feasibility - comfortable status when <= 70% of surplus required', () {
      final asOf = DateTime(2026, 1, 1);
      final goal = GoalModel(
        id: 'g1',
        userId: 'u1',
        name: 'New Laptop',
        category: GoalCategory.personal,
        targetAmount: 120000,
        currentAmount: 20000, // 100,000 remaining
        targetDate: DateTime(2026, 11, 1), // 10 months -> 10,000/mo
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Monthly surplus of 30,000. Required: 10,000/mo (33.3% of surplus)
      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 30000,
        currentSavings: 50000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.comfortable);
      expect(result.requiredMonthlyContribution, 10000.0);
      expect(result.isAchievableWithoutSavings, isTrue);
      expect(result.feasibilityScore, greaterThanOrEqualTo(85.0));
      expect(result.monthlyShortfall, 0.0);
    });

    test('goal feasibility - feasible status when requiring 71% to 100% of surplus', () {
      final asOf = DateTime(2026, 1, 1);
      final goal = GoalModel(
        id: 'g2',
        userId: 'u1',
        name: 'Emergency Fund',
        category: GoalCategory.emergencyFund,
        targetAmount: 100000,
        currentAmount: 20000, // 80,000 remaining
        targetDate: DateTime(2026, 11, 1), // 10 months -> 8,000/mo
        priority: GoalPriority.essential,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Monthly surplus of 10,000. Required: 8,000/mo (80% of surplus)
      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 10000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.feasible);
      expect(result.requiredMonthlyContribution, 8000.0);
      expect(result.isAchievableWithoutSavings, isTrue);
      expect(result.feasibilityScore, inInclusiveRange(65.0, 84.9));
    });

    test('goal feasibility - tight status when surplus is short but savings covers gap', () {
      final asOf = DateTime(2026, 1, 1);
      final goal = GoalModel(
        id: 'g3',
        userId: 'u1',
        name: 'Vehicle Downpayment',
        category: GoalCategory.vehicle,
        targetAmount: 150000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1), // 10 months -> 15,000/mo
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Monthly surplus is 10,000 (short by 5,000/mo), but savings is 100,000
      // 10,000 * 10 = 100,000 + 100,000 savings = 200,000 >= 150,000 target
      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 10000,
        currentSavings: 100000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.tight);
      expect(result.isAchievableWithoutSavings, isFalse);
      expect(result.isAchievableWithSavings, isTrue);
      expect(result.monthlyShortfall, 5000.0);
    });

    test('goal feasibility - unfeasible status when surplus is short and savings insufficient', () {
      final asOf = DateTime(2026, 1, 1);
      final goal = GoalModel(
        id: 'g4',
        userId: 'u1',
        name: 'Luxury Vacation',
        category: GoalCategory.travel,
        targetAmount: 300000,
        currentAmount: 20000, // 280,000 remaining
        targetDate: DateTime(2026, 8, 1), // 7 months -> 40,000/mo
        priority: GoalPriority.flexible,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Monthly surplus is 12,000, current savings is 10,000
      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 12000,
        currentSavings: 10000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.unfeasible);
      expect(result.isAchievableWithoutSavings, isFalse);
      expect(result.isAchievableWithSavings, isFalse);
      expect(result.monthlyShortfall, 28000.0);
      expect(result.feasibilityScore, lessThan(40.0));
    });

    test('goal feasibility - overdue status when target date is in the past', () {
      final asOf = DateTime(2026, 9, 26);
      final pastDate = DateTime(2026, 5, 1);
      final goal = GoalModel(
        id: 'g_past',
        userId: 'u1',
        name: 'Past Goal',
        category: GoalCategory.other,
        targetAmount: 50000,
        currentAmount: 25000,
        targetDate: pastDate,
        priority: GoalPriority.important,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 20000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.overdue);
      expect(result.feasibilityScore, 0.0);
      expect(result.daysRemaining, lessThan(0));
    });

    test('goal feasibility - achieved status when target is already reached', () {
      final asOf = DateTime(2026, 9, 26);
      final goal = GoalModel(
        id: 'g_done',
        userId: 'u1',
        name: 'Done Goal',
        category: GoalCategory.education,
        targetAmount: 50000,
        currentAmount: 50000,
        targetDate: DateTime(2027, 1, 1),
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      final result = GoalFeasibilityEngine.evaluateGoal(
        goal: goal,
        monthlySurplus: 15000,
        asOfDate: asOf,
      );

      expect(result.status, GoalFeasibilityStatus.achieved);
      expect(result.feasibilityScore, 100.0);
      expect(result.requiredMonthlyContribution, 0.0);
    });
  });

  group('Conflict Detection Foundation Tests', () {
    test('conflict detection - detects monthly cash flow deficit', () {
      final state = FinancialStateSnapshot(
        userId: 'u1',
        calculatedAt: DateTime(2026, 9, 26),
        totalMonthlyIncome: 50000,
        totalMonthlyExpenses: 65000,
        monthlyFixedExpenses: 35000,
        monthlyVariableExpenses: 25000,
        totalEmi: 5000,
        activeLoansCount: 1,
        monthlySurplus: -15000,
        savingsRate: 0.0,
        savingsRateFraction: 0.0,
        currentSavings: 20000,
        availableMonthlyAmount: 0.0,
        totalTransactionInflow: 0.0,
        totalTransactionOutflow: 0.0,
        netTransactionCashFlow: 0.0,
        isDeficit: true,
        expenseToIncomeRatio: 1.30,
        debtToIncomeRatio: 0.10,
        emergencyFundMonths: 0.31,
      );

      final analysis = ConflictDetectionEngine.detectConflicts(
        state: state,
        goals: [],
      );

      expect(analysis.hasConflicts, isTrue);
      expect(analysis.criticalCount, greaterThanOrEqualTo(1));
      final deficitConflict = analysis.conflicts.firstWhere(
        (c) => c.type == ConflictType.cashFlowDeficit,
      );
      expect(deficitConflict.severity, ConflictSeverity.critical);
      expect(deficitConflict.monthlyShortfall, 15000.0);
      expect(deficitConflict.suggestedAction, SuggestedActionType.reduceExpenses);
    });

    test('conflict detection - detects single goal exceeding monthly surplus', () {
      final asOf = DateTime(2026, 1, 1);
      final state = FinancialStateSnapshot(
        userId: 'u1',
        calculatedAt: asOf,
        totalMonthlyIncome: 80000,
        totalMonthlyExpenses: 65000,
        monthlyFixedExpenses: 35000,
        monthlyVariableExpenses: 30000,
        totalEmi: 0,
        activeLoansCount: 0,
        monthlySurplus: 15000, // Surplus is 15,000/mo
        savingsRate: 18.75,
        savingsRateFraction: 0.1875,
        currentSavings: 50000,
        availableMonthlyAmount: 15000,
        totalTransactionInflow: 0.0,
        totalTransactionOutflow: 0.0,
        netTransactionCashFlow: 0.0,
        isDeficit: false,
        expenseToIncomeRatio: 0.8125,
        debtToIncomeRatio: 0.0,
        emergencyFundMonths: 0.77,
      );

      // Goal requires 25,000/mo (250,000 in 10 months) against 15,000 surplus
      final largeGoal = GoalModel(
        id: 'g_big',
        userId: 'u1',
        name: 'Higher Studies',
        category: GoalCategory.education,
        targetAmount: 250000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.essential,
        createdAt: asOf,
        updatedAt: asOf,
      );

      final analysis = ConflictDetectionEngine.detectConflicts(
        state: state,
        goals: [largeGoal],
        asOfDate: asOf,
      );

      expect(analysis.hasConflicts, isTrue);
      final singleGoalConflict = analysis.conflicts.firstWhere(
        (c) => c.type == ConflictType.singleGoalSurplusExceeded,
      );
      expect(singleGoalConflict.affectedGoalIds, contains('g_big'));
      expect(singleGoalConflict.monthlyShortfall, 10000.0); // 25,000 - 15,000
    });

    test('conflict detection - detects competing goals exceeding aggregate capacity', () {
      final asOf = DateTime(2026, 1, 1);
      final state = FinancialStateSnapshot(
        userId: 'u1',
        calculatedAt: asOf,
        totalMonthlyIncome: 100000,
        totalMonthlyExpenses: 70000,
        monthlyFixedExpenses: 40000,
        monthlyVariableExpenses: 30000,
        totalEmi: 0,
        activeLoansCount: 0,
        monthlySurplus: 30000, // Available capacity is 30,000/mo
        savingsRate: 30.0,
        savingsRateFraction: 0.30,
        currentSavings: 150000,
        availableMonthlyAmount: 30000,
        totalTransactionInflow: 0.0,
        totalTransactionOutflow: 0.0,
        netTransactionCashFlow: 0.0,
        isDeficit: false,
        expenseToIncomeRatio: 0.70,
        debtToIncomeRatio: 0.0,
        emergencyFundMonths: 2.14,
      );

      // Goal 1: requires 18,000/mo (individually <= 30,000)
      final goal1 = GoalModel(
        id: 'g_comp1',
        userId: 'u1',
        name: 'Wedding Fund',
        category: GoalCategory.personal,
        targetAmount: 180000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1), // 10 months -> 18,000/mo
        priority: GoalPriority.essential,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Goal 2: requires 17,000/mo (individually <= 30,000)
      final goal2 = GoalModel(
        id: 'g_comp2',
        userId: 'u1',
        name: 'Euro Trip',
        category: GoalCategory.travel,
        targetAmount: 170000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1), // 10 months -> 17,000/mo
        priority: GoalPriority.flexible,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Combined requirement: 35,000/mo > 30,000 surplus
      final analysis = ConflictDetectionEngine.detectConflicts(
        state: state,
        goals: [goal1, goal2],
        asOfDate: asOf,
      );

      expect(analysis.hasConflicts, isTrue);
      final aggregateConflict = analysis.conflicts.firstWhere(
        (c) => c.type == ConflictType.competingGoalsCapacityExceeded,
      );
      expect(aggregateConflict.monthlyShortfall, 5000.0);
      expect(aggregateConflict.suggestedAction, SuggestedActionType.prioritizeGoals);
    });

    test('conflict detection - detects high EMI debt burden', () {
      final state = FinancialStateSnapshot(
        userId: 'u1',
        calculatedAt: DateTime(2026, 9, 26),
        totalMonthlyIncome: 100000,
        totalMonthlyExpenses: 75000,
        monthlyFixedExpenses: 15000,
        monthlyVariableExpenses: 15000,
        totalEmi: 45000, // 45% debt-to-income ratio!
        activeLoansCount: 2,
        monthlySurplus: 25000,
        savingsRate: 25.0,
        savingsRateFraction: 0.25,
        currentSavings: 80000,
        availableMonthlyAmount: 25000,
        totalTransactionInflow: 0.0,
        totalTransactionOutflow: 0.0,
        netTransactionCashFlow: 0.0,
        isDeficit: false,
        expenseToIncomeRatio: 0.75,
        debtToIncomeRatio: 0.45,
        emergencyFundMonths: 1.06,
      );

      final analysis = ConflictDetectionEngine.detectConflicts(
        state: state,
        goals: [],
      );

      expect(analysis.hasConflicts, isTrue);
      final debtConflict = analysis.conflicts.firstWhere(
        (c) => c.type == ConflictType.highDebtBurden,
      );
      expect(debtConflict.severity, ConflictSeverity.high);
    });

    test('evaluateExpenseImpact - evaluates significant surplus reduction and deficit trigger', () {
      final asOf = DateTime(2026, 1, 1);
      final state = FinancialStateSnapshot(
        userId: 'u1',
        calculatedAt: asOf,
        totalMonthlyIncome: 100000,
        totalMonthlyExpenses: 70000,
        monthlyFixedExpenses: 40000,
        monthlyVariableExpenses: 30000,
        totalEmi: 0,
        activeLoansCount: 0,
        monthlySurplus: 30000,
        savingsRate: 30.0,
        savingsRateFraction: 0.30,
        currentSavings: 50000,
        availableMonthlyAmount: 30000,
        totalTransactionInflow: 0.0,
        totalTransactionOutflow: 0.0,
        netTransactionCashFlow: 0.0,
        isDeficit: false,
        expenseToIncomeRatio: 0.70,
        debtToIncomeRatio: 0.0,
        emergencyFundMonths: 0.71,
      );

      final goal = GoalModel(
        id: 'g_active',
        userId: 'u1',
        name: 'Certification Exam',
        category: GoalCategory.education,
        targetAmount: 150000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1), // 10 months -> 15,000/mo (was comfortable with 30k surplus)
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // Scenario A: Adding 18,000/mo car subscription
      // Surplus drops from 30,000 to 12,000 (60% reduction)
      // Goal requiring 15,000/mo now becomes unfeasible under 12,000 surplus!
      final impact = ConflictDetectionEngine.evaluateExpenseImpact(
        currentState: state,
        proposedMonthlyExpense: 18000,
        goals: [goal],
        asOfDate: asOf,
      );

      expect(impact.previousSurplus, 30000.0);
      expect(impact.newSurplus, 12000.0);
      expect(impact.surplusReductionPercentage, 60.0);
      expect(impact.causesDeficit, isFalse);
      expect(impact.affectedGoalIds, contains('g_active'));
      expect(impact.generatedConflicts, isNotEmpty);

      // Scenario B: Adding 35,000/mo expense pushes user into cash flow deficit
      final deficitImpact = ConflictDetectionEngine.evaluateExpenseImpact(
        currentState: state,
        proposedMonthlyExpense: 35000,
        goals: [goal],
        asOfDate: asOf,
      );

      expect(deficitImpact.causesDeficit, isTrue);
      expect(deficitImpact.newSurplus, -5000.0);
      expect(deficitImpact.generatedConflicts.any((c) => c.severity == ConflictSeverity.critical), isTrue);
    });
  });
}
