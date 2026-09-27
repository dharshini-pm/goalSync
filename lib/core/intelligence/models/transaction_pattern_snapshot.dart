import 'dart:convert';
import 'transaction_intelligence.dart';

/// Represents a detected recurring transaction pattern candidate.
///
/// NOTE: This is a deterministic candidate indicator only, NOT a guarantee of recurring billing.
class RecurringTransactionCandidate {
  final String merchant;
  final double averageAmount;
  final int occurrenceCount;
  final int intervalDays;
  final IntelligenceConfidence confidence;

  const RecurringTransactionCandidate({
    required this.merchant,
    required this.averageAmount,
    required this.occurrenceCount,
    required this.intervalDays,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'merchant': merchant,
      'averageAmount': averageAmount,
      'occurrenceCount': occurrenceCount,
      'intervalDays': intervalDays,
      'confidence': confidence.name,
      'confidenceLevel': confidence.displayName,
    };
  }

  factory RecurringTransactionCandidate.fromMap(Map<String, dynamic> map) {
    return RecurringTransactionCandidate(
      merchant: map['merchant'] as String? ?? '',
      averageAmount: (map['averageAmount'] as num?)?.toDouble() ?? 0.0,
      occurrenceCount: (map['occurrenceCount'] as num?)?.toInt() ?? 0,
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
      confidence: IntelligenceConfidence.fromString(
        map['confidence'] as String? ?? map['confidenceLevel'] as String?,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory RecurringTransactionCandidate.fromJson(String source) =>
      RecurringTransactionCandidate.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'RecurringTransactionCandidate(merchant: $merchant, avgAmount: $averageAmount, count: $occurrenceCount, intervalDays: $intervalDays, confidence: ${confidence.displayName})';
  }
}

/// Derived intelligence snapshot aggregating transaction patterns across a collection.
class TransactionPatternSnapshot {
  final int totalTransactionCount;
  final double totalIncome;
  final double totalExpenses;
  final double totalCredits;
  final double totalDebits;
  final double largestExpense;
  final double largestIncome;
  final double averageExpense;
  final double averageIncome;
  final Map<String, double> categoryTotals;
  final Map<String, double> merchantTotals;
  final List<RecurringTransactionCandidate> recurringCandidates;
  final DateTime? _analyzedAt;
  DateTime get analyzedAt => _analyzedAt ?? DateTime.now();

  const TransactionPatternSnapshot({
    this.totalTransactionCount = 0,
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.totalCredits = 0.0,
    this.totalDebits = 0.0,
    this.largestExpense = 0.0,
    this.largestIncome = 0.0,
    this.averageExpense = 0.0,
    this.averageIncome = 0.0,
    this.categoryTotals = const {},
    this.merchantTotals = const {},
    this.recurringCandidates = const [],
    DateTime? analyzedAt,
  }) : _analyzedAt = analyzedAt;

  double get netCashFlow => totalIncome - totalExpenses;
  bool get hasRecurringCandidates => recurringCandidates.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'totalTransactionCount': totalTransactionCount,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'totalCredits': totalCredits,
      'totalDebits': totalDebits,
      'largestExpense': largestExpense,
      'largestIncome': largestIncome,
      'averageExpense': averageExpense,
      'averageIncome': averageIncome,
      'categoryTotals': categoryTotals,
      'merchantTotals': merchantTotals,
      'recurringCandidates':
          recurringCandidates.map((c) => c.toMap()).toList(),
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  factory TransactionPatternSnapshot.fromMap(Map<String, dynamic> map) {
    final recurringList = (map['recurringCandidates'] as List?)
            ?.map((e) =>
                RecurringTransactionCandidate.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const <RecurringTransactionCandidate>[];

    return TransactionPatternSnapshot(
      totalTransactionCount:
          (map['totalTransactionCount'] as num?)?.toInt() ?? 0,
      totalIncome: (map['totalIncome'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      totalCredits: (map['totalCredits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (map['totalDebits'] as num?)?.toDouble() ?? 0.0,
      largestExpense: (map['largestExpense'] as num?)?.toDouble() ?? 0.0,
      largestIncome: (map['largestIncome'] as num?)?.toDouble() ?? 0.0,
      averageExpense: (map['averageExpense'] as num?)?.toDouble() ?? 0.0,
      averageIncome: (map['averageIncome'] as num?)?.toDouble() ?? 0.0,
      categoryTotals: Map<String, double>.from(
          (map['categoryTotals'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      )),
      merchantTotals: Map<String, double>.from(
          (map['merchantTotals'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      )),
      recurringCandidates: recurringList,
      analyzedAt: map['analyzedAt'] != null
          ? DateTime.tryParse(map['analyzedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionPatternSnapshot.fromJson(String source) =>
      TransactionPatternSnapshot.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TransactionPatternSnapshot(count: $totalTransactionCount, income: $totalIncome, expenses: $totalExpenses, recurringCandidates: ${recurringCandidates.length})';
  }
}

