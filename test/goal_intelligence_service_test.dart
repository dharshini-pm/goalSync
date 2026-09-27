import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/intelligence.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_service.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/onboarding/services/financial_profile_service.dart';
import 'package:goalsync/features/transactions/services/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FinancialProfileService profileService;
  late GoalService goalService;
  late TransactionService transactionService;
  late GoalIntelligenceService intelligenceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FinancialProfileService.resetForTesting();
    GoalService.resetForTesting();
    TransactionService.resetForTesting();
    GoalIntelligenceService.resetForTesting();

    profileService = FinancialProfileService.instance;
    goalService = GoalService.instance;
    transactionService = TransactionService.instance;
    intelligenceService = GoalIntelligenceService.instance;

    await profileService.init();
    await goalService.init();
    await transactionService.init();
  });

  Future<void> setupProfile({
    required String userId,
    double monthlyIncome = 100000,
    double additionalIncome = 0,
    double fixedExpenses = 40000,
    double variableExpenses = 20000,
    double loanEmi = 10000,
    double currentSavings = 100000,
  }) async {
    final profile = FinancialProfile(
      userId: userId,
      age: 28,
      occupation: 'Developer',
      dependents: 1,
      monthlyIncome: monthlyIncome,
      incomeType: 'Salary',
      additionalIncome: additionalIncome,
      currentSavings: currentSavings,
      monthlyFixedExpenses: fixedExpenses,
      monthlyVariableExpenses: variableExpenses,
      existingLoanEmi: loanEmi,
      activeLoansCount: loanEmi > 0 ? 1 : 0,
      completedAt: DateTime(2026, 1, 1),
    );
    await profileService.saveProfile(profile);
  }

  group('GoalIntelligenceService Orchestration Tests', () {
    test('1. User with no goals', () async {
      const userId = 'user_no_goals';
      await setupProfile(userId: userId);

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: DateTime(2026, 1, 1),
      );

      expect(snapshot.userId, userId);
      expect(snapshot.totalGoals, 0);
      expect(snapshot.achievedGoals, 0);
      expect(snapshot.achievableGoals, 0);
      expect(snapshot.tightGoals, 0);
      expect(snapshot.unfeasibleGoals, 0);
      expect(snapshot.overdueGoals, 0);
      expect(snapshot.totalRequiredMonthlyGoalContribution, 0.0);
      expect(snapshot.overallGoalCapacityStatus, 'no_goals');
      expect(snapshot.financialState.monthlySurplus, 30000.0);
      expect(snapshot.conflicts, isEmpty);
    });

    test('2. User with one comfortable goal', () async {
      const userId = 'user_comfortable';
      await setupProfile(userId: userId); // 30,000 monthly surplus

      final asOf = DateTime(2026, 1, 1);
      await goalService.createGoal(
        userId: userId,
        name: 'New Computer',
        category: GoalCategory.personal,
        targetAmountRaw: '100000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1), // 10 months -> 10,000/mo (33% of surplus)
        priority: GoalPriority.important,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.totalGoals, 1);
      expect(snapshot.achievableGoals, 1);
      expect(snapshot.tightGoals, 0);
      expect(snapshot.unfeasibleGoals, 0);
      expect(snapshot.totalRequiredMonthlyGoalContribution, 10000.0);
      expect(snapshot.overallGoalCapacityStatus, 'healthy');
      expect(
        snapshot.goalFeasibilityResults.first.status,
        GoalFeasibilityStatus.comfortable,
      );
    });

    test('3. User with one tight goal', () async {
      const userId = 'user_tight';
      // Income 60,000, expenses 50,000 -> 10,000 surplus; 100,000 savings
      await setupProfile(
        userId: userId,
        monthlyIncome: 60000,
        fixedExpenses: 30000,
        variableExpenses: 20000,
        loanEmi: 0,
        currentSavings: 100000,
      );

      final asOf = DateTime(2026, 1, 1);
      // Requires 15,000/mo (150,000 in 10 months). Exceeds 10,000 surplus, but covered by 100,000 savings
      await goalService.createGoal(
        userId: userId,
        name: 'Car Downpayment',
        category: GoalCategory.vehicle,
        targetAmountRaw: '150000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.important,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.totalGoals, 1);
      expect(snapshot.achievableGoals, 0);
      expect(snapshot.tightGoals, 1);
      expect(snapshot.overallGoalCapacityStatus, 'tight');
      expect(
        snapshot.goalFeasibilityResults.first.status,
        GoalFeasibilityStatus.tight,
      );
    });

    test('4. User with an unfeasible goal', () async {
      const userId = 'user_unfeasible';
      // 10,000 surplus, only 5,000 savings
      await setupProfile(
        userId: userId,
        monthlyIncome: 50000,
        fixedExpenses: 25000,
        variableExpenses: 15000,
        loanEmi: 0,
        currentSavings: 5000,
      );

      final now = DateTime.now();
      final asOf = DateTime(now.year, now.month, now.day);
      // Requires 83,333/mo (250,000 in 3 months). Far exceeds 10,000 surplus and 5,000 savings
      await goalService.createGoal(
        userId: userId,
        name: 'Luxury Trip',
        category: GoalCategory.travel,
        targetAmountRaw: '250000',
        currentAmountRaw: '0',
        targetDate: asOf.add(const Duration(days: 90)),
        priority: GoalPriority.flexible,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.totalGoals, 1);
      expect(snapshot.unfeasibleGoals, 1);
      expect(snapshot.overallGoalCapacityStatus, 'conflicted');
      expect(
        snapshot.conflicts.any(
            (c) => c.type == ConflictType.singleGoalSurplusExceeded),
        isTrue,
      );
    });

    test('5. Multiple goals exceeding available capacity', () async {
      const userId = 'user_multiple_exceeding';
      // Surplus is 25,000/mo
      await setupProfile(
        userId: userId,
        monthlyIncome: 75000,
        fixedExpenses: 30000,
        variableExpenses: 20000,
        loanEmi: 0,
        currentSavings: 50000,
      );

      final asOf = DateTime(2026, 1, 1);
      // Goal 1 requires 15,000/mo (150,000 in 10 months)
      await goalService.createGoal(
        userId: userId,
        name: 'Goal Alpha',
        category: GoalCategory.education,
        targetAmountRaw: '150000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.essential,
      );

      // Goal 2 requires 15,000/mo (150,000 in 10 months)
      await goalService.createGoal(
        userId: userId,
        name: 'Goal Beta',
        category: GoalCategory.investment,
        targetAmountRaw: '150000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.important,
      );

      // Total demand = 30,000/mo > 25,000 surplus
      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.totalGoals, 2);
      expect(snapshot.totalRequiredMonthlyGoalContribution, 30000.0);
      expect(snapshot.overallGoalCapacityStatus, 'conflicted');
      expect(
        snapshot.conflicts.any(
            (c) => c.type == ConflictType.competingGoalsCapacityExceeded),
        isTrue,
      );
    });

    test('6. Achieved goal', () async {
      const userId = 'user_achieved';
      await setupProfile(userId: userId);

      final asOf = DateTime(2026, 1, 1);
      await goalService.createGoal(
        userId: userId,
        name: 'Completed Goal',
        category: GoalCategory.emergencyFund,
        targetAmountRaw: '50000',
        currentAmountRaw: '50000', // 100% completed
        targetDate: DateTime(2026, 12, 1),
        priority: GoalPriority.essential,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.totalGoals, 1);
      expect(snapshot.achievedGoals, 1);
      expect(snapshot.totalRequiredMonthlyGoalContribution, 0.0);
      expect(snapshot.overallGoalCapacityStatus, 'healthy');
      expect(
        snapshot.goalFeasibilityResults.first.status,
        GoalFeasibilityStatus.achieved,
      );
    });

    test('7. Overdue goal', () async {
      const userId = 'user_overdue';
      await setupProfile(userId: userId);

      final asOf = DateTime(2026, 9, 26);
      // Target date in the past with unpaid balance
      final pastGoal = GoalModel(
        id: 'goal_past',
        userId: userId,
        name: 'Expired Target Goal',
        category: GoalCategory.travel,
        targetAmount: 80000,
        currentAmount: 30000, // 50,000 remaining
        targetDate: DateTime(2026, 6, 1),
        priority: GoalPriority.important,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Manually persist to local storage handle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('goalsync_goals_$userId', [pastGoal.toJson()]);

      final snapshot = await GoalIntelligenceService(
        profileService: profileService,
        goalService: goalService,
        transactionService: transactionService,
      ).buildSnapshot(userId, asOfDate: asOf);

      expect(snapshot.totalGoals, 1);
      expect(snapshot.overdueGoals, 1);
      expect(snapshot.overallGoalCapacityStatus, 'conflicted');
      expect(
        snapshot.conflicts.any((c) => c.type == ConflictType.goalOverdue),
        isTrue,
      );
    });

    test('8. Financial deficit affecting goals', () async {
      const userId = 'user_deficit';
      // Deficit: 50,000 income, 65,000 expenses -> -15,000 deficit
      await setupProfile(
        userId: userId,
        monthlyIncome: 50000,
        fixedExpenses: 35000,
        variableExpenses: 25000,
        loanEmi: 5000,
        currentSavings: 10000,
      );

      final asOf = DateTime(2026, 1, 1);
      await goalService.createGoal(
        userId: userId,
        name: 'Modest Goal',
        category: GoalCategory.personal,
        targetAmountRaw: '30000',
        currentAmountRaw: '0',
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.important,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      expect(snapshot.financialState.isDeficit, isTrue);
      expect(snapshot.financialState.monthlySurplus, -15000.0);
      expect(snapshot.overallGoalCapacityStatus, 'conflicted');
      expect(
        snapshot.conflicts.any((c) => c.type == ConflictType.cashFlowDeficit),
        isTrue,
      );
    });

    test('9. Snapshot contains correct counts across all goal statuses', () async {
      const userId = 'user_counts';
      // 40,000 monthly surplus, 150,000 savings
      await setupProfile(
        userId: userId,
        monthlyIncome: 100000,
        fixedExpenses: 35000,
        variableExpenses: 25000,
        loanEmi: 0,
        currentSavings: 150000,
      );

      final asOf = DateTime(2026, 1, 1);

      // 1 Achieved: 40k / 40k
      final gAchieved = GoalModel(
        id: 'g_achieved',
        userId: userId,
        name: 'Achieved Goal',
        category: GoalCategory.emergencyFund,
        targetAmount: 40000,
        currentAmount: 40000,
        targetDate: DateTime(2026, 12, 1),
        priority: GoalPriority.essential,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // 1 Comfortable: 100k target in 10 months -> 10,000/mo (25% of surplus)
      final gComfortable = GoalModel(
        id: 'g_comfortable',
        userId: userId,
        name: 'Comfortable Goal',
        category: GoalCategory.education,
        targetAmount: 100000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1),
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // 1 Tight: requires 50k/mo against 40k surplus, covered by 150k savings
      final gTight = GoalModel(
        id: 'g_tight',
        userId: userId,
        name: 'Tight Goal',
        category: GoalCategory.vehicle,
        targetAmount: 500000,
        currentAmount: 0,
        targetDate: DateTime(2026, 11, 1), // 10 months -> 50,000/mo
        priority: GoalPriority.important,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // 1 Unfeasible: requires 100k/mo against 40k surplus, savings insufficient
      final gUnfeasible = GoalModel(
        id: 'g_unfeasible',
        userId: userId,
        name: 'Unfeasible Goal',
        category: GoalCategory.home,
        targetAmount: 2000000,
        currentAmount: 0,
        targetDate: DateTime(2026, 5, 1), // 4 months -> 500,000/mo
        priority: GoalPriority.flexible,
        createdAt: asOf,
        updatedAt: asOf,
      );

      // 1 Overdue
      final gOverdue = GoalModel(
        id: 'g_overdue',
        userId: userId,
        name: 'Overdue Goal',
        category: GoalCategory.travel,
        targetAmount: 50000,
        currentAmount: 10000,
        targetDate: DateTime(2025, 12, 1), // in the past relative to 2026-01-01
        priority: GoalPriority.flexible,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final allGoals = [
        gAchieved,
        gComfortable,
        gTight,
        gUnfeasible,
        gOverdue,
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'goalsync_goals_$userId',
        allGoals.map((g) => g.toJson()).toList(),
      );

      final snapshot = await GoalIntelligenceService(
        profileService: profileService,
        goalService: goalService,
        transactionService: transactionService,
      ).buildSnapshot(userId, asOfDate: asOf);

      expect(snapshot.totalGoals, 5);
      expect(snapshot.achievedGoals, 1);
      expect(snapshot.achievableGoals, 1);
      expect(snapshot.tightGoals, 1);
      expect(snapshot.unfeasibleGoals, 1);
      expect(snapshot.overdueGoals, 1);
    });

    test('10. Snapshot serialization and deserialization preserves all data', () async {
      const userId = 'user_serialize';
      await setupProfile(userId: userId);

      final asOf = DateTime(2026, 1, 1);
      await goalService.createGoal(
        userId: userId,
        name: 'Gadget Fund',
        category: GoalCategory.personal,
        targetAmountRaw: '50000',
        currentAmountRaw: '10000',
        targetDate: DateTime(2026, 9, 1),
        priority: GoalPriority.important,
      );

      final snapshot = await intelligenceService.buildSnapshot(
        userId,
        asOfDate: asOf,
      );

      final jsonStr = snapshot.toJson();
      final restored = GoalIntelligenceSnapshot.fromJson(jsonStr);

      expect(restored.userId, snapshot.userId);
      expect(restored.totalGoals, snapshot.totalGoals);
      expect(restored.achievableGoals, snapshot.achievableGoals);
      expect(restored.tightGoals, snapshot.tightGoals);
      expect(restored.unfeasibleGoals, snapshot.unfeasibleGoals);
      expect(restored.achievedGoals, snapshot.achievedGoals);
      expect(restored.overdueGoals, snapshot.overdueGoals);
      expect(
        restored.totalRequiredMonthlyGoalContribution,
        snapshot.totalRequiredMonthlyGoalContribution,
      );
      expect(
        restored.overallGoalCapacityStatus,
        snapshot.overallGoalCapacityStatus,
      );
      expect(
        restored.financialState.totalMonthlyIncome,
        snapshot.financialState.totalMonthlyIncome,
      );
      expect(
        restored.financialState.monthlySurplus,
        snapshot.financialState.monthlySurplus,
      );
      expect(
        restored.goalFeasibilityResults.length,
        snapshot.goalFeasibilityResults.length,
      );
    });

    test('refresh updates cached snapshot and notifies listeners', () async {
      const userId = 'user_refresh';
      await setupProfile(userId: userId);

      int notifyCount = 0;
      intelligenceService.addListener(() {
        notifyCount++;
      });

      final refreshed = await intelligenceService.refresh(userId);
      expect(refreshed.userId, userId);
      expect(notifyCount, 1);
      expect(intelligenceService.getCachedSnapshot(userId), isNotNull);
    });
  });
}
