import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';

/// Central HTTP Client for GoalSync interacting with FastAPI backend.
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  ApiClient._({http.Client? client}) : _httpClient = client ?? http.Client();

  final http.Client _httpClient;
  String? _authToken;

  /// Custom client constructor for testing or dependency injection.
  factory ApiClient.withClient(http.Client client) {
    final c = ApiClient._(client: client);
    _instance = c;
    return c;
  }

  /// Reset singleton instance (useful for unit tests).
  static void resetForTesting() {
    _instance = null;
  }

  /// Get currently active JWT auth token.
  String? get authToken => _authToken;

  /// Update JWT token in memory for all subsequent requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Clear active JWT token.
  void clearAuthToken() {
    _authToken = null;
  }

  /// Build URI for endpoint with base URL and optional query parameters.
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final base = ApiConfig.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$base$normalizedPath';
    final uri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  /// Construct HTTP headers with JSON content-type and Bearer token if available.
  Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    bool requiresAuth = true,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && _authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Perform a GET request.
  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _send(
      () => _httpClient.get(
        _buildUri(path, queryParameters),
        headers: _buildHeaders(
          customHeaders: headers,
          requiresAuth: requiresAuth,
        ),
      ),
    );
  }

  /// Perform a POST request.
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _send(
      () => _httpClient.post(
        _buildUri(path),
        headers: _buildHeaders(
          customHeaders: headers,
          requiresAuth: requiresAuth,
        ),
        body: encodedBody,
      ),
    );
  }

  /// Perform a PUT request.
  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _send(
      () => _httpClient.put(
        _buildUri(path),
        headers: _buildHeaders(
          customHeaders: headers,
          requiresAuth: requiresAuth,
        ),
        body: encodedBody,
      ),
    );
  }

  /// Perform a DELETE request.
  Future<dynamic> delete(
    String path, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    return _send(
      () => _httpClient.delete(
        _buildUri(path),
        headers: _buildHeaders(
          customHeaders: headers,
          requiresAuth: requiresAuth,
        ),
      ),
    );
  }

  /// Internal request execution wrapper with timeout and network exception translation.
  Future<dynamic> _send(Future<http.Response> Function() requestFn) async {
    http.Response response;
    try {
      response = await requestFn().timeout(ApiConfig.defaultTimeout);
    } on TimeoutException {
      throw ApiException.networkError('Connection timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError(
        'Unable to connect to GoalSync server. Please check your internet connection.',
      );
    }

    return _processResponse(response);
  }

  /// Inspect response status code and decode JSON body.
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    // 204 No Content
    if (statusCode == 204 || response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return null;
      }
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    throw ApiException.fromResponse(statusCode, decoded);
  }
}
