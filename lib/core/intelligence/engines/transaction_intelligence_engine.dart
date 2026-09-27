import 'dart:math' as math;
import '../../../features/transactions/models/transaction_model.dart';
import '../models/transaction_intelligence_model.dart';

/// Pure, deterministic calculation and classification engine for financial transactions.
///
/// Features:
/// - Deterministic merchant name normalization
/// - Rule-based category inference with extensible dictionary
/// - Deterministic financial impact determination
/// - Historical pattern-based recurring candidate detection
/// - Multi-dimensional transaction aggregation
///
/// Designed to be extensible so future RAG / vector search can augment the rule dictionaries.
abstract final class TransactionIntelligenceEngine {
  /// Known merchant normalization rules (pattern -> canonical name).
  static const Map<String, String> _merchantRules = {
    'amazon pay': 'Amazon',
    'amazon.in': 'Amazon',
    'amazon retail': 'Amazon',
    'amazon': 'Amazon',
    'swiggy instamart': 'Swiggy',
    'swiggy food': 'Swiggy',
    'swiggy': 'Swiggy',
    'zomato order': 'Zomato',
    'zomato ltd': 'Zomato',
    'zomato': 'Zomato',
    'uber trip': 'Uber',
    'uber india': 'Uber',
    'uber': 'Uber',
    'ola cabs': 'Ola',
    'ola money': 'Ola',
    'ola': 'Ola',
    'netflix entertainment': 'Netflix',
    'netflix.com': 'Netflix',
    'netflix': 'Netflix',
    'spotify india': 'Spotify',
    'spotify ab': 'Spotify',
    'spotify': 'Spotify',
    'flipkart internet': 'Flipkart',
    'flipkart pay': 'Flipkart',
    'flipkart': 'Flipkart',
    'tata starbucks': 'Starbucks',
    'starbucks coffee': 'Starbucks',
    'starbucks': 'Starbucks',
    'blinkit commerce': 'Blinkit',
    'blinkit': 'Blinkit',
    'zepto market': 'Zepto',
    'zepto': 'Zepto',
    'bigbasket retail': 'BigBasket',
    'bigbasket': 'BigBasket',
    'bb daily': 'BigBasket',
    'makemytrip india': 'MakeMyTrip',
    'makemytrip': 'MakeMyTrip',
    'irctc ticket': 'IRCTC',
    'irctc': 'IRCTC',
    'google play': 'Google',
    'google services': 'Google',
    'google': 'Google',
    'apple services': 'Apple',
    'apple.com': 'Apple',
    'apple': 'Apple',
    'airtel prepaid': 'Airtel',
    'airtel bill': 'Airtel',
    'airtel': 'Airtel',
    'jio prepaid': 'Jio',
    'jio recharge': 'Jio',
    'jio': 'Jio',
    'apollo pharmacy': 'Apollo',
    'apollo 247': 'Apollo',
    'apollo': 'Apollo',
    'practo': 'Practo',
  };

  /// Merchant keyword to category mappings for deterministic inference.
  static const Map<String, String> _merchantToCategory = {
    // Food & Dining
    'swiggy': TransactionCategories.foodAndDining,
    'zomato': TransactionCategories.foodAndDining,
    'starbucks': TransactionCategories.foodAndDining,
    'mcdonald': TransactionCategories.foodAndDining,
    'domino': TransactionCategories.foodAndDining,
    'kfc': TransactionCategories.foodAndDining,
    'burger king': TransactionCategories.foodAndDining,
    'pizza hut': TransactionCategories.foodAndDining,
    'subway': TransactionCategories.foodAndDining,
    'restaurant': TransactionCategories.foodAndDining,
    'cafe': TransactionCategories.foodAndDining,

    // Shopping
    'amazon': TransactionCategories.shopping,
    'flipkart': TransactionCategories.shopping,
    'myntra': TransactionCategories.shopping,
    'ajio': TransactionCategories.shopping,
    'zara': TransactionCategories.shopping,
    'h&m': TransactionCategories.shopping,
    'nykaa': TransactionCategories.shopping,

    // Groceries
    'zepto': TransactionCategories.groceries,
    'blinkit': TransactionCategories.groceries,
    'bigbasket': TransactionCategories.groceries,
    'dmart': TransactionCategories.groceries,
    'supermarket': TransactionCategories.groceries,
    'grocery': TransactionCategories.groceries,

    // Transport
    'uber': TransactionCategories.transport,
    'ola': TransactionCategories.transport,
    'rapido': TransactionCategories.transport,
    'metro': TransactionCategories.transport,
    'petrol': TransactionCategories.transport,
    'fuel': TransactionCategories.transport,
    'hpcl': TransactionCategories.transport,
    'bpcl': TransactionCategories.transport,
    'iocl': TransactionCategories.transport,

    // Entertainment
    'netflix': TransactionCategories.entertainment,
    'spotify': TransactionCategories.entertainment,
    'prime video': TransactionCategories.entertainment,
    'hotstar': TransactionCategories.entertainment,
    'pvr': TransactionCategories.entertainment,
    'inox': TransactionCategories.entertainment,
    'bookmyshow': TransactionCategories.entertainment,

    // Bills & Utilities
    'airtel': TransactionCategories.billsAndUtilities,
    'jio': TransactionCategories.billsAndUtilities,
    'bescom': TransactionCategories.billsAndUtilities,
    'electricity': TransactionCategories.billsAndUtilities,
    'water bill': TransactionCategories.billsAndUtilities,
    'gas bill': TransactionCategories.billsAndUtilities,
    'broadband': TransactionCategories.billsAndUtilities,

    // Health & Medical
    'apollo': TransactionCategories.healthAndMedical,
    'practo': TransactionCategories.healthAndMedical,
    'pharmacy': TransactionCategories.healthAndMedical,
    '1mg': TransactionCategories.healthAndMedical,
    'pharmeasy': TransactionCategories.healthAndMedical,
    'hospital': TransactionCategories.healthAndMedical,
    'clinic': TransactionCategories.healthAndMedical,

    // Salary & Income
    'salary': TransactionCategories.salaryAndIncome,
    'payroll': TransactionCategories.salaryAndIncome,
    'tech corp': TransactionCategories.salaryAndIncome,

    // Investment
    'zerodha': TransactionCategories.investment,
    'groww': TransactionCategories.investment,
    'upstox': TransactionCategories.investment,
    'mutual fund': TransactionCategories.investment,
    'sip': TransactionCategories.investment,

    // Education
    'coursera': TransactionCategories.education,
    'udemy': TransactionCategories.education,
    'udacity': TransactionCategories.education,
    'school': TransactionCategories.education,
    'college': TransactionCategories.education,

    // Travel
    'makemytrip': 'Travel',
    'cleartrip': 'Travel',
    'indigo': 'Travel',
    'air india': 'Travel',
    'irctc': 'Travel',
    'booking.com': 'Travel',
  };

  /// Deterministically normalizes a merchant name string.
  /// If unknown or unable to match, returns original trimmed merchant name.
  static String normalizeMerchant(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return rawName;

    final lower = trimmed.toLowerCase();

    // 1. Direct and prefix matches from rules dictionary
    for (final entry in _merchantRules.entries) {
      if (lower == entry.key ||
          lower.startsWith(entry.key) ||
          lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Preserve original if no match
    return trimmed;
  }

  /// Whether a merchant name is recognized in the deterministic dictionary.
  static bool isKnownMerchant(String rawName) {
    final lower = rawName.trim().toLowerCase();
    return _merchantRules.keys
        .any((k) => lower == k || lower.startsWith(k) || lower.contains(k));
  }

  /// Deterministically infers category for a transaction.
  /// Preserves existing category if present and valid; otherwise infers from merchant keywords.
  static String inferCategory({
    required String rawMerchant,
    required String currentCategory,
  }) {
    final catTrimmed = currentCategory.trim();
    // Preserve existing category if valid and not Other/empty
    if (catTrimmed.isNotEmpty &&
        catTrimmed != TransactionCategories.other &&
        catTrimmed.toLowerCase() != 'other') {
      return catTrimmed;
    }

    final lowerMerchant = rawMerchant.trim().toLowerCase();
    for (final entry in _merchantToCategory.entries) {
      if (lowerMerchant.contains(entry.key)) {
        return entry.value;
      }
    }

    return TransactionCategories.other;
  }

  /// Deterministically categorizes the cash flow impact of a transaction.
  static FinancialImpact determineFinancialImpact(
    TransactionType type,
    double amount,
  ) {
    if (amount <= 0) return FinancialImpact.neutral;
    switch (type) {
      case TransactionType.credit:
        return FinancialImpact.income;
      case TransactionType.debit:
        return FinancialImpact.expense;
    }
  }

  /// Calculates a deterministic confidence score (0.0 to 1.0) based on field completeness.
  static double calculateConfidence({
    required bool isTypeKnown,
    required bool isMerchantRecognized,
    required bool isCategoryRecognized,
  }) {
    double score = 0.50; // Base score for a valid transaction
    if (isTypeKnown) score += 0.20;
    if (isMerchantRecognized) score += 0.15;
    if (isCategoryRecognized) score += 0.15;
    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Evaluates historical transaction patterns to identify candidate recurring transactions.
  ///
  /// Criteria:
  /// - At least 2 occurrences for the same normalized merchant
  /// - Consistent amounts (<= 15% variance or identical)
  /// - Regular intervals (monthly: ~25-35 days, weekly: ~6-8 days, or bi-weekly: ~13-16 days)
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

  /// Converts a single [TransactionModel] into a [TransactionIntelligence] instance.
  static TransactionIntelligence analyzeTransaction(
    TransactionModel tx, {
    bool isRecurring = false,
  }) {
    final normalized = normalizeMerchant(tx.merchantName);
    final category = inferCategory(
      rawMerchant: tx.merchantName,
      currentCategory: tx.category,
    );
    final impact = determineFinancialImpact(tx.type, tx.amount);
    final merchantKnown = isKnownMerchant(tx.merchantName);
    final categoryKnown = category != TransactionCategories.other;

    final confidence = calculateConfidence(
      isTypeKnown: true,
      isMerchantRecognized: merchantKnown,
      isCategoryRecognized: categoryKnown,
    );

    final tags = <String>[];
    if (isRecurring) tags.add('recurring_candidate');
    if (impact == FinancialImpact.income) tags.add('income');
    if (impact == FinancialImpact.expense) tags.add('expense');
    if (merchantKnown) tags.add('verified_merchant');

    return TransactionIntelligence(
      transactionId: tx.id,
      amount: tx.amount,
      transactionType: tx.type,
      merchantName: tx.merchantName,
      normalizedMerchantName: normalized,
      category: category,
      dateTime: tx.dateTime,
      paymentMethod: tx.paymentMethod,
      notes: tx.notes,
      financialImpact: impact,
      isRecurringCandidate: isRecurring,
      confidence: confidence,
      tags: tags,
    );
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
        merchantSpending[item.normalizedMerchantName] =
            (merchantSpending[item.normalizedMerchantName] ?? 0.0) +
                item.amount;
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
