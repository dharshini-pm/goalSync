import 'package:flutter/foundation.dart';
import '../../../features/transactions/models/transaction_model.dart';
import '../../../features/transactions/services/transaction_service.dart';
import '../engines/transaction_intelligence_engine.dart';
import '../models/transaction_intelligence.dart';

/// Pure analysis service orchestrating deterministic transaction intelligence.
///
/// Accepts an existing [TransactionModel] and produces derived [TransactionIntelligence].
///
/// Important:
/// - Does NOT mutate or save the original [TransactionModel].
/// - Functions purely as an in-memory analysis layer.
/// - Remains completely independent of Flutter UI and backend APIs.
class TransactionIntelligenceService extends ChangeNotifier {
  static TransactionIntelligenceService? _instance;
  static TransactionIntelligenceService get instance =>
      _instance ??= TransactionIntelligenceService._();

  final TransactionService? _transactionService;
  final Map<String, List<TransactionIntelligence>> _cachedTransactions = {};
  final Map<String, TransactionIntelligenceSummary> _cachedSummaries = {};

  TransactionIntelligenceService({
    TransactionService? transactionService,
  }) : _transactionService = transactionService;

  TransactionIntelligenceService._() : _transactionService = null;

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Primary analysis method: accepts an existing [TransactionModel] and returns derived [TransactionIntelligence].
  ///
  /// Does NOT modify or save the original transaction.
  TransactionIntelligence analyze(TransactionModel transaction) {
    return TransactionIntelligenceEngine.analyzeTransaction(transaction);
  }

  /// Convenience alias for [analyze].
  TransactionIntelligence analyzeTransaction(TransactionModel transaction) {
    return analyze(transaction);
  }

  /// Direct in-memory analysis helper for arbitrary lists of transactions.
  /// Does NOT modify any of the input transactions.
  List<TransactionIntelligence> analyzeAll(List<TransactionModel> transactions) {
    return TransactionIntelligenceEngine.analyzeAll(transactions);
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
    final service = _transactionService ?? TransactionService.instance;
    if (!service.isInitialized) {
      await service.init();
    }

    final rawTransactions = service.getTransactionsForUser(userId);
    final enriched = TransactionIntelligenceEngine.analyzeAll(rawTransactions);

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

  /// Direct in-memory summary helper for arbitrary lists of transactions.
  TransactionIntelligenceSummary summarize(
    List<TransactionModel> transactions, {
    String userId = '',
    DateTime? asOfDate,
  }) {
    final enriched = analyzeAll(transactions);
    return TransactionIntelligenceEngine.summarize(
      enriched,
      userId: userId,
      asOfDate: asOfDate,
    );
  }
}
