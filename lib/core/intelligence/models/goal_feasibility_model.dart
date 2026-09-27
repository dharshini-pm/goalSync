import 'dart:convert';

/// Status representing deterministic evaluation of a goal's feasibility.
enum GoalFeasibilityStatus {
  achieved,
  comfortable,
  feasible,
  tight,
  unfeasible,
  overdue;

  String get displayName {
    switch (this) {
      case GoalFeasibilityStatus.achieved:
        return 'Achieved';
      case GoalFeasibilityStatus.comfortable:
        return 'Comfortable';
      case GoalFeasibilityStatus.feasible:
        return 'Feasible';
      case GoalFeasibilityStatus.tight:
        return 'Tight Capacity';
      case GoalFeasibilityStatus.unfeasible:
        return 'Unfeasible';
      case GoalFeasibilityStatus.overdue:
        return 'Overdue';
    }
  }

  static GoalFeasibilityStatus fromString(String? val) {
    if (val == null) return GoalFeasibilityStatus.unfeasible;
    return GoalFeasibilityStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == val.toLowerCase(),
      orElse: () => GoalFeasibilityStatus.unfeasible,
    );
  }
}

/// Represents the deterministic evaluation of a single goal's financial feasibility.
class GoalFeasibilityResult {
  final String goalId;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double remainingAmount;
  final DateTime targetDate;
  final DateTime asOfDate;
  final int daysRemaining;
  final int monthsRemaining;
  final double requiredMonthlyContribution;
  final double availableMonthlySurplus;
  final double surplusCoverageRatio; // available / required
  final double monthlyShortfall; // max(0, required - available)
  final bool isAchievableWithoutSavings;
  final bool isAchievableWithSavings;
  final DateTime? projectedCompletionDate;
  final GoalFeasibilityStatus status;
  final double feasibilityScore; // 0.0 to 100.0
  final String reason;
  final Map<String, dynamic> metadata;

  const GoalFeasibilityResult({
    required this.goalId,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.targetDate,
    required this.asOfDate,
    required this.daysRemaining,
    required this.monthsRemaining,
    required this.requiredMonthlyContribution,
    required this.availableMonthlySurplus,
    required this.surplusCoverageRatio,
    required this.monthlyShortfall,
    required this.isAchievableWithoutSavings,
    required this.isAchievableWithSavings,
    this.projectedCompletionDate,
    required this.status,
    required this.feasibilityScore,
    required this.reason,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'goalName': goalName,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'remainingAmount': remainingAmount,
      'targetDate': targetDate.toIso8601String(),
      'asOfDate': asOfDate.toIso8601String(),
      'daysRemaining': daysRemaining,
      'monthsRemaining': monthsRemaining,
      'requiredMonthlyContribution': requiredMonthlyContribution,
      'availableMonthlySurplus': availableMonthlySurplus,
      'surplusCoverageRatio': surplusCoverageRatio,
      'monthlyShortfall': monthlyShortfall,
      'isAchievableWithoutSavings': isAchievableWithoutSavings,
      'isAchievableWithSavings': isAchievableWithSavings,
      'projectedCompletionDate': projectedCompletionDate?.toIso8601String(),
      'status': status.name,
      'feasibilityScore': feasibilityScore,
      'reason': reason,
      'metadata': metadata,
    };
  }

  factory GoalFeasibilityResult.fromMap(Map<String, dynamic> map) {
    return GoalFeasibilityResult(
      goalId: map['goalId'] as String? ?? '',
      goalName: map['goalName'] as String? ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      asOfDate: map['asOfDate'] != null
          ? DateTime.tryParse(map['asOfDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      daysRemaining: (map['daysRemaining'] as num?)?.toInt() ?? 0,
      monthsRemaining: (map['monthsRemaining'] as num?)?.toInt() ?? 0,
      requiredMonthlyContribution:
          (map['requiredMonthlyContribution'] as num?)?.toDouble() ?? 0.0,
      availableMonthlySurplus:
          (map['availableMonthlySurplus'] as num?)?.toDouble() ?? 0.0,
      surplusCoverageRatio:
          (map['surplusCoverageRatio'] as num?)?.toDouble() ?? 0.0,
      monthlyShortfall: (map['monthlyShortfall'] as num?)?.toDouble() ?? 0.0,
      isAchievableWithoutSavings:
          map['isAchievableWithoutSavings'] as bool? ?? false,
      isAchievableWithSavings:
          map['isAchievableWithSavings'] as bool? ?? false,
      projectedCompletionDate: map['projectedCompletionDate'] != null
          ? DateTime.tryParse(map['projectedCompletionDate'] as String)
          : null,
      status: GoalFeasibilityStatus.fromString(map['status'] as String?),
      feasibilityScore: (map['feasibilityScore'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory GoalFeasibilityResult.fromJson(String source) =>
      GoalFeasibilityResult.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'GoalFeasibilityResult(goal: $goalName, status: ${status.name}, reqMonthly: $requiredMonthlyContribution, score: $feasibilityScore)';
  }
}
