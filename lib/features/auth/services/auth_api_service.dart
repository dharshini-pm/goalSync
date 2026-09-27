import '../../../core/api/api_client.dart';
import '../models/user_model.dart';

/// Response payload from auth endpoints.
class AuthApiResponse {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  const AuthApiResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });
}

/// Service handling authentication endpoints against the FastAPI backend.
class AuthApiService {
  final ApiClient _client;

  AuthApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Register a new user on the backend.
  /// POST /auth/register
  Future<AuthApiResponse> register({
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
    required String password,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
    final cleanCode = countryCode.replaceAll(RegExp(r'[^\d+]'), '').trim();
    final fullPhone = cleanCode.isNotEmpty && !cleanPhone.startsWith('+')
        ? '$cleanCode$cleanPhone'
        : (cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone');

    final response = await _client.post(
      '/auth/register',
      requiresAuth: false,
      body: {
        'fullName': fullName.trim(),
        'phone': fullPhone,
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = response as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final userMap = data['user'] as Map<String, dynamic>;

    final user = UserModel(
      id: (userMap['_id'] ?? userMap['id'] ?? '').toString(),
      fullName: (userMap['fullName'] ?? fullName.trim()).toString(),
      phone: (userMap['phone'] ?? cleanPhone).toString(),
      countryCode: countryCode,
      email: (userMap['email'] ?? email.trim().toLowerCase()).toString(),
      passwordHash: '',
      createdAt: userMap['createdAt'] != null
          ? DateTime.tryParse(userMap['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );

    _client.setAuthToken(token);

    return AuthApiResponse(
      accessToken: token,
      tokenType: (data['token_type'] ?? 'bearer').toString(),
      user: user,
    );
  }

  /// Log in an existing user with identifier (email or phone) and password.
  /// POST /auth/login
  Future<AuthApiResponse> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      requiresAuth: false,
      body: {
        'identifier': identifier.trim(),
        'password': password,
      },
    );

    final data = response as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final userMap = data['user'] as Map<String, dynamic>;

    final user = UserModel(
      id: (userMap['_id'] ?? userMap['id'] ?? '').toString(),
      fullName: (userMap['fullName'] ?? '').toString(),
      phone: (userMap['phone'] ?? '').toString(),
      countryCode: '+91',
      email: (userMap['email'] ?? '').toString(),
      passwordHash: '',
      createdAt: userMap['createdAt'] != null
          ? DateTime.tryParse(userMap['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );

    _client.setAuthToken(token);

    return AuthApiResponse(
      accessToken: token,
      tokenType: (data['token_type'] ?? 'bearer').toString(),
      user: user,
    );
  }
}
