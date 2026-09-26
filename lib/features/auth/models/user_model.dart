import 'dart:convert';

/// Represents an authenticated user in GoalSync.
class UserModel {
  final String id;
  final String fullName;
  final String phone;
  final String countryCode;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.countryCode,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  /// Full phone number with country code.
  String get fullPhoneNumber => '$countryCode $phone'.trim();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'countryCode': countryCode,
      'email': email,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '+91',
      email: map['email'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
