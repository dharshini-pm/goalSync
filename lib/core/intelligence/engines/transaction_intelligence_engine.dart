import 'dart:math' as math;
import '../../../features/transactions/models/transaction_model.dart';
import '../models/transaction_intelligence.dart';

/// Pure, deterministic calculation and classification engine for financial transactions.
///
/// Responsibilities:
/// 1. Deterministic merchant name normalization
/// 2. Deterministic category inference for known merchants
/// 3. Deterministic financial impact mapping (Debit -> Expense, Credit -> Income)
/// 4. Deterministic confidence scoring (Known -> High, Unknown -> Low)
/// 5. Recurring transaction candidate evaluation
abstract final class TransactionIntelligenceEngine {
  static final RegExp _olaRegex =
      RegExp(r'(^|[^a-zA-Z0-9])ola([^a-zA-Z0-9]|$)', caseSensitive: false);

  /// Known merchant normalization rules (pattern -> canonical name).
  static const Map<String, String> _merchantRules = {
    'swiggy': 'Swiggy',
    'zomato': 'Zomato',
    'amazon': 'Amazon',
    'uber': 'Uber',
    'netflix': 'Netflix',
    'spotify': 'Spotify',
    'electricity board': 'Electricity Board',
    'flipkart': 'Flipkart',
    'starbucks': 'Starbucks',
    'blinkit': 'Blinkit',
    'zepto': 'Zepto',
    'bigbasket': 'BigBasket',
    'makemytrip': 'MakeMyTrip',
    'irctc': 'IRCTC',
    'google': 'Google',
    'apple': 'Apple',
    'airtel': 'Airtel',
    'jio': 'Jio',
    'apollo': 'Apollo',
    'practo': 'Practo',
  };

  /// Deterministically normalizes a merchant name string.
  /// If unknown or unable to match, returns original trimmed merchant name.
  /// Does not invent merchants.
  static String normalizeMerchant(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return rawName;

    final lower = trimmed.toLowerCase();

    // Check Ola specifically with boundary check to avoid false matches (e.g. chocolate)
    if (_olaRegex.hasMatch(lower)) {
      return 'Ola';
    }

    // Direct and substring matches for known merchants
    for (final entry in _merchantRules.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Preserve original if no match (do not invent merchants)
    return trimmed;
  }

  /// Whether a merchant name is recognized in the deterministic dictionary.
  static bool isKnownMerchant(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (_olaRegex.hasMatch(lower)) return true;

    return _merchantRules.keys.any((k) => lower.contains(k));
  }

  /// Deterministically infers an [InferredCategory] enum from merchant name.
  ///
  /// Mappings:
  /// - Swiggy, Zomato -> Food
  /// - Amazon -> Shopping
  /// - Uber, Ola -> Transport
  /// - Netflix, Spotify -> Entertainment
  /// - Electricity Board -> Utilities
  /// - Unknown -> Other
  static InferredCategory inferCategoryForMerchant(String merchantName) {
    final lower = merchantName.trim().toLowerCase();

    // Food & Dining
    if (lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('starbucks') ||
        lower.contains('mcdonald') ||
        lower.contains('domino') ||
        lower.contains('kfc') ||
        lower.contains('burger king') ||
        lower.contains('restaurant') ||
        lower.contains('cafe')) {
      return InferredCategory.food;
    }

    // Shopping
    if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra') ||
        lower.contains('ajio') ||
        lower.contains('zara') ||
        lower.contains('h&m') ||
        lower.contains('nykaa')) {
      return InferredCategory.shopping;
    }

    // Transport
    if (lower.contains('uber') ||
        _olaRegex.hasMatch(lower) ||
        lower.contains('rapido') ||
        lower.contains('metro') ||
        lower.contains('petrol') ||
        lower.contains('fuel')) {
      return InferredCategory.transport;
    }

    // Entertainment
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('prime video') ||
        lower.contains('hotstar') ||
        lower.contains('pvr') ||
        lower.contains('inox') ||
        lower.contains('bookmyshow')) {
      return InferredCategory.entertainment;
    }

    // Utilities
    if (lower.contains('electricity') ||
        lower.contains('bescom') ||
        lower.contains('water bill') ||
        lower.contains('gas bill') ||
        lower.contains('broadband') ||
        lower.contains('airtel') ||
        lower.contains('jio')) {
      return InferredCategory.utilities;
    }

    return InferredCategory.other;
  }

  /// Deterministically infers category for a transaction.
  /// Preserves existing category if present and valid; otherwise infers from merchant keywords.
  static String inferCategory({
    required String rawMerchant,
    required String currentCategory,
  }) {
    final catTrimmed = currentCategory.trim();
    if (catTrimmed.isNotEmpty &&
        catTrimmed != TransactionCategories.other &&
        catTrimmed.toLowerCase() != 'other') {
      return catTrimmed;
    }

    final inferred = inferCategoryForMerchant(rawMerchant);
    if (inferred == InferredCategory.food) {
      return TransactionCategories.foodAndDining;
    }
    return inferred.displayName;
  }

  /// Deterministically categorizes the cash flow impact of a transaction.
  ///
  /// Debit -> Expense
  /// Credit -> Income
  static FinancialImpact determineFinancialImpact(
    TransactionType type, [
    double? amount,
  ]) {
    if (amount != null && amount <= 0) return FinancialImpact.neutral;
    switch (type) {
      case TransactionType.credit:
        return FinancialImpact.income;
      case TransactionType.debit:
        return FinancialImpact.expense;
    }
  }

  /// Deterministically determines confidence level based on merchant recognition.
  ///
  /// Known deterministic merchant mapping -> high confidence
  /// Unknown merchant -> low confidence
  static IntelligenceConfidence determineConfidence({
    required String merchantName,
  }) {
    return isKnownMerchant(merchantName)
        ? IntelligenceConfidence.high
        : IntelligenceConfidence.low;
  }

  /// Calculates a deterministic confidence score (0.0 to 1.0) based on field completeness.
  static double calculateConfidence({
    required bool isTypeKnown,
    required bool isMerchantRecognized,
    required bool isCategoryRecognized,
  }) {
    double score = 0.50;
    if (isTypeKnown) score += 0.20;
    if (isMerchantRecognized) score += 0.15;
    if (isCategoryRecognized) score += 0.15;
    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Converts a single [TransactionModel] into a [TransactionIntelligence] instance.
  ///
  /// Does NOT modify the original [TransactionModel].
  static TransactionIntelligence analyzeTransaction(
    TransactionModel tx, {
    bool isRecurring = false,
  }) {
    final normalized = normalizeMerchant(tx.merchantName);
    final inferredCat = inferCategoryForMerchant(normalized);
    final impact = determineFinancialImpact(tx.type, tx.amount);
    final confidence = determineConfidence(merchantName: tx.merchantName);

    final tags = <String>[];
    if (isRecurring) tags.add('recurring_candidate');
    if (impact == FinancialImpact.income) tags.add('income');
    if (impact == FinancialImpact.expense) tags.add('expense');
    if (isKnownMerchant(tx.merchantName)) tags.add('verified_merchant');

    return TransactionIntelligence(
      transactionId: tx.id,
      normalizedMerchant: normalized,
      inferredCategory: inferredCat,
      transactionType: tx.type,
      financialImpact: impact,
      isRecurringCandidate: isRecurring,
      confidence: confidence,
      originalMerchantName: tx.merchantName,
      amount: tx.amount,
      dateTime: tx.dateTime,
      paymentMethod: tx.paymentMethod,
      notes: tx.notes,
      tags: tags,
      rawCategory: tx.category,
    );
  }

  /// Evaluates historical transaction patterns to identify candidate recurring transactions.
  static Set<String> findRecurringTransactionIds(
    List<TransactionModel> transactions,
  ) {
    final recurringIds = <String>{};
    if (transactions.length < 2) return recurringIds;

    // Group transactions by normalized merchant name
    final groups = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key = normalizeMerchant(tx.merchantName).toLowerCase();
      groups.putIfAbsent(key, () => []).add(tx);
    }

    for (final group in groups.values) {
      if (group.length < 2) continue;

      // Sort by transaction date ascending
      final sorted = List<TransactionModel>.from(group)
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      for (int i = 0; i < sorted.length - 1; i++) {
        final current = sorted[i];
        final next = sorted[i + 1];

        // 1. Amount consistency (within 15% variance or exact)
        final maxAmount = math.max(current.amount, next.amount);
        final minAmount = math.min(current.amount, next.amount);
        final isAmountConsistent =
            maxAmount > 0 && ((maxAmount - minAmount) / maxAmount) <= 0.15;

        // 2. Interval consistency
        final days = next.dateTime.difference(current.dateTime).inDays.abs();
        final isMonthly = days >= 25 && days <= 35;
        final isWeekly = days >= 6 && days <= 8;
        final isBiWeekly = days >= 13 && days <= 16;
        final isRegularInterval = isMonthly || isWeekly || isBiWeekly;

        if (isAmountConsistent && isRegularInterval) {
          recurringIds.add(current.id);
          recurringIds.add(next.id);
        }
      }
    }

    return recurringIds;
  }

  /// Transforms an entire list of [TransactionModel]s into [TransactionIntelligence] list.
  /// Does NOT modify the original input transactions.
  static List<TransactionIntelligence> analyzeAll(
    List<TransactionModel> transactions,
  ) {
    if (transactions.isEmpty) return const [];

    final recurringIds = findRecurringTransactionIds(transactions);

    return transactions
        .map((tx) => analyzeTransaction(
              tx,
              isRecurring: recurringIds.contains(tx.id),
            ))
        .toList();
  }

  /// Aggregates an analyzed list of transactions into a [TransactionIntelligenceSummary].
  static TransactionIntelligenceSummary summarize(
    List<TransactionIntelligence> items, {
    String userId = '',
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    if (items.isEmpty) {
      return TransactionIntelligenceSummary(
        userId: userId,
        analyzedAt: now,
        transactionCount: 0,
        totalIncome: 0.0,
        totalExpenses: 0.0,
        totalCredits: 0.0,
        totalDebits: 0.0,
        netCashFlow: 0.0,
        averageTransactionAmount: 0.0,
        spendingByCategory: const {},
        spendingByMerchant: const {},
        recurringCandidateCount: 0,
        recurringCandidates: const [],
      );
    }

    double totalCredits = 0.0;
    double totalDebits = 0.0;
    TransactionIntelligence? largestExpense;
    TransactionIntelligence? largestIncome;
    final categorySpending = <String, double>{};
    final merchantSpending = <String, double>{};
    final recurringCandidates = <TransactionIntelligence>[];

    for (final item in items) {
      if (item.transactionType == TransactionType.credit) {
        totalCredits += item.amount;
        if (largestIncome == null || item.amount > largestIncome.amount) {
          largestIncome = item;
        }
      } else if (item.transactionType == TransactionType.debit) {
        totalDebits += item.amount;
        if (largestExpense == null || item.amount > largestExpense.amount) {
          largestExpense = item;
        }

        // Aggregate debits by category
        categorySpending[item.category] =
            (categorySpending[item.category] ?? 0.0) + item.amount;

        // Aggregate debits by normalized merchant
        merchantSpending[item.normalizedMerchant] =
            (merchantSpending[item.normalizedMerchant] ?? 0.0) + item.amount;
      }

      if (item.isRecurringCandidate) {
        recurringCandidates.add(item);
      }
    }

    final totalVolume = totalCredits + totalDebits;
    final avgAmount =
        items.isNotEmpty ? totalVolume / items.length : 0.0;

    return TransactionIntelligenceSummary(
      userId: userId,
      analyzedAt: now,
      transactionCount: items.length,
      totalIncome: totalCredits,
      totalExpenses: totalDebits,
      totalCredits: totalCredits,
      totalDebits: totalDebits,
      netCashFlow: totalCredits - totalDebits,
      averageTransactionAmount:
          double.parse(avgAmount.toStringAsFixed(2)),
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      spendingByCategory: categorySpending,
      spendingByMerchant: merchantSpending,
      recurringCandidateCount: recurringCandidates.length,
      recurringCandidates: recurringCandidates,
    );
  }
}
