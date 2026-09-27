/// Standard API exception for handling backend errors in GoalSync.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400 || statusCode == 422;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => statusCode == null;

  /// Factory to construct user-friendly [ApiException] from an HTTP response.
  factory ApiException.fromResponse(int statusCode, dynamic responseBody) {
    String message = 'An unexpected error occurred. Please try again.';
    dynamic details;

    if (responseBody is Map<String, dynamic>) {
      final detail = responseBody['detail'];
      details = detail;
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        // FastAPI 422 validation errors: list of error objects with 'msg'
        final messages = <String>[];
        for (final item in detail) {
          if (item is Map && item.containsKey('msg')) {
            messages.add(item['msg'].toString());
          } else {
            messages.add(item.toString());
          }
        }
        message = messages.join('. ');
      } else if (responseBody['message'] is String) {
        message = responseBody['message'] as String;
      }
    } else if (responseBody is String && responseBody.trim().isNotEmpty) {
      // Don't show HTML dumps or raw stack traces
      if (!responseBody.contains('<!DOCTYPE html>') &&
          !responseBody.contains('<html>') &&
          !responseBody.contains('Traceback')) {
        message = responseBody.trim();
      }
    }

    // If no specific message was found in response, use friendly status-code defaults
    if (message == 'An unexpected error occurred. Please try again.' || message.isEmpty) {
      if (statusCode == 401) {
        message = 'Session expired or invalid credentials. Please log in again.';
      } else if (statusCode == 404) {
        message = 'The requested resource was not found.';
      } else if (statusCode >= 500) {
        message = 'Server encountered an error. Please try again later.';
      }
    } else if (statusCode >= 500) {
      // Don't expose internal server errors or tracebacks
      message = 'Server encountered an error. Please try again later.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  /// Factory for network connection errors (offline, timeout, connection refused).
  factory ApiException.networkError([String? customMessage]) {
    return ApiException(
      message: customMessage ??
          'Unable to connect to GoalSync server. Please check your internet connection.',
      statusCode: null,
    );
  }

  @override
  String toString() => message;
}
