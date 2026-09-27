import '../../../features/goals/models/goal_model.dart';
import '../models/financial_conflict_model.dart';
import '../models/financial_state_snapshot.dart';
import '../models/goal_feasibility_model.dart';
import 'goal_feasibility_engine.dart';

/// Pure, deterministic engine for detecting financial conflicts.
///
/// Rules:
/// - 100% rule-based and mathematical.
/// - Zero LLM reasoning.
/// - Produces explicit conflict metrics, severities, and structured actions for downstream agents.
abstract final class ConflictDetectionEngine {
  /// Detect all deterministic financial conflicts given the current state and goals.
  static ConflictAnalysisResult detectConflicts({
    required FinancialStateSnapshot state,
    required List<GoalModel> goals,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final conflicts = <FinancialConflict>[];

    // 1. Evaluate cash flow deficit
    final deficitConflict = _detectDeficitConflict(state, now);
    if (deficitConflict != null) {
      conflicts.add(deficitConflict);
    }

    // 2. Evaluate high debt / EMI burden
    final debtConflict = _detectDebtBurdenConflict(state, now);
    if (debtConflict != null) {
      conflicts.add(debtConflict);
    }

    // 3. Evaluate goal feasibilities
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final feasibilities = GoalFeasibilityEngine.evaluateAllGoals(
      goals: activeGoals,
      monthlySurplus: state.monthlySurplus,
      currentSavings: state.currentSavings,
      asOfDate: now,
    );

    // 4. Evaluate overdue goals
    for (final f in feasibilities) {
      if (f.status == GoalFeasibilityStatus.overdue) {
        conflicts.add(FinancialConflict(
          id: 'conflict_overdue_${f.goalId}',
          type: ConflictType.goalOverdue,
          severity: ConflictSeverity.medium,
          title: 'Goal "${f.goalName}" is Overdue',
          description:
              'Target date has passed with ₹${f.remainingAmount.toStringAsFixed(0)} remaining unfunded.',
          affectedGoalIds: [f.goalId],
          monthlyShortfall: f.remainingAmount,
          suggestedAction: SuggestedActionType.extendGoalTimeline,
          actionSuggestionText:
              'Extend target date or re-allocate current savings to clear the remaining balance.',
          metrics: {
            'goalId': f.goalId,
            'remainingAmount': f.remainingAmount,
            'targetDate': f.targetDate.toIso8601String(),
          },
          detectedAt: now,
        ));
      }
    }

    // 5. Evaluate individual goals exceeding available surplus
    for (final f in feasibilities) {
      if (f.status == GoalFeasibilityStatus.unfeasible &&
          f.daysRemaining >= 0 &&
          state.monthlySurplus > 0) {
        conflicts.add(FinancialConflict(
          id: 'conflict_single_goal_${f.goalId}',
          type: ConflictType.singleGoalSurplusExceeded,
          severity: f.requiredMonthlyContribution > state.monthlySurplus * 1.5
              ? ConflictSeverity.critical
              : ConflictSeverity.high,
          title: 'Goal "${f.goalName}" Exceeds Monthly Surplus',
          description:
              'Requires ₹${f.requiredMonthlyContribution.toStringAsFixed(0)}/mo, but monthly surplus is only ₹${state.monthlySurplus.toStringAsFixed(0)}/mo (shortfall of ₹${f.monthlyShortfall.toStringAsFixed(0)}/mo).',
          affectedGoalIds: [f.goalId],
          monthlyShortfall: f.monthlyShortfall,
          suggestedAction: SuggestedActionType.extendGoalTimeline,
          actionSuggestionText:
              'Extend the target date or reduce the target amount to lower monthly requirement.',
          metrics: {
            'goalId': f.goalId,
            'requiredMonthly': f.requiredMonthlyContribution,
            'availableSurplus': state.monthlySurplus,
            'monthlyShortfall': f.monthlyShortfall,
          },
          detectedAt: now,
        ));
      }
    }

    // 6. Evaluate aggregate capacity across multiple competing goals
    final totalGoalDemand = feasibilities
        .where((f) => f.status != GoalFeasibilityStatus.achieved)
        .fold(0.0, (sum, f) => sum + f.requiredMonthlyContribution);

    if (activeGoals.length > 1 &&
        state.monthlySurplus > 0 &&
        totalGoalDemand > state.monthlySurplus) {
      final aggregateShortfall = totalGoalDemand - state.monthlySurplus;
      conflicts.add(FinancialConflict(
        id: 'conflict_competing_goals_capacity',
        type: ConflictType.competingGoalsCapacityExceeded,
        severity: totalGoalDemand > (state.monthlySurplus * 1.5)
            ? ConflictSeverity.critical
            : ConflictSeverity.high,
        title: 'Multiple Goals Exceed Surplus Capacity',
        description:
            'Combined goals require ₹${totalGoalDemand.toStringAsFixed(0)}/mo against available surplus of ₹${state.monthlySurplus.toStringAsFixed(0)}/mo (shortfall of ₹${aggregateShortfall.toStringAsFixed(0)}/mo).',
        affectedGoalIds: activeGoals.map((g) => g.id).toList(),
        monthlyShortfall: aggregateShortfall,
        suggestedAction: SuggestedActionType.prioritizeGoals,
        actionSuggestionText:
            'Prioritize higher-priority goals and pause or stagger flexible goals.',
        metrics: {
          'totalGoalDemand': totalGoalDemand,
          'availableSurplus': state.monthlySurplus,
          'aggregateShortfall': aggregateShortfall,
          'goalCount': activeGoals.length,
        },
        detectedAt: now,
      ));
    }

    // 7. Evaluate emergency buffer vulnerability
    if (state.emergencyFundMonths < 1.0 && activeGoals.isNotEmpty) {
      conflicts.add(FinancialConflict(
        id: 'conflict_low_emergency_buffer',
        type: ConflictType.lowEmergencyBuffer,
        severity: ConflictSeverity.medium,
        title: 'Emergency Buffer Under 1 Month',
        description:
            'Current savings covers only ${(state.emergencyFundMonths * 30).toStringAsFixed(0)} days of living expenses while committing funds to forward goals.',
        affectedGoalIds: activeGoals.map((g) => g.id).toList(),
        monthlyShortfall: 0.0,
        suggestedAction: SuggestedActionType.buildEmergencyFund,
        actionSuggestionText:
            'Prioritize accumulating a 3-month emergency safety net before funding discretionary goals.',
        metrics: {
          'currentSavings': state.currentSavings,
          'emergencyFundMonths': state.emergencyFundMonths,
        },
        detectedAt: now,
      ));
    }

    final criticalCount =
        conflicts.where((c) => c.severity == ConflictSeverity.critical).length;
    final highCount =
        conflicts.where((c) => c.severity == ConflictSeverity.high).length;
    final mediumCount =
        conflicts.where((c) => c.severity == ConflictSeverity.medium).length;
    final lowCount =
        conflicts.where((c) => c.severity == ConflictSeverity.low).length;

    return ConflictAnalysisResult(
      hasConflicts: conflicts.isNotEmpty,
      conflicts: conflicts,
      criticalCount: criticalCount,
      highCount: highCount,
      mediumCount: mediumCount,
      lowCount: lowCount,
      totalMonthlyGoalDemand: totalGoalDemand,
      availableSurplus: state.monthlySurplus,
      netCapacityRemaining: state.monthlySurplus - totalGoalDemand,
      evaluatedAt: now,
    );
  }

  /// Evaluate the deterministic impact of an added or proposed monthly expense.
  static ExpenseImpactResult evaluateExpenseImpact({
    required FinancialStateSnapshot currentState,
    required double proposedMonthlyExpense,
    required List<GoalModel> goals,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final prevSurplus = currentState.monthlySurplus;
    final newSurplus = prevSurplus - proposedMonthlyExpense;
    final delta = proposedMonthlyExpense;

    final reductionPct = prevSurplus > 0
        ? ((proposedMonthlyExpense / prevSurplus) * 100.0).clamp(0.0, 1000.0)
        : 100.0;

    final causesDeficit = newSurplus < 0;

    // Check which previously feasible goals become unfeasible or tight
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final prevFeasibilities = GoalFeasibilityEngine.evaluateAllGoals(
      goals: activeGoals,
      monthlySurplus: prevSurplus,
      currentSavings: currentState.currentSavings,
      asOfDate: now,
    );
    final newFeasibilities = GoalFeasibilityEngine.evaluateAllGoals(
      goals: activeGoals,
      monthlySurplus: newSurplus,
      currentSavings: currentState.currentSavings,
      asOfDate: now,
    );

    final affectedGoalIds = <String>[];
    for (int i = 0; i < activeGoals.length; i++) {
      final prevF = prevFeasibilities[i];
      final newF = newFeasibilities[i];
      final wasFeasible = prevF.status == GoalFeasibilityStatus.comfortable ||
          prevF.status == GoalFeasibilityStatus.feasible;
      final isNowUnfeasible =
          newF.status == GoalFeasibilityStatus.unfeasible ||
              newF.status == GoalFeasibilityStatus.tight;
      if (wasFeasible && isNowUnfeasible) {
        affectedGoalIds.add(activeGoals[i].id);
      }
    }

    final generatedConflicts = <FinancialConflict>[];

    // If expense causes deficit
    if (causesDeficit) {
      generatedConflicts.add(FinancialConflict(
        id: 'conflict_impact_deficit',
        type: ConflictType.newExpenseSurplusReduction,
        severity: ConflictSeverity.critical,
        title: 'New Expense Triggers Monthly Deficit',
        description:
            'Adding ₹${proposedMonthlyExpense.toStringAsFixed(0)}/mo expense reduces monthly surplus from ₹${prevSurplus.toStringAsFixed(0)} to a deficit of ₹${newSurplus.abs().toStringAsFixed(0)}.',
        affectedGoalIds: affectedGoalIds,
        monthlyShortfall: newSurplus.abs(),
        suggestedAction: SuggestedActionType.reduceExpenses,
        actionSuggestionText:
            'Avoid or reduce this recurring expense to protect monthly cash flow.',
        metrics: {
          'proposedExpense': proposedMonthlyExpense,
          'previousSurplus': prevSurplus,
          'newSurplus': newSurplus,
        },
        detectedAt: now,
      ));
    } else if (reductionPct >= 30.0) {
      // Significant reduction in surplus
      final severity = reductionPct >= 60.0
          ? ConflictSeverity.high
          : ConflictSeverity.medium;
      generatedConflicts.add(FinancialConflict(
        id: 'conflict_impact_surplus_reduction',
        type: ConflictType.newExpenseSurplusReduction,
        severity: severity,
        title: 'New Expense Significantly Reduces Surplus',
        description:
            'Adding ₹${proposedMonthlyExpense.toStringAsFixed(0)}/mo absorbs ${reductionPct.toStringAsFixed(0)}% of your monthly surplus (reducing it to ₹${newSurplus.toStringAsFixed(0)}/mo).',
        affectedGoalIds: affectedGoalIds,
        monthlyShortfall: 0.0,
        suggestedAction: affectedGoalIds.isNotEmpty
            ? SuggestedActionType.extendGoalTimeline
            : SuggestedActionType.reduceExpenses,
        actionSuggestionText: affectedGoalIds.isNotEmpty
            ? 'Adjust timeline for ${affectedGoalIds.length} affected goal(s) to absorb the expense safely.'
            : 'Consider keeping variable expenses lower to protect savings capacity.',
        metrics: {
          'proposedExpense': proposedMonthlyExpense,
          'previousSurplus': prevSurplus,
          'newSurplus': newSurplus,
          'reductionPercentage': reductionPct,
          'affectedGoalsCount': affectedGoalIds.length,
        },
        detectedAt: now,
      ));
    }

    return ExpenseImpactResult(
      proposedExpenseAmount: proposedMonthlyExpense,
      previousSurplus: prevSurplus,
      newSurplus: newSurplus,
      surplusDelta: delta,
      surplusReductionPercentage:
          double.parse(reductionPct.toStringAsFixed(1)),
      causesDeficit: causesDeficit,
      affectedGoalIds: affectedGoalIds,
      generatedConflicts: generatedConflicts,
      evaluatedAt: now,
    );
  }

  static FinancialConflict? _detectDeficitConflict(
    FinancialStateSnapshot state,
    DateTime now,
  ) {
    if (!state.isDeficit && state.monthlySurplus >= 0) return null;
    final deficit = state.monthlySurplus.abs();
    return FinancialConflict(
      id: 'conflict_cash_flow_deficit',
      type: ConflictType.cashFlowDeficit,
      severity: ConflictSeverity.critical,
      title: 'Monthly Cash Flow Deficit',
      description:
          'Monthly expenses (₹${state.totalMonthlyExpenses.toStringAsFixed(0)}) exceed monthly income (₹${state.totalMonthlyIncome.toStringAsFixed(0)}) by ₹${deficit.toStringAsFixed(0)}/mo.',
      monthlyShortfall: deficit,
      suggestedAction: SuggestedActionType.reduceExpenses,
      actionSuggestionText:
          'Immediate expense reduction required to prevent erosion of existing savings.',
      metrics: {
        'totalIncome': state.totalMonthlyIncome,
        'totalExpenses': state.totalMonthlyExpenses,
        'monthlyDeficit': deficit,
      },
      detectedAt: now,
    );
  }

  static FinancialConflict? _detectDebtBurdenConflict(
    FinancialStateSnapshot state,
    DateTime now,
  ) {
    if (state.debtToIncomeRatio < 0.40) return null;
    final isCritical = state.debtToIncomeRatio >= 0.50;
    final emiPct = (state.debtToIncomeRatio * 100).toStringAsFixed(0);
    return FinancialConflict(
      id: 'conflict_high_debt_burden',
      type: ConflictType.highDebtBurden,
      severity: isCritical ? ConflictSeverity.critical : ConflictSeverity.high,
      title: 'High Debt / EMI Burden ($emiPct% of Income)',
      description:
          'Monthly EMI of ₹${state.totalEmi.toStringAsFixed(0)} consumes $emiPct% of total income, creating high financial vulnerability.',
      monthlyShortfall: 0.0,
      suggestedAction: SuggestedActionType.prioritizeGoals,
      actionSuggestionText:
          'Prioritize aggressive loan prepayment or refinance before committing to discretionary goals.',
      metrics: {
        'totalEmi': state.totalEmi,
        'totalIncome': state.totalMonthlyIncome,
        'debtToIncomeRatio': state.debtToIncomeRatio,
      },
      detectedAt: now,
    );
  }
}
