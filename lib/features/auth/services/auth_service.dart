import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api.dart';
import '../models/user_model.dart';
import 'auth_api_service.dart';
import '../../profile/services/profile_api_service.dart';

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

/// Authentication service managing user registration, login, and session persistence.
/// Integrates with FastAPI backend while maintaining local SharedPreferences fallback.
class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._({
    AuthApiService? authApiService,
    ProfileApiService? profileApiService,
  })  : _authApiService = authApiService ?? AuthApiService(),
        _profileApiService = profileApiService ?? ProfileApiService();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static const String _keyIsLoggedIn = 'goalsync_is_logged_in';
  static const String _keyCurrentUserId = 'goalsync_current_user_id';
  static const String _keyUsersList = 'goalsync_registered_users';
  static const String _keyAuthToken = 'goalsync_auth_token';

  final AuthApiService _authApiService;
  final ProfileApiService _profileApiService;

  SharedPreferences? _prefs;
  UserModel? _currentUser;
  String? _authToken;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _prefs?.getBool(_keyIsLoggedIn) ?? false;
  UserModel? get currentUser => _currentUser;
  String? get authToken => _authToken;

  /// Initialize local storage, restore session and active JWT token if any.
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    _prefs = await SharedPreferences.getInstance();

    final isLogged = _prefs?.getBool(_keyIsLoggedIn) ?? false;
    final currentUserId = _prefs?.getString(_keyCurrentUserId);
    final savedToken = _prefs?.getString(_keyAuthToken);

    if (savedToken != null && savedToken.isNotEmpty) {
      _authToken = savedToken;
      ApiClient.instance.setAuthToken(savedToken);
    }

    if (isLogged && currentUserId != null) {
      _currentUser = _getUserById(currentUserId);
      if (_currentUser == null && savedToken != null) {
        try {
          final me = await _profileApiService.getMe();
          _currentUser = me;
          _saveOrUpdateUser(me);
        } catch (_) {}
      }
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

  void _saveOrUpdateUser(UserModel user) {
    final users = _getAllUsers();
    final idx = users.indexWhere((u) => u.id == user.id || u.email.toLowerCase() == user.email.toLowerCase());
    if (idx != -1) {
      users[idx] = user;
    } else {
      users.add(user);
    }
    _saveAllUsers(users);
  }

  /// Register a new user with FastAPI backend, falling back locally if offline.
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

    // 1. Attempt backend registration
    try {
      final apiResponse = await _authApiService.register(
        fullName: trimmedName,
        phone: trimmedPhone,
        countryCode: countryCode,
        email: trimmedEmail,
        password: password,
      );

      final backendUser = apiResponse.user;
      _authToken = apiResponse.accessToken;
      ApiClient.instance.setAuthToken(_authToken);
      await _prefs?.setString(_keyAuthToken, _authToken!);

      final userToStore = UserModel(
        id: backendUser.id,
        fullName: backendUser.fullName,
        phone: backendUser.phone,
        countryCode: countryCode,
        email: backendUser.email,
        passwordHash: _hashPassword(password),
        createdAt: backendUser.createdAt,
      );

      _saveOrUpdateUser(userToStore);
      await _setSession(userToStore);
      _currentUser = userToStore;
      notifyListeners();

      return AuthResult.success(userToStore);
    } on ApiException catch (e) {
      // If validation error from backend (e.g. duplicate email/phone or format), return failure directly
      if (e.isValidationError || e.isUnauthorized) {
        return AuthResult.failure(e.message);
      }
      // If network error, fall back to local register
      return _localRegister(
        trimmedName: trimmedName,
        trimmedPhone: trimmedPhone,
        countryCode: countryCode,
        trimmedEmail: trimmedEmail,
        password: password,
      );
    } catch (_) {
      // Other network / offline error -> fallback to local
      return _localRegister(
        trimmedName: trimmedName,
        trimmedPhone: trimmedPhone,
        countryCode: countryCode,
        trimmedEmail: trimmedEmail,
        password: password,
      );
    }
  }

  /// Fallback local registration logic.
  Future<AuthResult> _localRegister({
    required String trimmedName,
    required String trimmedPhone,
    required String countryCode,
    required String trimmedEmail,
    required String password,
  }) async {
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

    await _setSession(newUser);
    _currentUser = newUser;
    notifyListeners();

    return AuthResult.success(newUser);
  }

  /// Authenticate with email or phone + password against backend or local fallback.
  Future<AuthResult> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final input = emailOrPhone.trim();
    if (input.isEmpty) {
      return const AuthResult.failure('Email or phone number is required.');
    }
    if (password.isEmpty) {
      return const AuthResult.failure('Password is required.');
    }

    // 1. Attempt FastAPI backend login
    try {
      final apiResponse = await _authApiService.login(
        identifier: input,
        password: password,
      );

      final backendUser = apiResponse.user;
      _authToken = apiResponse.accessToken;
      ApiClient.instance.setAuthToken(_authToken);
      await _prefs?.setString(_keyAuthToken, _authToken!);

      final userToStore = UserModel(
        id: backendUser.id,
        fullName: backendUser.fullName,
        phone: backendUser.phone,
        countryCode: '+91',
        email: backendUser.email,
        passwordHash: _hashPassword(password),
        createdAt: backendUser.createdAt,
      );

      _saveOrUpdateUser(userToStore);
      await _setSession(userToStore);
      _currentUser = userToStore;
      notifyListeners();

      return AuthResult.success(userToStore);
    } on ApiException catch (e) {
      if (e.isValidationError || e.isUnauthorized) {
        return AuthResult.failure(e.message);
      }
      return _localLogin(input: input, password: password);
    } catch (_) {
      return _localLogin(input: input, password: password);
    }
  }

  /// Fallback local login logic.
  Future<AuthResult> _localLogin({
    required String input,
    required String password,
  }) async {
    final passwordHash = _hashPassword(password);
    final users = _getAllUsers();

    UserModel? matchedUser;

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

  /// Retrieve the authenticated user's backend profile via GET /users/me.
  Future<UserModel?> syncUserFromBackend() async {
    if (_authToken == null || _authToken!.isEmpty) return _currentUser;
    try {
      final user = await _profileApiService.getMe();
      final updated = UserModel(
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        countryCode: _currentUser?.countryCode ?? '+91',
        email: user.email,
        passwordHash: _currentUser?.passwordHash ?? '',
        createdAt: user.createdAt,
      );
      _currentUser = updated;
      _saveOrUpdateUser(updated);
      notifyListeners();
      return _currentUser;
    } catch (_) {
      return _currentUser;
    }
  }

  /// Log out current user, clear active JWT token and session state.
  Future<void> logout() async {
    await _clearSession();
    _authToken = null;
    ApiClient.instance.clearAuthToken();
    await _prefs?.remove(_keyAuthToken);
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
