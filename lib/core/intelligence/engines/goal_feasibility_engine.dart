import 'dart:math' as math;
import '../../../features/goals/models/goal_model.dart';
import '../models/goal_feasibility_model.dart';

/// Pure, deterministic calculation engine for goal feasibility evaluation.
///
/// Rules:
/// - 100% mathematical and code-driven.
/// - Zero LLM reasoning.
/// - Provides exact numerical metrics, coverage ratios, and deterministic statuses.
abstract final class GoalFeasibilityEngine {
  /// Calculate remaining amount needed to reach goal target.
  static double calculateRemainingAmount({
    required double targetAmount,
    required double currentAmount,
  }) {
    if (targetAmount <= 0) return 0.0;
    return math.max(0.0, targetAmount - math.max(0.0, currentAmount));
  }

  /// Calculate days remaining until target date (from midnight to midnight).
  static int calculateDaysRemaining({
    required DateTime targetDate,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return targetMidnight.difference(todayMidnight).inDays;
  }

  /// Calculate months remaining until target date.
  /// If target date has passed, returns 0.
  /// If target date is in the future, returns at least 1 month.
  static int calculateMonthsRemaining({
    required DateTime targetDate,
    DateTime? asOfDate,
  }) {
    final days =
        calculateDaysRemaining(targetDate: targetDate, asOfDate: asOfDate);
    if (days <= 0) return 0;
    // Average calendar month length is 30.4375 days; ceil to capture monthly saving cycles
    return math.max(1, (days / 30.4375).ceil());
  }

  /// Calculate required monthly contribution to reach target amount by target date.
  /// If goal is already funded, returns 0.0.
  /// If goal is overdue or due within 0 months, returns total remaining amount immediately.
  static double calculateRequiredMonthlyContribution({
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
    DateTime? asOfDate,
  }) {
    final remaining = calculateRemainingAmount(
      targetAmount: targetAmount,
      currentAmount: currentAmount,
    );
    if (remaining <= 0) return 0.0;

    final months = calculateMonthsRemaining(
      targetDate: targetDate,
      asOfDate: asOfDate,
    );
    if (months <= 0) return remaining;

    return remaining / months;
  }

  /// Evaluate feasibility of a [GoalModel] based on monthly surplus and savings.
  static GoalFeasibilityResult evaluateGoal({
    required GoalModel goal,
    required double monthlySurplus,
    double currentSavings = 0.0,
    DateTime? asOfDate,
  }) {
    return evaluateGoalFromValues(
      goalId: goal.id,
      goalName: goal.name,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      targetDate: goal.targetDate,
      monthlySurplus: monthlySurplus,
      currentSavings: currentSavings,
      asOfDate: asOfDate,
      metadata: {
        'category': goal.category.name,
        'priority': goal.priority.name,
      },
    );
  }

  /// Evaluate feasibility from discrete primitive parameters.
  static GoalFeasibilityResult evaluateGoalFromValues({
    required String goalId,
    required String goalName,
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
    required double monthlySurplus,
    double currentSavings = 0.0,
    DateTime? asOfDate,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = asOfDate ?? DateTime.now();
    final remaining = calculateRemainingAmount(
      targetAmount: targetAmount,
      currentAmount: currentAmount,
    );
    final daysRemaining = calculateDaysRemaining(
      targetDate: targetDate,
      asOfDate: now,
    );
    final monthsRemaining = calculateMonthsRemaining(
      targetDate: targetDate,
      asOfDate: now,
    );
    final requiredMonthly = calculateRequiredMonthlyContribution(
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      asOfDate: now,
    );

    // Case 1: Already achieved
    if (remaining <= 0) {
      return GoalFeasibilityResult(
        goalId: goalId,
        goalName: goalName,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        remainingAmount: 0.0,
        targetDate: targetDate,
        asOfDate: now,
        daysRemaining: daysRemaining,
        monthsRemaining: monthsRemaining,
        requiredMonthlyContribution: 0.0,
        availableMonthlySurplus: monthlySurplus,
        surplusCoverageRatio: 1.0,
        monthlyShortfall: 0.0,
        isAchievableWithoutSavings: true,
        isAchievableWithSavings: true,
        projectedCompletionDate: now,
        status: GoalFeasibilityStatus.achieved,
        feasibilityScore: 100.0,
        reason: 'Goal target amount has been fully reached.',
        metadata: metadata,
      );
    }

    // Case 2: Overdue (target date is in the past, yet unpaid)
    if (daysRemaining < 0) {
      return GoalFeasibilityResult(
        goalId: goalId,
        goalName: goalName,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        remainingAmount: remaining,
        targetDate: targetDate,
        asOfDate: now,
        daysRemaining: daysRemaining,
        monthsRemaining: 0,
        requiredMonthlyContribution: remaining,
        availableMonthlySurplus: monthlySurplus,
        surplusCoverageRatio: 0.0,
        monthlyShortfall: math.max(0.0, remaining - monthlySurplus),
        isAchievableWithoutSavings: false,
        isAchievableWithSavings: currentSavings >= remaining,
        projectedCompletionDate: null,
        status: GoalFeasibilityStatus.overdue,
        feasibilityScore: 0.0,
        reason:
            'Target date passed with ₹${remaining.toStringAsFixed(0)} remaining to be funded.',
        metadata: metadata,
      );
    }

    // Projected completion date based on monthly surplus
    DateTime? projectedDate;
    if (monthlySurplus > 0) {
      final monthsToComplete = (remaining / monthlySurplus).ceil();
      projectedDate = DateTime(
        now.year,
        now.month + monthsToComplete,
        now.day,
      );
    }

    final coverageRatio = requiredMonthly > 0 && monthlySurplus > 0
        ? monthlySurplus / requiredMonthly
        : 0.0;
    final shortfall = math.max(0.0, requiredMonthly - monthlySurplus);
    final totalProjectedAccumulation =
        (monthlySurplus > 0 ? monthlySurplus * monthsRemaining : 0.0) +
            currentSavings;
    final isAchievableWithoutSavings =
        monthlySurplus > 0 && requiredMonthly <= monthlySurplus;
    final isAchievableWithSavings = totalProjectedAccumulation >= remaining;

    GoalFeasibilityStatus status;
    double score;
    String reason;

    if (isAchievableWithoutSavings) {
      final surplusUtilization = requiredMonthly / monthlySurplus;
      if (surplusUtilization <= 0.70) {
        status = GoalFeasibilityStatus.comfortable;
        // Score between 85 and 100 based on low surplus utilization
        score = (100.0 - (surplusUtilization * 20)).clamp(85.0, 100.0);
        reason =
            'Comfortably achievable. Requires ₹${requiredMonthly.toStringAsFixed(0)}/mo (${(surplusUtilization * 100).toStringAsFixed(0)}% of monthly surplus).';
      } else {
        status = GoalFeasibilityStatus.feasible;
        // Score between 65 and 84.9
        score = (85.0 - ((surplusUtilization - 0.70) / 0.30 * 20))
            .clamp(65.0, 84.9);
        reason =
            'Achievable with current cash flow. Requires ₹${requiredMonthly.toStringAsFixed(0)}/mo (${(surplusUtilization * 100).toStringAsFixed(0)}% of monthly surplus).';
      }
    } else if (isAchievableWithSavings) {
      status = GoalFeasibilityStatus.tight;
      score = 50.0;
      reason =
          'Monthly surplus is short by ₹${shortfall.toStringAsFixed(0)}/mo, but achievable by utilizing existing savings buffer.';
    } else {
      status = GoalFeasibilityStatus.unfeasible;
      score = math.max(0.0, coverageRatio * 40.0).clamp(0.0, 39.9);
      if (monthlySurplus <= 0) {
        reason =
            'Unfeasible due to zero or negative monthly surplus (monthly deficit).';
      } else {
        reason =
            'Unfeasible under current surplus. Requires ₹${requiredMonthly.toStringAsFixed(0)}/mo, exceeding surplus by ₹${shortfall.toStringAsFixed(0)}/mo.';
      }
    }

    return GoalFeasibilityResult(
      goalId: goalId,
      goalName: goalName,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      remainingAmount: remaining,
      targetDate: targetDate,
      asOfDate: now,
      daysRemaining: daysRemaining,
      monthsRemaining: monthsRemaining,
      requiredMonthlyContribution: requiredMonthly,
      availableMonthlySurplus: monthlySurplus,
      surplusCoverageRatio: coverageRatio,
      monthlyShortfall: shortfall,
      isAchievableWithoutSavings: isAchievableWithoutSavings,
      isAchievableWithSavings: isAchievableWithSavings,
      projectedCompletionDate: projectedDate,
      status: status,
      feasibilityScore: double.parse(score.toStringAsFixed(1)),
      reason: reason,
      metadata: metadata,
    );
  }

  /// Batch evaluate a list of goals against a user's monthly surplus.
  static List<GoalFeasibilityResult> evaluateAllGoals({
    required List<GoalModel> goals,
    required double monthlySurplus,
    double currentSavings = 0.0,
    DateTime? asOfDate,
  }) {
    return goals
        .map((goal) => evaluateGoal(
              goal: goal,
              monthlySurplus: monthlySurplus,
              currentSavings: currentSavings,
              asOfDate: asOfDate,
            ))
        .toList();
  }
}
