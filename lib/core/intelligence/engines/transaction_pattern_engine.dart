import 'dart:math' as math;
import '../../../features/transactions/models/transaction_model.dart';
import '../models/transaction_intelligence.dart';
import '../models/transaction_pattern_snapshot.dart';
import 'transaction_intelligence_engine.dart';

/// Pure, deterministic calculation engine for transaction collection patterns.
///
/// Follows the architecture flow:
/// TransactionModel -> TransactionIntelligence -> TransactionPatternEngine -> TransactionPatternSnapshot
abstract final class TransactionPatternEngine {
  /// Analyzes a collection of [TransactionModel]s and produces a [TransactionPatternSnapshot].
  ///
  /// Operates purely in-memory and does NOT mutate the input transactions.
  static TransactionPatternSnapshot analyze(
    List<TransactionModel> transactions, {
    DateTime? asOfDate,
  }) {
    final analyzedAt = asOfDate ?? DateTime.now();

    if (transactions.isEmpty) {
      return TransactionPatternSnapshot(analyzedAt: analyzedAt);
    }

    // Step 1: Map TransactionModel -> TransactionIntelligence (Architecture Requirement)
    final intelligenceList = transactions
        .map((tx) => TransactionIntelligenceEngine.analyzeTransaction(tx))
        .toList();

    return analyzeIntelligence(
      intelligenceList,
      originalTransactions: transactions,
      asOfDate: analyzedAt,
    );
  }

  /// Aggregates a list of already-analyzed [TransactionIntelligence] objects into [TransactionPatternSnapshot].
  static TransactionPatternSnapshot analyzeIntelligence(
    List<TransactionIntelligence> intelligenceList, {
    List<TransactionModel>? originalTransactions,
    DateTime? asOfDate,
  }) {
    final analyzedAt = asOfDate ?? DateTime.now();

    if (intelligenceList.isEmpty) {
      return TransactionPatternSnapshot(analyzedAt: analyzedAt);
    }

    int creditCount = 0;
    int debitCount = 0;
    double totalCredits = 0.0;
    double totalDebits = 0.0;
    double largestIncome = 0.0;
    double largestExpense = 0.0;

    final categoryTotals = <String, double>{};
    final merchantTotals = <String, double>{};

    for (final intel in intelligenceList) {
      if (intel.transactionType == TransactionType.credit) {
        creditCount++;
        totalCredits += intel.amount;
        if (intel.amount > largestIncome) {
          largestIncome = intel.amount;
        }
      } else if (intel.transactionType == TransactionType.debit) {
        debitCount++;
        totalDebits += intel.amount;
        if (intel.amount > largestExpense) {
          largestExpense = intel.amount;
        }

        // Category spending aggregation (using existing stored category)
        final categoryKey = intel.category.isNotEmpty
            ? intel.category
            : TransactionCategories.other;
        categoryTotals[categoryKey] =
            (categoryTotals[categoryKey] ?? 0.0) + intel.amount;

        // Merchant spending aggregation (using normalized merchant)
        final merchantKey = intel.normalizedMerchant.isNotEmpty
            ? intel.normalizedMerchant
            : intel.originalMerchantName;
        merchantTotals[merchantKey] =
            (merchantTotals[merchantKey] ?? 0.0) + intel.amount;
      }
    }

    final avgIncome = creditCount > 0 ? totalCredits / creditCount : 0.0;
    final avgExpense = debitCount > 0 ? totalDebits / debitCount : 0.0;

    // Detect recurring transaction candidates
    final recurringCandidates = detectRecurringCandidates(
      originalTransactions ??
          intelligenceList.map((i) => _toTransactionModel(i)).toList(),
    );

    return TransactionPatternSnapshot(
      totalTransactionCount: intelligenceList.length,
      totalIncome: totalCredits,
      totalExpenses: totalDebits,
      totalCredits: totalCredits,
      totalDebits: totalDebits,
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      averageExpense: double.parse(avgExpense.toStringAsFixed(2)),
      averageIncome: double.parse(avgIncome.toStringAsFixed(2)),
      categoryTotals: categoryTotals,
      merchantTotals: merchantTotals,
      recurringCandidates: recurringCandidates,
      analyzedAt: analyzedAt,
    );
  }

  /// Deterministically detects candidate recurring transactions across a transaction set.
  ///
  /// Criteria:
  /// - Same normalized merchant
  /// - Multiple occurrences (>= 2)
  /// - Similar amount (<= 15% variance or exact)
  /// - Regular intervals (e.g. monthly ~25-35d, weekly ~6-8d, bi-weekly ~13-16d)
  static List<RecurringTransactionCandidate> detectRecurringCandidates(
    List<TransactionModel> transactions,
  ) {
    final candidates = <RecurringTransactionCandidate>[];
    if (transactions.length < 2) return candidates;

    // Group by normalized merchant
    final groups = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key =
          TransactionIntelligenceEngine.normalizeMerchant(tx.merchantName);
      groups.putIfAbsent(key, () => []).add(tx);
    }

    for (final entry in groups.entries) {
      final merchant = entry.key;
      final group = entry.value;

      if (group.length < 2) continue;

      // Sort by date ascending
      final sorted = List<TransactionModel>.from(group)
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      final amounts = sorted.map((t) => t.amount).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      final maxAmount = amounts.reduce(math.max);
      final minAmount = amounts.reduce(math.min);

      // Amount consistency check (<= 15% variance)
      final amountVariance =
          avgAmount > 0 ? (maxAmount - minAmount) / avgAmount : 0.0;
      if (amountVariance > 0.15) {
        continue; // Inconsistent amounts do not qualify
      }

      // Interval consistency check
      final intervals = <int>[];
      for (int i = 0; i < sorted.length - 1; i++) {
        final diffDays =
            sorted[i + 1].dateTime.difference(sorted[i].dateTime).inDays.abs();
        intervals.add(diffDays);
      }

      final avgInterval =
          (intervals.reduce((a, b) => a + b) / intervals.length).round();

      final isMonthly = avgInterval >= 25 && avgInterval <= 35;
      final isWeekly = avgInterval >= 6 && avgInterval <= 8;
      final isBiWeekly = avgInterval >= 13 && avgInterval <= 16;
      final isQuarterly = avgInterval >= 85 && avgInterval <= 95;
      final isYearly = avgInterval >= 350 && avgInterval <= 375;

      final isRecognizedInterval =
          isMonthly || isWeekly || isBiWeekly || isQuarterly || isYearly;

      if (!isRecognizedInterval) {
        continue; // Not a recognized regular recurring cycle
      }

      // Check jitter across all intervals
      final maxJitter = intervals
          .map((interval) => (interval - avgInterval).abs())
          .reduce(math.max);

      // Monthly intervals tolerate up to 5 days variance; weekly up to 2 days
      final allowedJitter = isWeekly ? 2 : 5;
      if (maxJitter > allowedJitter) {
        continue; // Irregular dates should not automatically become recurring
      }

      // Deterministic Confidence Scoring
      IntelligenceConfidence confidence;
      final isExactAmount = amountVariance == 0.0;
      if (sorted.length >= 3 && isExactAmount && maxJitter <= 2) {
        confidence = IntelligenceConfidence.high;
      } else if (sorted.length >= 2 && amountVariance <= 0.10 && maxJitter <= 3) {
        confidence = IntelligenceConfidence.medium;
      } else {
        confidence = IntelligenceConfidence.low;
      }

      candidates.add(RecurringTransactionCandidate(
        merchant: merchant,
        averageAmount: double.parse(avgAmount.toStringAsFixed(2)),
        occurrenceCount: sorted.length,
        intervalDays: avgInterval,
        confidence: confidence,
      ));
    }

    return candidates;
  }

  static TransactionModel _toTransactionModel(TransactionIntelligence intel) {
    final now = intel.dateTime ?? DateTime.now();
    return TransactionModel(
      id: intel.transactionId,
      userId: '',
      amount: intel.amount,
      type: intel.transactionType,
      merchantName: intel.originalMerchantName,
      category: intel.category,
      dateTime: now,
      paymentMethod: intel.paymentMethod,
      notes: intel.notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}
