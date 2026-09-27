import '../../../features/transactions/models/transaction_model.dart';
import '../engines/transaction_pattern_engine.dart';
import '../models/transaction_pattern_snapshot.dart';

/// Pure, in-memory analysis service for transaction collection patterns.
///
/// Responsibilities:
/// - Takes a [List<TransactionModel>] and produces a [TransactionPatternSnapshot].
/// - Purely in-memory and deterministic.
/// - Completely independent of Flutter UI, backend APIs, and MongoDB.
/// - Does NOT mutate or persist any transaction records.
class TransactionPatternService {
  const TransactionPatternService();

  /// Primary analysis method: accepts a collection of [TransactionModel]s and produces derived [TransactionPatternSnapshot].
  ///
  /// Safe for empty lists, single transactions, and arbitrary input sets.
  TransactionPatternSnapshot analyze(
    List<TransactionModel> transactions, {
    DateTime? asOfDate,
  }) {
    return TransactionPatternEngine.analyze(
      transactions,
      asOfDate: asOfDate,
    );
  }
}
