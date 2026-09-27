import 'package:flutter/foundation.dart';
import '../../../features/goals/services/goal_service.dart';
import '../../../features/onboarding/services/financial_profile_service.dart';
import '../../../features/transactions/services/transaction_service.dart';
import '../engines/conflict_detection_engine.dart';
import '../engines/financial_state_engine.dart';
import '../engines/goal_feasibility_engine.dart';
import '../models/financial_conflict_model.dart';
import '../models/financial_state_snapshot.dart';
import '../models/goal_feasibility_model.dart';
import '../models/goal_intelligence_snapshot.dart';
import 'transaction_pattern_service.dart';

/// Service that orchestrates deterministic financial intelligence calculations
/// across user profile, goals, and transaction history.
///
/// Produces a unified [GoalIntelligenceSnapshot] without relying on an LLM or heuristics.
class GoalIntelligenceService extends ChangeNotifier {
  static GoalIntelligenceService? _instance;
  static GoalIntelligenceService get instance =>
      _instance ??= GoalIntelligenceService._();

  final FinancialProfileService _profileService;
  final GoalService _goalService;
  final TransactionService _transactionService;
  final TransactionPatternService _transactionPatternService;

  final Map<String, GoalIntelligenceSnapshot> _cachedSnapshots = {};

  GoalIntelligenceService({
    FinancialProfileService? profileService,
    GoalService? goalService,
    TransactionService? transactionService,
    TransactionPatternService? transactionPatternService,
  })  : _profileService = profileService ?? FinancialProfileService.instance,
        _goalService = goalService ?? GoalService.instance,
        _transactionService = transactionService ?? TransactionService.instance,
        _transactionPatternService =
            transactionPatternService ?? const TransactionPatternService();

  GoalIntelligenceService._()
      : _profileService = FinancialProfileService.instance,
        _goalService = GoalService.instance,
        _transactionService = TransactionService.instance,
        _transactionPatternService = const TransactionPatternService();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Get the last cached intelligence snapshot for a user, if available.
  GoalIntelligenceSnapshot? getCachedSnapshot(String userId) =>
      _cachedSnapshots[userId];

  /// Builds a unified, deterministic [GoalIntelligenceSnapshot] for the given user.
  Future<GoalIntelligenceSnapshot> buildSnapshot(
    String userId, {
    DateTime? asOfDate,
  }) async {
    final now = asOfDate ?? DateTime.now();

    // Ensure underlying persistence services are initialized
    if (!_profileService.isInitialized) await _profileService.init();
    if (!_goalService.isInitialized) await _goalService.init();
    if (!_transactionService.isInitialized) await _transactionService.init();

    // 1. Load user profile, goals, and transactions
    final profile = _profileService.getProfile(userId);
    final goals = _goalService.getGoalsForUser(userId);
    final transactions = _transactionService.getTransactionsForUser(userId);

    // 2. Compute deterministic financial state
    final FinancialStateSnapshot financialState;
    if (profile != null) {
      financialState = FinancialStateEngine.computeState(
        profile: profile,
        transactions: transactions,
        asOfDate: now,
      );
    } else {
      // Graceful fallback for uncompleted onboarding
      financialState = FinancialStateEngine.computeStateFromValues(
        userId: userId,
        monthlyIncome: 0.0,
        fixedExpenses: 0.0,
        variableExpenses: 0.0,
        loanEmi: 0.0,
        currentSavings: 0.0,
        asOfDate: now,
      );
    }

    // 3. Evaluate feasibility for all goals
    final feasibilityResults = GoalFeasibilityEngine.evaluateAllGoals(
      goals: goals,
      monthlySurplus: financialState.monthlySurplus,
      currentSavings: financialState.currentSavings,
      asOfDate: now,
    );

    // 4. Detect deterministic conflicts
    final conflictAnalysis = ConflictDetectionEngine.detectConflicts(
      state: financialState,
      goals: goals,
      asOfDate: now,
    );

    // 5. Aggregate goal status counts
    int achievableCount = 0;
    int tightCount = 0;
    int unfeasibleCount = 0;
    int overdueCount = 0;
    int achievedCount = 0;
    double totalRequiredMonthly = 0.0;

    for (final result in feasibilityResults) {
      switch (result.status) {
        case GoalFeasibilityStatus.achieved:
          achievedCount++;
          break;
        case GoalFeasibilityStatus.comfortable:
        case GoalFeasibilityStatus.feasible:
          achievableCount++;
          totalRequiredMonthly += result.requiredMonthlyContribution;
          break;
        case GoalFeasibilityStatus.tight:
          tightCount++;
          totalRequiredMonthly += result.requiredMonthlyContribution;
          break;
        case GoalFeasibilityStatus.unfeasible:
          unfeasibleCount++;
          totalRequiredMonthly += result.requiredMonthlyContribution;
          break;
        case GoalFeasibilityStatus.overdue:
          overdueCount++;
          totalRequiredMonthly += result.requiredMonthlyContribution;
          break;
      }
    }

    // 6. Deterministic classification of overallGoalCapacityStatus
    final String overallStatus = _classifyOverallCapacity(
      totalGoals: goals.length,
      achievedGoals: achievedCount,
      unfeasibleGoals: unfeasibleCount,
      tightGoals: tightCount,
      overdueGoals: overdueCount,
      totalRequiredMonthly: totalRequiredMonthly,
      monthlySurplus: financialState.monthlySurplus,
      isDeficit: financialState.isDeficit,
      conflicts: conflictAnalysis.conflicts,
    );

    // 7. Deterministically analyze transaction patterns
    final transactionPatterns = _transactionPatternService.analyze(
      transactions,
      asOfDate: now,
    );

    final snapshot = GoalIntelligenceSnapshot(
      userId: userId,
      generatedAt: now,
      financialState: financialState,
      goalFeasibilityResults: feasibilityResults,
      conflicts: conflictAnalysis.conflicts,
      totalGoals: goals.length,
      achievableGoals: achievableCount,
      tightGoals: tightCount,
      unfeasibleGoals: unfeasibleCount,
      overdueGoals: overdueCount,
      achievedGoals: achievedCount,
      totalRequiredMonthlyGoalContribution: totalRequiredMonthly,
      availableMonthlyAmount: financialState.availableMonthlyAmount,
      overallGoalCapacityStatus: overallStatus,
      transactionPatterns: transactionPatterns,
    );

    _cachedSnapshots[userId] = snapshot;
    return snapshot;
  }

  /// Refreshes and rebuilds the snapshot, updating local cache and notifying listeners.
  Future<GoalIntelligenceSnapshot> refresh(
    String userId, {
    DateTime? asOfDate,
  }) async {
    final snapshot = await buildSnapshot(userId, asOfDate: asOfDate);
    notifyListeners();
    return snapshot;
  }

  /// Pure deterministic classifier for overall goal capacity status.
  ///
  /// Status values:
  /// - 'no_goals': User has no goals created.
  /// - 'conflicted': Monthly deficit, unfeasible goals, or aggregate goal requirements exceed available capacity.
  /// - 'tight': Goals consume most (> 70%) capacity or rely on savings buffer.
  /// - 'healthy': All active goals fit comfortably within monthly surplus.
  static String _classifyOverallCapacity({
    required int totalGoals,
    required int achievedGoals,
    required int unfeasibleGoals,
    required int tightGoals,
    required int overdueGoals,
    required double totalRequiredMonthly,
    required double monthlySurplus,
    required bool isDeficit,
    required List<FinancialConflict> conflicts,
  }) {
    if (totalGoals == 0) {
      return 'no_goals';
    }

    final activeGoalsCount = totalGoals - achievedGoals;
    if (activeGoalsCount == 0) {
      return 'healthy';
    }

    // Cash flow deficit with active goals is always conflicted
    if (isDeficit || monthlySurplus <= 0) {
      return 'conflicted';
    }

    // Overdue goals or completely unfeasible goals mark conflicted state
    if (unfeasibleGoals > 0 || overdueGoals > 0) {
      return 'conflicted';
    }

    // Multiple competing goals exceeding capacity or critical conflicts
    final hasCompetingGoalsConflict = conflicts.any(
      (c) => c.type == ConflictType.competingGoalsCapacityExceeded,
    );
    if (hasCompetingGoalsConflict) {
      return 'conflicted';
    }

    final hasCriticalConflicts = conflicts.any(
      (c) => c.severity == ConflictSeverity.critical,
    );
    if (hasCriticalConflicts) {
      return 'conflicted';
    }

    // Tight capacity: tight goals present or demand consumes > 70% of surplus
    final utilization = totalRequiredMonthly / monthlySurplus;
    if (tightGoals > 0 || utilization > 0.70) {
      return 'tight';
    }

    return 'healthy';
  }
}
