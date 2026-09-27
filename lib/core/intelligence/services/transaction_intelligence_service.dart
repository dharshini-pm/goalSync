import 'package:flutter/foundation.dart';
import '../../../features/transactions/models/transaction_model.dart';
import '../../../features/transactions/services/transaction_service.dart';
import '../engines/transaction_intelligence_engine.dart';
import '../models/transaction_intelligence_model.dart';

/// Service orchestrating deterministic transaction intelligence for users.
///
/// Features:
/// - Transforms raw [TransactionModel] objects into enriched [TransactionIntelligence] objects.
/// - Produces aggregated [TransactionIntelligenceSummary] metrics.
/// - Operates purely in-memory; does NOT mutate underlying stored transactions.
class TransactionIntelligenceService extends ChangeNotifier {
  static TransactionIntelligenceService? _instance;
  static TransactionIntelligenceService get instance =>
      _instance ??= TransactionIntelligenceService._();

  final TransactionService _transactionService;
  final Map<String, List<TransactionIntelligence>> _cachedTransactions = {};
  final Map<String, TransactionIntelligenceSummary> _cachedSummaries = {};

  TransactionIntelligenceService({
    TransactionService? transactionService,
  }) : _transactionService =
            transactionService ?? TransactionService.instance;

  TransactionIntelligenceService._()
      : _transactionService = TransactionService.instance;

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Get cached intelligence transactions for a user, if available.
  List<TransactionIntelligence>? getCachedTransactions(String userId) =>
      _cachedTransactions[userId];

  /// Get cached intelligence summary for a user, if available.
  TransactionIntelligenceSummary? getCachedSummary(String userId) =>
      _cachedSummaries[userId];

  /// Loads, enriches, and analyzes all transactions for the given user.
  Future<List<TransactionIntelligence>> analyzeTransactions(
    String userId,
  ) async {
    if (!_transactionService.isInitialized) {
      await _transactionService.init();
    }

    final rawTransactions =
        _transactionService.getTransactionsForUser(userId);
    final enriched =
        TransactionIntelligenceEngine.analyzeAll(rawTransactions);

    _cachedTransactions[userId] = enriched;
    return enriched;
  }

  /// Builds a deterministic [TransactionIntelligenceSummary] for the given user.
  Future<TransactionIntelligenceSummary> buildSummary(
    String userId, {
    DateTime? asOfDate,
  }) async {
    final enriched = await analyzeTransactions(userId);
    final summary = TransactionIntelligenceEngine.summarize(
      enriched,
      userId: userId,
      asOfDate: asOfDate,
    );

    _cachedSummaries[userId] = summary;
    return summary;
  }

  /// Refreshes and rebuilds transaction intelligence, notifying listeners.
  Future<TransactionIntelligenceSummary> refresh(
    String userId, {
    DateTime? asOfDate,
  }) async {
    final summary = await buildSummary(userId, asOfDate: asOfDate);
    notifyListeners();
    return summary;
  }

  /// Direct in-memory analysis helper for arbitrary lists of transactions.
  List<TransactionIntelligence> analyze(List<TransactionModel> transactions) {
    return TransactionIntelligenceEngine.analyzeAll(transactions);
  }

  /// Direct in-memory summary helper for arbitrary lists of transactions.
  TransactionIntelligenceSummary summarize(
    List<TransactionModel> transactions, {
    String userId = '',
    DateTime? asOfDate,
  }) {
    final enriched = analyze(transactions);
    return TransactionIntelligenceEngine.summarize(
      enriched,
      userId: userId,
      asOfDate: asOfDate,
    );
  }
}
