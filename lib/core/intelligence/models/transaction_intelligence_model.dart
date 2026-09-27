import 'dart:convert';
import '../../../features/transactions/models/transaction_model.dart';

/// Represents the deterministic financial impact of a transaction on cash flow.
enum FinancialImpact {
  income,
  expense,
  neutral;

  String get displayName {
    switch (this) {
      case FinancialImpact.income:
        return 'Income';
      case FinancialImpact.expense:
        return 'Expense';
      case FinancialImpact.neutral:
        return 'Neutral';
    }
  }

  static FinancialImpact fromString(String? val) {
    if (val == null) return FinancialImpact.neutral;
    return FinancialImpact.values.firstWhere(
      (i) => i.name.toLowerCase() == val.toLowerCase(),
      orElse: () => FinancialImpact.neutral,
    );
  }
}

/// Represents an enriched, deterministic intelligence snapshot for a single transaction.
///
/// Converts a raw transaction into a structured event ready for downstream agent consumption.
class TransactionIntelligence {
  final String transactionId;
  final double amount;
  final TransactionType transactionType;
  final String merchantName;
  final String normalizedMerchantName;
  final String category;
  final DateTime dateTime;
  final PaymentMethod paymentMethod;
  final String? notes;
  final FinancialImpact financialImpact;
  final bool isRecurringCandidate;
  final double confidence; // Deterministic classification score between 0.0 and 1.0
  final List<String> tags;

  const TransactionIntelligence({
    required this.transactionId,
    required this.amount,
    required this.transactionType,
    required this.merchantName,
    required this.normalizedMerchantName,
    required this.category,
    required this.dateTime,
    required this.paymentMethod,
    this.notes,
    required this.financialImpact,
    required this.isRecurringCandidate,
    required this.confidence,
    this.tags = const [],
  });

  bool get isIncome => financialImpact == FinancialImpact.income;
  bool get isExpense => financialImpact == FinancialImpact.expense;
  bool get isNeutral => financialImpact == FinancialImpact.neutral;

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'transactionType': transactionType.name,
      'merchantName': merchantName,
      'normalizedMerchantName': normalizedMerchantName,
      'category': category,
      'dateTime': dateTime.toIso8601String(),
      'paymentMethod': paymentMethod.name,
      'notes': notes,
      'financialImpact': financialImpact.name,
      'isRecurringCandidate': isRecurringCandidate,
      'confidence': confidence,
      'tags': tags,
    };
  }

  factory TransactionIntelligence.fromMap(Map<String, dynamic> map) {
    return TransactionIntelligence(
      transactionId: map['transactionId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType:
          TransactionType.fromString(map['transactionType'] as String?),
      merchantName: map['merchantName'] as String? ?? '',
      normalizedMerchantName: map['normalizedMerchantName'] as String? ?? '',
      category: map['category'] as String? ?? TransactionCategories.other,
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod:
          PaymentMethod.fromString(map['paymentMethod'] as String?),
      notes: map['notes'] as String?,
      financialImpact:
          FinancialImpact.fromString(map['financialImpact'] as String?),
      isRecurringCandidate:
          map['isRecurringCandidate'] as bool? ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionIntelligence.fromJson(String source) =>
      TransactionIntelligence.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TransactionIntelligence(id: $transactionId, merchant: $normalizedMerchantName, amount: $amount, impact: ${financialImpact.name}, recurring: $isRecurringCandidate)';
  }
}

/// Aggregated transaction metrics and summary for a given user or dataset.
class TransactionIntelligenceSummary {
  final String userId;
  final DateTime analyzedAt;
  final int transactionCount;
  final double totalIncome;
  final double totalExpenses;
  final double totalCredits;
  final double totalDebits;
  final double netCashFlow;
  final double averageTransactionAmount;
  final TransactionIntelligence? largestExpense;
  final TransactionIntelligence? largestIncome;
  final Map<String, double> spendingByCategory;
  final Map<String, double> spendingByMerchant;
  final int recurringCandidateCount;
  final List<TransactionIntelligence> recurringCandidates;

  const TransactionIntelligenceSummary({
    required this.userId,
    required this.analyzedAt,
    required this.transactionCount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalCredits,
    required this.totalDebits,
    required this.netCashFlow,
    required this.averageTransactionAmount,
    this.largestExpense,
    this.largestIncome,
    required this.spendingByCategory,
    required this.spendingByMerchant,
    required this.recurringCandidateCount,
    this.recurringCandidates = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'analyzedAt': analyzedAt.toIso8601String(),
      'transactionCount': transactionCount,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'totalCredits': totalCredits,
      'totalDebits': totalDebits,
      'netCashFlow': netCashFlow,
      'averageTransactionAmount': averageTransactionAmount,
      'largestExpense': largestExpense?.toMap(),
      'largestIncome': largestIncome?.toMap(),
      'spendingByCategory': spendingByCategory,
      'spendingByMerchant': spendingByMerchant,
      'recurringCandidateCount': recurringCandidateCount,
      'recurringCandidates':
          recurringCandidates.map((r) => r.toMap()).toList(),
    };
  }

  factory TransactionIntelligenceSummary.fromMap(Map<String, dynamic> map) {
    final recurringList = (map['recurringCandidates'] as List?)
            ?.map((e) =>
                TransactionIntelligence.fromMap(e as Map<String, dynamic>))
            .toList() ??
        <TransactionIntelligence>[];

    return TransactionIntelligenceSummary(
      userId: map['userId'] as String? ?? '',
      analyzedAt: map['analyzedAt'] != null
          ? DateTime.tryParse(map['analyzedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      totalIncome: (map['totalIncome'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      totalCredits: (map['totalCredits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (map['totalDebits'] as num?)?.toDouble() ?? 0.0,
      netCashFlow: (map['netCashFlow'] as num?)?.toDouble() ?? 0.0,
      averageTransactionAmount:
          (map['averageTransactionAmount'] as num?)?.toDouble() ?? 0.0,
      largestExpense: map['largestExpense'] != null
          ? TransactionIntelligence.fromMap(
              map['largestExpense'] as Map<String, dynamic>)
          : null,
      largestIncome: map['largestIncome'] != null
          ? TransactionIntelligence.fromMap(
              map['largestIncome'] as Map<String, dynamic>)
          : null,
      spendingByCategory: Map<String, double>.from(
          (map['spendingByCategory'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      )),
      spendingByMerchant: Map<String, double>.from(
          (map['spendingByMerchant'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      )),
      recurringCandidateCount:
          (map['recurringCandidateCount'] as num?)?.toInt() ?? 0,
      recurringCandidates: recurringList,
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionIntelligenceSummary.fromJson(String source) =>
      TransactionIntelligenceSummary.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
