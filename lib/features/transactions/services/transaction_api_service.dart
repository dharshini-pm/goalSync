import '../../../core/api/api_client.dart';
import '../models/transaction_model.dart';

/// API Service managing transaction CRUD operations against the FastAPI backend.
class TransactionApiService {
  final ApiClient _client;

  TransactionApiService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// Retrieve all transactions for the authenticated user: GET /transactions.
  Future<List<TransactionModel>> getTransactions() async {
    final response = await _client.get('/transactions', requiresAuth: true);
    if (response is List) {
      return response
          .map((item) => _mapToTransactionModel(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieve a single transaction by ID: GET /transactions/{transaction_id}.
  Future<TransactionModel> getTransactionById(String transactionId) async {
    final response =
        await _client.get('/transactions/$transactionId', requiresAuth: true);
    return _mapToTransactionModel(response as Map<String, dynamic>);
  }

  /// Create a transaction on backend: POST /transactions.
  Future<TransactionModel> createTransaction({
    required double amount,
    required TransactionType type,
    required String merchantName,
    required String category,
    required DateTime dateTime,
    required PaymentMethod paymentMethod,
    String? notes,
  }) async {
    final response = await _client.post(
      '/transactions',
      requiresAuth: true,
      body: {
        'amount': amount,
        'type': type == TransactionType.credit ? 'credit' : 'debit',
        'merchantName': merchantName.trim(),
        'category': category.trim(),
        'dateTime': dateTime.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod.name,
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      },
    );
    return _mapToTransactionModel(response as Map<String, dynamic>);
  }

  /// Update an existing transaction: PUT /transactions/{transaction_id}.
  Future<TransactionModel> updateTransaction({
    required String transactionId,
    double? amount,
    TransactionType? type,
    String? merchantName,
    String? category,
    DateTime? dateTime,
    PaymentMethod? paymentMethod,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    if (type != null) {
      body['type'] = type == TransactionType.credit ? 'credit' : 'debit';
    }
    if (merchantName != null) body['merchantName'] = merchantName.trim();
    if (category != null) body['category'] = category.trim();
    if (dateTime != null) {
      body['dateTime'] = dateTime.toUtc().toIso8601String();
    }
    if (paymentMethod != null) body['paymentMethod'] = paymentMethod.name;
    if (notes != null) {
      body['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final response = await _client.put(
      '/transactions/$transactionId',
      requiresAuth: true,
      body: body,
    );
    return _mapToTransactionModel(response as Map<String, dynamic>);
  }

  /// Delete a transaction: DELETE /transactions/{transaction_id}.
  Future<void> deleteTransaction(String transactionId) async {
    await _client.delete('/transactions/$transactionId', requiresAuth: true);
  }

  TransactionModel _mapToTransactionModel(Map<String, dynamic> map) {
    final id = (map['_id'] ?? map['id'] ?? '').toString();
    final userId = (map['userId'] ?? '').toString();
    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    final typeStr = (map['type'] ?? 'debit').toString().toLowerCase();
    final merchant = (map['merchantName'] ?? '').toString();
    final category = (map['category'] ?? TransactionCategories.other).toString();
    final dtStr = map['dateTime']?.toString();
    final dateTime = dtStr != null
        ? DateTime.tryParse(dtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final paymentStr = (map['paymentMethod'] ?? 'other').toString();
    final notes = map['notes'] as String?;
    final createdAtStr = map['createdAt']?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final updatedAtStr = map['updatedAt']?.toString();
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return TransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: typeStr == 'credit' ? TransactionType.credit : TransactionType.debit,
      merchantName: merchant,
      category: category,
      dateTime: dateTime,
      paymentMethod: PaymentMethod.fromString(paymentStr),
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
