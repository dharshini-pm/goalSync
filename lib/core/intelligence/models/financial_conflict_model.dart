import 'dart:convert';

/// Categorization of deterministic financial conflicts.
enum ConflictType {
  cashFlowDeficit,
  singleGoalSurplusExceeded,
  competingGoalsCapacityExceeded,
  newExpenseSurplusReduction,
  highDebtBurden,
  lowEmergencyBuffer,
  goalOverdue;

  String get displayName {
    switch (this) {
      case ConflictType.cashFlowDeficit:
        return 'Cash Flow Deficit';
      case ConflictType.singleGoalSurplusExceeded:
        return 'Goal Exceeds Surplus';
      case ConflictType.competingGoalsCapacityExceeded:
        return 'Competing Goals Over Capacity';
      case ConflictType.newExpenseSurplusReduction:
        return 'Expense Threatens Surplus';
      case ConflictType.highDebtBurden:
        return 'High Debt / EMI Burden';
      case ConflictType.lowEmergencyBuffer:
        return 'Low Emergency Buffer';
      case ConflictType.goalOverdue:
        return 'Goal Overdue';
    }
  }

  static ConflictType fromString(String? val) {
    if (val == null) return ConflictType.cashFlowDeficit;
    return ConflictType.values.firstWhere(
      (t) => t.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ConflictType.cashFlowDeficit,
    );
  }
}

/// Severity grading for financial conflicts.
enum ConflictSeverity {
  critical,
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case ConflictSeverity.critical:
        return 'Critical';
      case ConflictSeverity.high:
        return 'High';
      case ConflictSeverity.medium:
        return 'Medium';
      case ConflictSeverity.low:
        return 'Low';
    }
  }

  static ConflictSeverity fromString(String? val) {
    if (val == null) return ConflictSeverity.medium;
    return ConflictSeverity.values.firstWhere(
      (s) => s.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ConflictSeverity.medium,
    );
  }
}

/// Standardized action types suggested by the deterministic conflict engine
/// for downstream agents (e.g. Conflict Agent or Scenario Agent) to explore.
enum SuggestedActionType {
  reduceExpenses,
  extendGoalTimeline,
  reduceGoalTarget,
  prioritizeGoals,
  pauseDiscretionaryGoals,
  increaseIncome,
  buildEmergencyFund;

  static SuggestedActionType fromString(String? val) {
    if (val == null) return SuggestedActionType.prioritizeGoals;
    return SuggestedActionType.values.firstWhere(
      (a) => a.name.toLowerCase() == val.toLowerCase(),
      orElse: () => SuggestedActionType.prioritizeGoals,
    );
  }
}

/// Represents a single identified financial conflict.
class FinancialConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final String title;
  final String description;
  final List<String> affectedGoalIds;
  final double monthlyShortfall;
  final SuggestedActionType suggestedAction;
  final String actionSuggestionText;
  final Map<String, dynamic> metrics;
  final DateTime detectedAt;

  const FinancialConflict({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.affectedGoalIds = const [],
    this.monthlyShortfall = 0.0,
    required this.suggestedAction,
    required this.actionSuggestionText,
    this.metrics = const {},
    required this.detectedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'affectedGoalIds': affectedGoalIds,
      'monthlyShortfall': monthlyShortfall,
      'suggestedAction': suggestedAction.name,
      'actionSuggestionText': actionSuggestionText,
      'metrics': metrics,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  factory FinancialConflict.fromMap(Map<String, dynamic> map) {
    return FinancialConflict(
      id: map['id'] as String? ?? '',
      type: ConflictType.fromString(map['type'] as String?),
      severity: ConflictSeverity.fromString(map['severity'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      affectedGoalIds: (map['affectedGoalIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      monthlyShortfall: (map['monthlyShortfall'] as num?)?.toDouble() ?? 0.0,
      suggestedAction:
          SuggestedActionType.fromString(map['suggestedAction'] as String?),
      actionSuggestionText: map['actionSuggestionText'] as String? ?? '',
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? {}),
      detectedAt: map['detectedAt'] != null
          ? DateTime.tryParse(map['detectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FinancialConflict.fromJson(String source) =>
      FinancialConflict.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FinancialConflict(title: $title, severity: ${severity.name}, shortfall: $monthlyShortfall)';
  }
}

/// Result of evaluating all potential financial conflicts for a user.
class ConflictAnalysisResult {
  final bool hasConflicts;
  final List<FinancialConflict> conflicts;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final double totalMonthlyGoalDemand;
  final double availableSurplus;
  final double netCapacityRemaining; // availableSurplus - totalMonthlyGoalDemand
  final DateTime evaluatedAt;

  const ConflictAnalysisResult({
    required this.hasConflicts,
    required this.conflicts,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.totalMonthlyGoalDemand,
    required this.availableSurplus,
    required this.netCapacityRemaining,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'hasConflicts': hasConflicts,
      'conflicts': conflicts.map((c) => c.toMap()).toList(),
      'criticalCount': criticalCount,
      'highCount': highCount,
      'mediumCount': mediumCount,
      'lowCount': lowCount,
      'totalMonthlyGoalDemand': totalMonthlyGoalDemand,
      'availableSurplus': availableSurplus,
      'netCapacityRemaining': netCapacityRemaining,
      'evaluatedAt': evaluatedAt.toIso8601String(),
    };
  }

  factory ConflictAnalysisResult.fromMap(Map<String, dynamic> map) {
    final conflictList = (map['conflicts'] as List?)
            ?.map((e) => FinancialConflict.fromMap(e as Map<String, dynamic>))
            .toList() ??
        <FinancialConflict>[];

    return ConflictAnalysisResult(
      hasConflicts: map['hasConflicts'] as bool? ?? conflictList.isNotEmpty,
      conflicts: conflictList,
      criticalCount: (map['criticalCount'] as num?)?.toInt() ?? 0,
      highCount: (map['highCount'] as num?)?.toInt() ?? 0,
      mediumCount: (map['mediumCount'] as num?)?.toInt() ?? 0,
      lowCount: (map['lowCount'] as num?)?.toInt() ?? 0,
      totalMonthlyGoalDemand:
          (map['totalMonthlyGoalDemand'] as num?)?.toDouble() ?? 0.0,
      availableSurplus: (map['availableSurplus'] as num?)?.toDouble() ?? 0.0,
      netCapacityRemaining:
          (map['netCapacityRemaining'] as num?)?.toDouble() ?? 0.0,
      evaluatedAt: map['evaluatedAt'] != null
          ? DateTime.tryParse(map['evaluatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ConflictAnalysisResult.fromJson(String source) =>
      ConflictAnalysisResult.fromMap(
          json.decode(source) as Map<String, dynamic>);
}

/// Result of evaluating the deterministic impact of a proposed or new expense.
class ExpenseImpactResult {
  final double proposedExpenseAmount;
  final double previousSurplus;
  final double newSurplus;
  final double surplusDelta;
  final double surplusReductionPercentage;
  final bool causesDeficit;
  final List<String> affectedGoalIds;
  final List<FinancialConflict> generatedConflicts;
  final DateTime evaluatedAt;

  const ExpenseImpactResult({
    required this.proposedExpenseAmount,
    required this.previousSurplus,
    required this.newSurplus,
    required this.surplusDelta,
    required this.surplusReductionPercentage,
    required this.causesDeficit,
    required this.affectedGoalIds,
    required this.generatedConflicts,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'proposedExpenseAmount': proposedExpenseAmount,
      'previousSurplus': previousSurplus,
      'newSurplus': newSurplus,
      'surplusDelta': surplusDelta,
      'surplusReductionPercentage': surplusReductionPercentage,
      'causesDeficit': causesDeficit,
      'affectedGoalIds': affectedGoalIds,
      'generatedConflicts': generatedConflicts.map((c) => c.toMap()).toList(),
      'evaluatedAt': evaluatedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());
}
