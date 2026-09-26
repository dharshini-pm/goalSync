import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

/// Result wrapper for transaction operations.
class TransactionResult {
  final bool isSuccess;
  final String? errorMessage;
  final TransactionModel? transaction;

  const TransactionResult.success([this.transaction])
      : isSuccess = true,
        errorMessage = null;

  const TransactionResult.failure(this.errorMessage)
      : isSuccess = false,
        transaction = null;
}

/// Validation result for transaction inputs.
class TransactionValidationResult {
  final String? amountError;
  final String? merchantError;
  final String? categoryError;
  final String? dateError;

  const TransactionValidationResult({
    this.amountError,
    this.merchantError,
    this.categoryError,
    this.dateError,
  });

  bool get isValid =>
      amountError == null &&
      merchantError == null &&
      categoryError == null &&
      dateError == null;
}

/// Validates transaction inputs without side effects.
TransactionValidationResult validateTransactionInputs({
  required String amountRaw,
  required String merchantName,
  required String category,
  required DateTime? dateTime,
}) {
  String? amountError;
  String? merchantError;
  String? categoryError;
  String? dateError;

  final amount = double.tryParse(amountRaw.trim());
  if (amount == null) {
    amountError = 'Enter a valid transaction amount.';
  } else if (amount <= 0) {
    amountError = 'Amount must be greater than 0.';
  }

  if (merchantName.trim().isEmpty) {
    merchantError = 'Merchant name is required.';
  }

  if (category.trim().isEmpty) {
    categoryError = 'Category is required.';
  }

  if (dateTime == null) {
    dateError = 'Transaction date is required.';
  }

  return TransactionValidationResult(
    amountError: amountError,
    merchantError: merchantError,
    categoryError: categoryError,
    dateError: dateError,
  );
}

/// Local persistence service for user transactions.
class TransactionService extends ChangeNotifier {
  static TransactionService? _instance;
  static TransactionService get instance =>
      _instance ??= TransactionService._();

  TransactionService._();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static String _keyForUser(String userId) =>
      'goalsync_transactions_$userId';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize local storage.
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    notifyListeners();
  }

  /// Retrieve all transactions for a specific user, sorted newest first.
  List<TransactionModel> getTransactionsForUser(String userId) {
    final raw = _prefs?.getStringList(_keyForUser(userId)) ?? [];
    return raw
        .map((s) {
          try {
            return TransactionModel.fromJson(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<TransactionModel>()
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  /// Retrieve a specific transaction by id.
  TransactionModel? getTransactionById(String userId, String id) {
    final all = getTransactionsForUser(userId);
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Save raw transaction list for a user.
  Future<void> _saveTransactions(
    String userId,
    List<TransactionModel> transactions,
  ) async {
    final list = transactions.map((t) => t.toJson()).toList();
    await _prefs?.setStringList(_keyForUser(userId), list);
  }

  /// Create a new transaction for user after validation.
  Future<TransactionResult> createTransaction({
    required String userId,
    required String amountRaw,
    required TransactionType type,
    required String merchantName,
    required String category,
    required PaymentMethod paymentMethod,
    required DateTime? dateTime,
    String? notes,
  }) async {
    final validation = validateTransactionInputs(
      amountRaw: amountRaw,
      merchantName: merchantName,
      category: category,
      dateTime: dateTime,
    );

    if (!validation.isValid) {
      final errors = [
        validation.amountError,
        validation.merchantError,
        validation.categoryError,
        validation.dateError,
      ].whereType<String>().join(' ');
      return TransactionResult.failure(errors);
    }

    final now = DateTime.now();
    final transaction = TransactionModel(
      id: 'tx_${now.millisecondsSinceEpoch}',
      userId: userId,
      amount: double.parse(amountRaw.trim()),
      type: type,
      merchantName: merchantName.trim(),
      category: category.trim(),
      dateTime: dateTime!,
      paymentMethod: paymentMethod,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final current = getTransactionsForUser(userId);
    current.insert(0, transaction);
    await _saveTransactions(userId, current);

    notifyListeners();
    return TransactionResult.success(transaction);
  }

  /// Update an existing transaction.
  Future<TransactionResult> updateTransaction({
    required String userId,
    required String id,
    required String amountRaw,
    required TransactionType type,
    required String merchantName,
    required String category,
    required PaymentMethod paymentMethod,
    required DateTime? dateTime,
    String? notes,
  }) async {
    final validation = validateTransactionInputs(
      amountRaw: amountRaw,
      merchantName: merchantName,
      category: category,
      dateTime: dateTime,
    );

    if (!validation.isValid) {
      final errors = [
        validation.amountError,
        validation.merchantError,
        validation.categoryError,
        validation.dateError,
      ].whereType<String>().join(' ');
      return TransactionResult.failure(errors);
    }

    final current = getTransactionsForUser(userId);
    final index = current.indexWhere((t) => t.id == id);
    if (index == -1) {
      return const TransactionResult.failure('Transaction not found.');
    }

    final existing = current[index];
    final updated = existing.copyWith(
      amount: double.parse(amountRaw.trim()),
      type: type,
      merchantName: merchantName.trim(),
      category: category.trim(),
      dateTime: dateTime,
      paymentMethod: paymentMethod,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      updatedAt: DateTime.now(),
    );

    current[index] = updated;
    await _saveTransactions(userId, current);

    notifyListeners();
    return TransactionResult.success(updated);
  }

  /// Delete a transaction by id.
  Future<bool> deleteTransaction(String userId, String id) async {
    final current = getTransactionsForUser(userId);
    final beforeCount = current.length;
    current.removeWhere((t) => t.id == id);
    if (current.length == beforeCount) return false;

    await _saveTransactions(userId, current);
    notifyListeners();
    return true;
  }

  /// Calculate total outflow (Debits) for a user.
  double getTotalDebit(String userId) {
    return getTransactionsForUser(userId)
        .where((t) => t.isDebit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate total inflow (Credits) for a user.
  double getTotalCredit(String userId) {
    return getTransactionsForUser(userId)
        .where((t) => t.isCredit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Net cash flow: Credits - Debits.
  double getNetCashFlow(String userId) {
    return getTotalCredit(userId) - getTotalDebit(userId);
  }

  /// Total count of transactions for user.
  int getTotalCount(String userId) {
    return getTransactionsForUser(userId).length;
  }
}
