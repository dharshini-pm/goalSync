import 'dart:convert';
import 'financial_conflict_model.dart';
import 'financial_state_snapshot.dart';
import 'goal_feasibility_model.dart';

/// Represents a unified, immutable deterministic intelligence snapshot for a user.
///
/// Integrates calculated financial state, goal feasibility evaluations,
/// detected conflicts, and an overall goal capacity classification.
/// Designed for immediate consumption by UI components or downstream AI agents.
class GoalIntelligenceSnapshot {
  final String userId;
  final DateTime generatedAt;
  final FinancialStateSnapshot financialState;
  final List<GoalFeasibilityResult> goalFeasibilityResults;
  final List<FinancialConflict> conflicts;

  // Goal counts
  final int totalGoals;
  final int achievableGoals;
  final int tightGoals;
  final int unfeasibleGoals;
  final int overdueGoals;
  final int achievedGoals;

  // Capacity metrics
  final double totalRequiredMonthlyGoalContribution;
  final double availableMonthlyAmount;
  final String overallGoalCapacityStatus; // 'healthy', 'tight', 'conflicted', 'no_goals'

  const GoalIntelligenceSnapshot({
    required this.userId,
    required this.generatedAt,
    required this.financialState,
    required this.goalFeasibilityResults,
    required this.conflicts,
    required this.totalGoals,
    required this.achievableGoals,
    required this.tightGoals,
    required this.unfeasibleGoals,
    required this.overdueGoals,
    required this.achievedGoals,
    required this.totalRequiredMonthlyGoalContribution,
    required this.availableMonthlyAmount,
    required this.overallGoalCapacityStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'generatedAt': generatedAt.toIso8601String(),
      'financialState': financialState.toMap(),
      'goalFeasibilityResults':
          goalFeasibilityResults.map((r) => r.toMap()).toList(),
      'conflicts': conflicts.map((c) => c.toMap()).toList(),
      'totalGoals': totalGoals,
      'achievableGoals': achievableGoals,
      'tightGoals': tightGoals,
      'unfeasibleGoals': unfeasibleGoals,
      'overdueGoals': overdueGoals,
      'achievedGoals': achievedGoals,
      'totalRequiredMonthlyGoalContribution':
          totalRequiredMonthlyGoalContribution,
      'availableMonthlyAmount': availableMonthlyAmount,
      'overallGoalCapacityStatus': overallGoalCapacityStatus,
    };
  }

  factory GoalIntelligenceSnapshot.fromMap(Map<String, dynamic> map) {
    final feasibilityList = (map['goalFeasibilityResults'] as List?)
            ?.map((e) =>
                GoalFeasibilityResult.fromMap(e as Map<String, dynamic>))
            .toList() ??
        <GoalFeasibilityResult>[];

    final conflictList = (map['conflicts'] as List?)
            ?.map((e) => FinancialConflict.fromMap(e as Map<String, dynamic>))
            .toList() ??
        <FinancialConflict>[];

    return GoalIntelligenceSnapshot(
      userId: map['userId'] as String? ?? '',
      generatedAt: map['generatedAt'] != null
          ? DateTime.tryParse(map['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      financialState: FinancialStateSnapshot.fromMap(
          map['financialState'] as Map<String, dynamic>? ?? {}),
      goalFeasibilityResults: feasibilityList,
      conflicts: conflictList,
      totalGoals: (map['totalGoals'] as num?)?.toInt() ?? 0,
      achievableGoals: (map['achievableGoals'] as num?)?.toInt() ?? 0,
      tightGoals: (map['tightGoals'] as num?)?.toInt() ?? 0,
      unfeasibleGoals: (map['unfeasibleGoals'] as num?)?.toInt() ?? 0,
      overdueGoals: (map['overdueGoals'] as num?)?.toInt() ?? 0,
      achievedGoals: (map['achievedGoals'] as num?)?.toInt() ?? 0,
      totalRequiredMonthlyGoalContribution:
          (map['totalRequiredMonthlyGoalContribution'] as num?)?.toDouble() ??
              0.0,
      availableMonthlyAmount:
          (map['availableMonthlyAmount'] as num?)?.toDouble() ?? 0.0,
      overallGoalCapacityStatus:
          map['overallGoalCapacityStatus'] as String? ?? 'no_goals',
    );
  }

  String toJson() => json.encode(toMap());

  factory GoalIntelligenceSnapshot.fromJson(String source) =>
      GoalIntelligenceSnapshot.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'GoalIntelligenceSnapshot(userId: $userId, status: $overallGoalCapacityStatus, totalGoals: $totalGoals, achievable: $achievableGoals, reqMonthly: $totalRequiredMonthlyGoalContribution)';
  }
}
