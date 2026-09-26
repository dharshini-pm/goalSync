import 'dart:convert';

/// Represents whether a transaction is an outflow (Debit) or inflow (Credit).
enum TransactionType {
  debit,
  credit;

  String get displayName => this == TransactionType.debit ? 'Debit' : 'Credit';

  static TransactionType fromString(String? val) {
    if (val == null) return TransactionType.debit;
    return TransactionType.values.firstWhere(
      (t) => t.name.toLowerCase() == val.toLowerCase() ||
          t.displayName.toLowerCase() == val.toLowerCase(),
      orElse: () => TransactionType.debit,
    );
  }
}

/// Supported payment methods in GoalSync.
enum PaymentMethod {
  upi,
  card,
  netBanking,
  cash,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromString(String? val) {
    if (val == null) return PaymentMethod.other;
    return PaymentMethod.values.firstWhere(
      (m) => m.name.toLowerCase() == val.toLowerCase() ||
          m.displayName.toLowerCase() == val.toLowerCase(),
      orElse: () => PaymentMethod.other,
    );
  }
}

/// Standard transaction categories.
abstract final class TransactionCategories {
  static const String foodAndDining = 'Food & Dining';
  static const String shopping = 'Shopping';
  static const String groceries = 'Groceries';
  static const String billsAndUtilities = 'Bills & Utilities';
  static const String entertainment = 'Entertainment';
  static const String transport = 'Transport';
  static const String healthAndMedical = 'Health & Medical';
  static const String investment = 'Investment';
  static const String salaryAndIncome = 'Salary & Income';
  static const String transfer = 'Transfer';
  static const String education = 'Education';
  static const String other = 'Other';

  static const List<String> all = [
    foodAndDining,
    shopping,
    groceries,
    billsAndUtilities,
    entertainment,
    transport,
    healthAndMedical,
    investment,
    salaryAndIncome,
    transfer,
    education,
    other,
  ];
}

/// Represents a financial transaction record in GoalSync.
class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String merchantName;
  final String category;
  final DateTime dateTime;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.merchantName,
    required this.category,
    required this.dateTime,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDebit => type == TransactionType.debit;
  bool get isCredit => type == TransactionType.credit;

  /// Returns clean currency representation (e.g. ₹500 or ₹1,250.50).
  String get formattedAmount {
    final isInt = amount.truncateToDouble() == amount;
    final valStr = isInt
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₹$valStr';
  }

  /// Returns signed currency representation (e.g. - ₹500 or + ₹1,250.50).
  String get signedFormattedAmount {
    final prefix = isCredit ? '+' : '-';
    return '$prefix $formattedAmount';
  }

  /// Formatted date: "26 Sep 2026"
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dateTime.month - 1];
    return '${dateTime.day} $m ${dateTime.year}';
  }

  /// Formatted time: "02:30 PM"
  String get formattedTime {
    final h24 = dateTime.hour;
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '${h12.toString().padLeft(2, '0')}:$min $period';
  }

  /// Combined formatted date and time.
  String get formattedDateTime => '$formattedDate, $formattedTime';

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? merchantName,
    String? category,
    DateTime? dateTime,
    PaymentMethod? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'merchantName': merchantName,
      'category': category,
      'dateTime': dateTime.toIso8601String(),
      'paymentMethod': paymentMethod.name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.fromString(map['type'] as String?),
      merchantName: map['merchantName'] as String,
      category: map['category'] as String? ?? TransactionCategories.other,
      dateTime: DateTime.parse(map['dateTime'] as String),
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] as String?),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionModel.fromJson(String source) =>
      TransactionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id && other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
