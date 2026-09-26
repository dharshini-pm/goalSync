import 'dart:convert';

/// Financial Profile model capturing user-entered onboarding data.
class FinancialProfile {
  final String userId;
  final int age;
  final String occupation;
  final int dependents;
  final double monthlyIncome;
  final String incomeType;
  final double additionalIncome;
  final double currentSavings;
  final double monthlyFixedExpenses;
  final double monthlyVariableExpenses;
  final double existingLoanEmi;
  final int activeLoansCount;
  final bool isCompleted;
  final DateTime completedAt;

  const FinancialProfile({
    required this.userId,
    required this.age,
    required this.occupation,
    required this.dependents,
    required this.monthlyIncome,
    required this.incomeType,
    this.additionalIncome = 0.0,
    required this.currentSavings,
    required this.monthlyFixedExpenses,
    required this.monthlyVariableExpenses,
    required this.existingLoanEmi,
    required this.activeLoansCount,
    this.isCompleted = true,
    required this.completedAt,
  });

  /// Total combined monthly income.
  double get totalMonthlyIncome => monthlyIncome + additionalIncome;

  /// Total monthly expenses including loans.
  double get totalMonthlyExpenses =>
      monthlyFixedExpenses + monthlyVariableExpenses + existingLoanEmi;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'age': age,
      'occupation': occupation,
      'dependents': dependents,
      'monthlyIncome': monthlyIncome,
      'incomeType': incomeType,
      'additionalIncome': additionalIncome,
      'currentSavings': currentSavings,
      'monthlyFixedExpenses': monthlyFixedExpenses,
      'monthlyVariableExpenses': monthlyVariableExpenses,
      'existingLoanEmi': existingLoanEmi,
      'activeLoansCount': activeLoansCount,
      'isCompleted': isCompleted,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory FinancialProfile.fromMap(Map<String, dynamic> map) {
    return FinancialProfile(
      userId: map['userId'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 18,
      occupation: map['occupation'] as String? ?? '',
      dependents: (map['dependents'] as num?)?.toInt() ?? 0,
      monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      incomeType: map['incomeType'] as String? ?? 'Salary',
      additionalIncome: (map['additionalIncome'] as num?)?.toDouble() ?? 0.0,
      currentSavings: (map['currentSavings'] as num?)?.toDouble() ?? 0.0,
      monthlyFixedExpenses:
          (map['monthlyFixedExpenses'] as num?)?.toDouble() ?? 0.0,
      monthlyVariableExpenses:
          (map['monthlyVariableExpenses'] as num?)?.toDouble() ?? 0.0,
      existingLoanEmi: (map['existingLoanEmi'] as num?)?.toDouble() ?? 0.0,
      activeLoansCount: (map['activeLoansCount'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FinancialProfile.fromJson(String source) =>
      FinancialProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}
