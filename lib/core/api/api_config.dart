import 'package:flutter/foundation.dart';

/// Configuration for backend API connectivity in GoalSync.
class ApiConfig {
  static const String _defaultAndroidEmulatorUrl = 'http://10.0.2.2:8000';
  static const String _defaultLocalhostUrl = 'http://127.0.0.1:8000';

  static String? _customBaseUrl;

  /// Default HTTP timeout duration.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Determine the default base URL based on the runtime target platform.
  /// - Android Emulator: http://10.0.2.2:8000
  /// - Web / Desktop / Local: http://127.0.0.1:8000
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return _defaultLocalhostUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _defaultAndroidEmulatorUrl;
    }
    return _defaultLocalhostUrl;
  }

  /// Active base URL. Can be dynamically overridden via [baseUrl].
  static String get baseUrl => _customBaseUrl ?? defaultBaseUrl;

  /// Set a custom base URL (e.g. for testing, staging, or production).
  static set baseUrl(String? url) {
    if (url != null && url.endsWith('/')) {
      _customBaseUrl = url.substring(0, url.length - 1);
    } else {
      _customBaseUrl = url;
    }
  }

  /// Reset to default base URL.
  static void reset() {
    _customBaseUrl = null;
  }
}
