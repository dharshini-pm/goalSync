import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Result object for authentication operations.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? user;

  const AuthResult.success([this.user])
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null;
}

/// Local authentication service managing user registration, login, and session persistence.
class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static const String _keyIsLoggedIn = 'goalsync_is_logged_in';
  static const String _keyCurrentUserId = 'goalsync_current_user_id';
  static const String _keyUsersList = 'goalsync_registered_users';

  SharedPreferences? _prefs;
  UserModel? _currentUser;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _prefs?.getBool(_keyIsLoggedIn) ?? false;
  UserModel? get currentUser => _currentUser;

  /// Initialize local storage and restore existing session if any.
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    _prefs = await SharedPreferences.getInstance();

    final isLogged = _prefs?.getBool(_keyIsLoggedIn) ?? false;
    final currentUserId = _prefs?.getString(_keyCurrentUserId);

    if (isLogged && currentUserId != null) {
      _currentUser = _getUserById(currentUserId);
      if (_currentUser == null) {
        // Inconsistent state, reset session
        await _clearSession();
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Hash password using SHA-256 for secure local storage.
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Retrieve all registered users stored locally.
  List<UserModel> _getAllUsers() {
    final usersRaw = _prefs?.getStringList(_keyUsersList) ?? [];
    return usersRaw
        .map((str) {
          try {
            return UserModel.fromJson(str);
          } catch (_) {
            return null;
          }
        })
        .whereType<UserModel>()
        .toList();
  }

  /// Save the updated user list to local storage.
  Future<void> _saveAllUsers(List<UserModel> users) async {
    final list = users.map((u) => u.toJson()).toList();
    await _prefs?.setStringList(_keyUsersList, list);
  }

  UserModel? _getUserById(String id) {
    final users = _getAllUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Register a new user and automatically start session.
  Future<AuthResult> register({
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
    required String password,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedName.isEmpty) {
      return const AuthResult.failure('Full name is required.');
    }
    if (trimmedPhone.isEmpty) {
      return const AuthResult.failure('Phone number is required.');
    }
    if (trimmedEmail.isEmpty) {
      return const AuthResult.failure('Email is required.');
    }

    final users = _getAllUsers();

    // Check email uniqueness
    final emailExists = users.any(
      (u) => u.email.toLowerCase().trim() == trimmedEmail,
    );
    if (emailExists) {
      return const AuthResult.failure(
        'An account with this email already exists.',
      );
    }

    // Check phone uniqueness
    final phoneExists = users.any(
      (u) =>
          u.phone.replaceAll(RegExp(r'\D'), '').trim() == trimmedPhone &&
          u.countryCode == countryCode,
    );
    if (phoneExists) {
      return const AuthResult.failure(
        'An account with this phone number already exists.',
      );
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      fullName: trimmedName,
      phone: trimmedPhone,
      countryCode: countryCode,
      email: trimmedEmail,
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now(),
    );

    users.add(newUser);
    await _saveAllUsers(users);

    // Save session
    await _setSession(newUser);
    _currentUser = newUser;
    notifyListeners();

    return AuthResult.success(newUser);
  }

  /// Authenticate with email or phone + password.
  Future<AuthResult> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final input = emailOrPhone.trim();
    final passwordHash = _hashPassword(password);
    final users = _getAllUsers();

    UserModel? matchedUser;

    // Check if input matches email
    final isEmail = input.contains('@');
    if (isEmail) {
      try {
        matchedUser = users.firstWhere(
          (u) => u.email.toLowerCase().trim() == input.toLowerCase(),
        );
      } catch (_) {
        matchedUser = null;
      }
    } else {
      // Check phone match (clean digits)
      final cleanDigits = input.replaceAll(RegExp(r'\D'), '');
      try {
        matchedUser = users.firstWhere(
          (u) =>
              u.phone.replaceAll(RegExp(r'\D'), '') == cleanDigits ||
              '${u.countryCode}${u.phone}'.replaceAll(RegExp(r'\D'), '') ==
                  cleanDigits,
        );
      } catch (_) {
        matchedUser = null;
      }
    }

    if (matchedUser == null || matchedUser.passwordHash != passwordHash) {
      return const AuthResult.failure('Invalid email/phone or password.');
    }

    await _setSession(matchedUser);
    _currentUser = matchedUser;
    notifyListeners();

    return AuthResult.success(matchedUser);
  }

  /// Log out current user and clear local session state.
  Future<void> logout() async {
    await _clearSession();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _setSession(UserModel user) async {
    await _prefs?.setBool(_keyIsLoggedIn, true);
    await _prefs?.setString(_keyCurrentUserId, user.id);
  }

  Future<void> _clearSession() async {
    await _prefs?.setBool(_keyIsLoggedIn, false);
    await _prefs?.remove(_keyCurrentUserId);
  }
}
