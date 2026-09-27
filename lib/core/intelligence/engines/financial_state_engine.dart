import 'dart:math' as math;
import '../../../features/onboarding/models/financial_profile_model.dart';
import '../../../features/transactions/models/transaction_model.dart';
import '../models/financial_state_snapshot.dart';

/// Pure, deterministic calculation engine for user financial states.
///
/// Rules:
/// - 100% code-based, zero LLM or heuristic guessing.
/// - Operates strictly on verified user data or passed parameters.
/// - Never generates random, mock, or fake numbers.
abstract final class FinancialStateEngine {
  /// Calculate combined monthly income (primary salary/business + additional income streams).
  static double calculateTotalIncome({
    required double monthlyIncome,
    double additionalIncome = 0.0,
  }) {
    final primary = monthlyIncome > 0 ? monthlyIncome : 0.0;
    final additional = additionalIncome > 0 ? additionalIncome : 0.0;
    return primary + additional;
  }

  /// Calculate combined monthly expenses including fixed overhead, variable lifestyle, and debt EMI.
  static double calculateTotalExpenses({
    required double fixedExpenses,
    required double variableExpenses,
    required double loanEmi,
  }) {
    final fixed = fixedExpenses > 0 ? fixedExpenses : 0.0;
    final variable = variableExpenses > 0 ? variableExpenses : 0.0;
    final emi = loanEmi > 0 ? loanEmi : 0.0;
    return fixed + variable + emi;
  }

  /// Calculate monthly cash surplus (income minus expenses).
  /// A positive number indicates a surplus; a negative number indicates a deficit.
  static double calculateMonthlySurplus({
    required double totalIncome,
    required double totalExpenses,
  }) {
    return totalIncome - totalExpenses;
  }

  /// Calculate savings rate as a percentage (e.g. 25.0 for 25%).
  /// Returns 0.0 if in deficit or if income is non-positive.
  static double calculateSavingsRate({
    required double totalIncome,
    required double monthlySurplus,
  }) {
    if (totalIncome <= 0 || monthlySurplus <= 0) return 0.0;
    return (monthlySurplus / totalIncome) * 100.0;
  }

  /// Calculate savings rate as a normalized fraction (0.0 to 1.0).
  static double calculateSavingsRateFraction({
    required double totalIncome,
    required double monthlySurplus,
  }) {
    if (totalIncome <= 0 || monthlySurplus <= 0) return 0.0;
    return (monthlySurplus / totalIncome).clamp(0.0, 1.0);
  }

  /// Calculate available monthly amount remaining for goal commitments or investments.
  /// If surplus is negative or already committed, returns 0.0.
  static double calculateAvailableMonthlyAmount({
    required double monthlySurplus,
    double committedMonthlyGoals = 0.0,
  }) {
    if (monthlySurplus <= 0) return 0.0;
    final remaining = monthlySurplus - math.max(0.0, committedMonthlyGoals);
    return math.max(0.0, remaining);
  }

  /// Calculate total transaction inflow (credits) from a list of transactions,
  /// optionally bounded by a date range.
  static double calculateTransactionInflow(
    List<TransactionModel> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return transactions.where((t) {
      if (!t.isCredit) return false;
      if (startDate != null && t.dateTime.isBefore(startDate)) return false;
      if (endDate != null && t.dateTime.isAfter(endDate)) return false;
      return true;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate total transaction outflow (debits) from a list of transactions,
  /// optionally bounded by a date range.
  static double calculateTransactionOutflow(
    List<TransactionModel> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return transactions.where((t) {
      if (!t.isDebit) return false;
      if (startDate != null && t.dateTime.isBefore(startDate)) return false;
      if (endDate != null && t.dateTime.isAfter(endDate)) return false;
      return true;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate net cash flow (inflow minus outflow) from transactions.
  static double calculateNetTransactionCashFlow(
    List<TransactionModel> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final inflow = calculateTransactionInflow(
      transactions,
      startDate: startDate,
      endDate: endDate,
    );
    final outflow = calculateTransactionOutflow(
      transactions,
      startDate: startDate,
      endDate: endDate,
    );
    return inflow - outflow;
  }

  /// Produce a complete deterministic [FinancialStateSnapshot] from a user's
  /// [FinancialProfile] and optional [TransactionModel] history.
  static FinancialStateSnapshot computeState({
    required FinancialProfile profile,
    List<TransactionModel>? transactions,
    DateTime? asOfDate,
    double committedMonthlyGoals = 0.0,
  }) {
    final now = asOfDate ?? DateTime.now();
    final txList = transactions ?? const <TransactionModel>[];

    final totalIncome = calculateTotalIncome(
      monthlyIncome: profile.monthlyIncome,
      additionalIncome: profile.additionalIncome,
    );

    final totalExpenses = calculateTotalExpenses(
      fixedExpenses: profile.monthlyFixedExpenses,
      variableExpenses: profile.monthlyVariableExpenses,
      loanEmi: profile.existingLoanEmi,
    );

    final surplus = calculateMonthlySurplus(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
    );

    final savingsRate = calculateSavingsRate(
      totalIncome: totalIncome,
      monthlySurplus: surplus,
    );

    final savingsRateFraction = calculateSavingsRateFraction(
      totalIncome: totalIncome,
      monthlySurplus: surplus,
    );

    final availableMonthly = calculateAvailableMonthlyAmount(
      monthlySurplus: surplus,
      committedMonthlyGoals: committedMonthlyGoals,
    );

    final txInflow = calculateTransactionInflow(txList);
    final txOutflow = calculateTransactionOutflow(txList);
    final netCashFlow = txInflow - txOutflow;

    final isDeficit = surplus < 0;
    final expenseToIncome =
        totalIncome > 0 ? (totalExpenses / totalIncome) : 0.0;
    final debtToIncome =
        totalIncome > 0 ? (profile.existingLoanEmi / totalIncome) : 0.0;
    final emergencyFundMonths =
        totalExpenses > 0 ? (profile.currentSavings / totalExpenses) : 0.0;

    return FinancialStateSnapshot(
      userId: profile.userId,
      calculatedAt: now,
      totalMonthlyIncome: totalIncome,
      totalMonthlyExpenses: totalExpenses,
      monthlyFixedExpenses: profile.monthlyFixedExpenses,
      monthlyVariableExpenses: profile.monthlyVariableExpenses,
      totalEmi: profile.existingLoanEmi,
      activeLoansCount: profile.activeLoansCount,
      monthlySurplus: surplus,
      savingsRate: savingsRate,
      savingsRateFraction: savingsRateFraction,
      currentSavings: profile.currentSavings,
      availableMonthlyAmount: availableMonthly,
      totalTransactionInflow: txInflow,
      totalTransactionOutflow: txOutflow,
      netTransactionCashFlow: netCashFlow,
      transactionCount: txList.length,
      isDeficit: isDeficit,
      expenseToIncomeRatio: expenseToIncome,
      debtToIncomeRatio: debtToIncome,
      emergencyFundMonths: emergencyFundMonths,
      metadata: {
        'incomeType': profile.incomeType,
        'occupation': profile.occupation,
        'dependents': profile.dependents,
        'hasEmergencyBuffer': emergencyFundMonths >= 3.0,
      },
    );
  }

  /// Produce a [FinancialStateSnapshot] from discrete primitive values.
  static FinancialStateSnapshot computeStateFromValues({
    required String userId,
    required double monthlyIncome,
    double additionalIncome = 0.0,
    required double fixedExpenses,
    required double variableExpenses,
    required double loanEmi,
    required double currentSavings,
    int activeLoansCount = 0,
    double totalTransactionInflow = 0.0,
    double totalTransactionOutflow = 0.0,
    int transactionCount = 0,
    double committedMonthlyGoals = 0.0,
    DateTime? asOfDate,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = asOfDate ?? DateTime.now();

    final totalIncome = calculateTotalIncome(
      monthlyIncome: monthlyIncome,
      additionalIncome: additionalIncome,
    );

    final totalExpenses = calculateTotalExpenses(
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      loanEmi: loanEmi,
    );

    final surplus = calculateMonthlySurplus(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
    );

    final savingsRate = calculateSavingsRate(
      totalIncome: totalIncome,
      monthlySurplus: surplus,
    );

    final savingsRateFraction = calculateSavingsRateFraction(
      totalIncome: totalIncome,
      monthlySurplus: surplus,
    );

    final availableMonthly = calculateAvailableMonthlyAmount(
      monthlySurplus: surplus,
      committedMonthlyGoals: committedMonthlyGoals,
    );

    final netCashFlow = totalTransactionInflow - totalTransactionOutflow;
    final isDeficit = surplus < 0;
    final expenseToIncome =
        totalIncome > 0 ? (totalExpenses / totalIncome) : 0.0;
    final debtToIncome = totalIncome > 0 ? (loanEmi / totalIncome) : 0.0;
    final emergencyFundMonths =
        totalExpenses > 0 ? (currentSavings / totalExpenses) : 0.0;

    return FinancialStateSnapshot(
      userId: userId,
      calculatedAt: now,
      totalMonthlyIncome: totalIncome,
      totalMonthlyExpenses: totalExpenses,
      monthlyFixedExpenses: fixedExpenses,
      monthlyVariableExpenses: variableExpenses,
      totalEmi: loanEmi,
      activeLoansCount: activeLoansCount,
      monthlySurplus: surplus,
      savingsRate: savingsRate,
      savingsRateFraction: savingsRateFraction,
      currentSavings: currentSavings,
      availableMonthlyAmount: availableMonthly,
      totalTransactionInflow: totalTransactionInflow,
      totalTransactionOutflow: totalTransactionOutflow,
      netTransactionCashFlow: netCashFlow,
      transactionCount: transactionCount,
      isDeficit: isDeficit,
      expenseToIncomeRatio: expenseToIncome,
      debtToIncomeRatio: debtToIncome,
      emergencyFundMonths: emergencyFundMonths,
      metadata: metadata,
    );
  }
}
