import 'dart:convert';
import '../../../features/transactions/models/transaction_model.dart';

/// Financial impact of a transaction on cash flow.
enum FinancialImpact {
  expense('Expense'),
  income('Income'),
  neutral('Neutral');

  final String displayName;
  const FinancialImpact(this.displayName);

  bool get isExpense => this == FinancialImpact.expense;
  bool get isIncome => this == FinancialImpact.income;
  bool get isNeutral => this == FinancialImpact.neutral;

  static FinancialImpact fromString(String? val) {
    if (val == null) return FinancialImpact.neutral;
    final lower = val.trim().toLowerCase();
    return FinancialImpact.values.firstWhere(
      (f) =>
          f.name.toLowerCase() == lower || f.displayName.toLowerCase() == lower,
      orElse: () => FinancialImpact.neutral,
    );
  }

  @override
  String toString() => displayName;
}

/// Inferred category for deterministic classification.
enum InferredCategory {
  food('Food'),
  shopping('Shopping'),
  transport('Transport'),
  entertainment('Entertainment'),
  utilities('Utilities'),
  other('Other');

  final String displayName;
  const InferredCategory(this.displayName);

  static InferredCategory fromString(String? val) {
    if (val == null) return InferredCategory.other;
    final lower = val.trim().toLowerCase();
    return InferredCategory.values.firstWhere(
      (c) =>
          c.name.toLowerCase() == lower || c.displayName.toLowerCase() == lower,
      orElse: () => InferredCategory.other,
    );
  }

  @override
  String toString() => displayName;
}

/// Confidence level for deterministic intelligence inferences.
enum IntelligenceConfidence {
  high('High', 0.9),
  medium('Medium', 0.6),
  low('Low', 0.3);

  final String displayName;
  final double score;
  const IntelligenceConfidence(this.displayName, this.score);

  bool get isHigh => this == IntelligenceConfidence.high;
  bool get isMedium => this == IntelligenceConfidence.medium;
  bool get isLow => this == IntelligenceConfidence.low;

  static IntelligenceConfidence fromString(String? val) {
    if (val == null) return IntelligenceConfidence.low;
    final lower = val.trim().toLowerCase();
    return IntelligenceConfidence.values.firstWhere(
      (c) =>
          c.name.toLowerCase() == lower || c.displayName.toLowerCase() == lower,
      orElse: () => IntelligenceConfidence.low,
    );
  }

  @override
  String toString() => displayName;
}

/// Alias for IntelligenceConfidence.
typedef ConfidenceLevel = IntelligenceConfidence;

/// Represents the derived intelligence understanding of a transaction.
///
/// This model contains ONLY derived intelligence fields.
/// Does NOT mutate the original TransactionModel.
class TransactionIntelligence {
  final String transactionId;
  final String normalizedMerchant;
  final InferredCategory inferredCategory;
  final TransactionType transactionType;
  final FinancialImpact financialImpact;
  final bool isRecurringCandidate;
  final IntelligenceConfidence confidence;
  final String originalMerchantName;

  // Contextual metadata for downstream engine support
  final double amount;
  final DateTime? dateTime;
  final PaymentMethod paymentMethod;
  final String? notes;
  final List<String> tags;
  final String? rawCategory;

  const TransactionIntelligence({
    required this.transactionId,
    required this.normalizedMerchant,
    required this.inferredCategory,
    required this.transactionType,
    required this.financialImpact,
    required this.isRecurringCandidate,
    required this.confidence,
    required this.originalMerchantName,
    this.amount = 0.0,
    this.dateTime,
    this.paymentMethod = PaymentMethod.other,
    this.notes,
    this.tags = const [],
    this.rawCategory,
  });

  // Convenience and backward-compatible getters
  String get normalizedMerchantName => normalizedMerchant;
  String get merchantName => originalMerchantName;
  String get category => (rawCategory != null &&
          rawCategory!.isNotEmpty &&
          rawCategory != 'Other' &&
          rawCategory != TransactionCategories.other)
      ? rawCategory!
      : (inferredCategory == InferredCategory.food
          ? TransactionCategories.foodAndDining
          : inferredCategory.displayName);
  double get confidenceScore => confidence.score;
  bool get isIncome => financialImpact == FinancialImpact.income;
  bool get isExpense => financialImpact == FinancialImpact.expense;
  bool get isNeutral => financialImpact == FinancialImpact.neutral;

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'normalizedMerchant': normalizedMerchant,
      'normalizedMerchantName': normalizedMerchant,
      'inferredCategory': inferredCategory.displayName,
      'category': category,
      'transactionType': transactionType.name,
      'financialImpact': financialImpact.name,
      'isRecurringCandidate': isRecurringCandidate,
      'confidence': confidence.name,
      'confidenceScore': confidence.score,
      'originalMerchantName': originalMerchantName,
      'merchantName': originalMerchantName,
      'amount': amount,
      'dateTime': dateTime?.toIso8601String(),
      'paymentMethod': paymentMethod.name,
      'notes': notes,
      'tags': tags,
      'rawCategory': rawCategory,
    };
  }

  factory TransactionIntelligence.fromMap(Map<String, dynamic> map) {
    final catStr = (map['inferredCategory'] ?? map['category']) as String?;
    final infCat = InferredCategory.fromString(catStr);
    final confVal = map['confidence'];
    IntelligenceConfidence conf;
    if (confVal is num) {
      conf = confVal >= 0.75
          ? IntelligenceConfidence.high
          : (confVal >= 0.5
              ? IntelligenceConfidence.medium
              : IntelligenceConfidence.low);
    } else {
      conf = IntelligenceConfidence.fromString(confVal as String?);
    }

    final normMerchant = (map['normalizedMerchant'] ??
        map['normalizedMerchantName'] ??
        '') as String;
    final origMerchant =
        (map['originalMerchantName'] ?? map['merchantName'] ?? '') as String;

    return TransactionIntelligence(
      transactionId: map['transactionId'] as String? ?? '',
      normalizedMerchant: normMerchant,
      inferredCategory: infCat,
      transactionType:
          TransactionType.fromString(map['transactionType'] as String?),
      financialImpact:
          FinancialImpact.fromString(map['financialImpact'] as String?),
      isRecurringCandidate: map['isRecurringCandidate'] as bool? ?? false,
      confidence: conf,
      originalMerchantName: origMerchant,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'] as String)
          : null,
      paymentMethod:
          PaymentMethod.fromString(map['paymentMethod'] as String?),
      notes: map['notes'] as String?,
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      rawCategory: map['rawCategory'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionIntelligence.fromJson(String source) =>
      TransactionIntelligence.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TransactionIntelligence(id: $transactionId, merchant: $normalizedMerchant, category: ${inferredCategory.displayName}, type: ${transactionType.displayName}, impact: ${financialImpact.displayName}, recurring: $isRecurringCandidate, confidence: ${confidence.displayName})';
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
