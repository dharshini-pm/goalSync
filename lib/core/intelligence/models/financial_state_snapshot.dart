import 'dart:convert';

/// Represents a deterministic, immutable snapshot of a user's calculated financial state.
///
/// Designed to be consumed by downstream intelligent agents (Financial State Agent,
/// Goal Agent, Conflict Agent, Scenario Agent, Explanation Agent).
class FinancialStateSnapshot {
  final String userId;
  final DateTime calculatedAt;

  // Primary income & expense figures
  final double totalMonthlyIncome;
  final double totalMonthlyExpenses;
  final double monthlyFixedExpenses;
  final double monthlyVariableExpenses;
  final double totalEmi;
  final int activeLoansCount;

  // Surplus & capacity
  final double monthlySurplus;
  final double savingsRate; // Percentage (e.g. 25.5 for 25.5%)
  final double savingsRateFraction; // Fraction (0.0 to 1.0)
  final double currentSavings;
  final double availableMonthlyAmount; // Non-negative available surplus capacity

  // Transaction actuals
  final double totalTransactionInflow;
  final double totalTransactionOutflow;
  final double netTransactionCashFlow;
  final int transactionCount;

  // Financial health ratios & metrics for downstream agents
  final bool isDeficit;
  final double expenseToIncomeRatio; // totalMonthlyExpenses / totalMonthlyIncome
  final double debtToIncomeRatio; // totalEmi / totalMonthlyIncome
  final double emergencyFundMonths; // currentSavings / totalMonthlyExpenses
  final Map<String, dynamic> metadata;

  const FinancialStateSnapshot({
    required this.userId,
    required this.calculatedAt,
    required this.totalMonthlyIncome,
    required this.totalMonthlyExpenses,
    required this.monthlyFixedExpenses,
    required this.monthlyVariableExpenses,
    required this.totalEmi,
    required this.activeLoansCount,
    required this.monthlySurplus,
    required this.savingsRate,
    required this.savingsRateFraction,
    required this.currentSavings,
    required this.availableMonthlyAmount,
    required this.totalTransactionInflow,
    required this.totalTransactionOutflow,
    required this.netTransactionCashFlow,
    this.transactionCount = 0,
    required this.isDeficit,
    required this.expenseToIncomeRatio,
    required this.debtToIncomeRatio,
    required this.emergencyFundMonths,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'calculatedAt': calculatedAt.toIso8601String(),
      'totalMonthlyIncome': totalMonthlyIncome,
      'totalMonthlyExpenses': totalMonthlyExpenses,
      'monthlyFixedExpenses': monthlyFixedExpenses,
      'monthlyVariableExpenses': monthlyVariableExpenses,
      'totalEmi': totalEmi,
      'activeLoansCount': activeLoansCount,
      'monthlySurplus': monthlySurplus,
      'savingsRate': savingsRate,
      'savingsRateFraction': savingsRateFraction,
      'currentSavings': currentSavings,
      'availableMonthlyAmount': availableMonthlyAmount,
      'totalTransactionInflow': totalTransactionInflow,
      'totalTransactionOutflow': totalTransactionOutflow,
      'netTransactionCashFlow': netTransactionCashFlow,
      'transactionCount': transactionCount,
      'isDeficit': isDeficit,
      'expenseToIncomeRatio': expenseToIncomeRatio,
      'debtToIncomeRatio': debtToIncomeRatio,
      'emergencyFundMonths': emergencyFundMonths,
      'metadata': metadata,
    };
  }

  factory FinancialStateSnapshot.fromMap(Map<String, dynamic> map) {
    return FinancialStateSnapshot(
      userId: map['userId'] as String? ?? '',
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalMonthlyIncome:
          (map['totalMonthlyIncome'] as num?)?.toDouble() ?? 0.0,
      totalMonthlyExpenses:
          (map['totalMonthlyExpenses'] as num?)?.toDouble() ?? 0.0,
      monthlyFixedExpenses:
          (map['monthlyFixedExpenses'] as num?)?.toDouble() ?? 0.0,
      monthlyVariableExpenses:
          (map['monthlyVariableExpenses'] as num?)?.toDouble() ?? 0.0,
      totalEmi: (map['totalEmi'] as num?)?.toDouble() ?? 0.0,
      activeLoansCount: (map['activeLoansCount'] as num?)?.toInt() ?? 0,
      monthlySurplus: (map['monthlySurplus'] as num?)?.toDouble() ?? 0.0,
      savingsRate: (map['savingsRate'] as num?)?.toDouble() ?? 0.0,
      savingsRateFraction:
          (map['savingsRateFraction'] as num?)?.toDouble() ?? 0.0,
      currentSavings: (map['currentSavings'] as num?)?.toDouble() ?? 0.0,
      availableMonthlyAmount:
          (map['availableMonthlyAmount'] as num?)?.toDouble() ?? 0.0,
      totalTransactionInflow:
          (map['totalTransactionInflow'] as num?)?.toDouble() ?? 0.0,
      totalTransactionOutflow:
          (map['totalTransactionOutflow'] as num?)?.toDouble() ?? 0.0,
      netTransactionCashFlow:
          (map['netTransactionCashFlow'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      isDeficit: map['isDeficit'] as bool? ?? false,
      expenseToIncomeRatio:
          (map['expenseToIncomeRatio'] as num?)?.toDouble() ?? 0.0,
      debtToIncomeRatio:
          (map['debtToIncomeRatio'] as num?)?.toDouble() ?? 0.0,
      emergencyFundMonths:
          (map['emergencyFundMonths'] as num?)?.toDouble() ?? 0.0,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory FinancialStateSnapshot.fromJson(String source) =>
      FinancialStateSnapshot.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FinancialStateSnapshot(userId: $userId, income: $totalMonthlyIncome, expenses: $totalMonthlyExpenses, surplus: $monthlySurplus, savingsRate: $savingsRate%)';
  }
}
