import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clean abstraction for safe device and user identification during SMS ingestion.
///
/// Security constraints:
/// - Never leaks passwords, JWTs, or database credentials into event payloads.
/// - Produces a stable, anonymous device identifier persisted locally.
class DeviceIdentity {
  static const String _prefKeyDeviceId = 'goalsync_device_id';
  static const String _prefKeyUserId = 'goalsync_authenticated_user_id';

  static String? _cachedDeviceId;

  /// Returns the stable local device identifier.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_prefKeyDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a collision-resistant pseudorandom device fingerprint
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      final rawHash = sha256.convert(values).toString();
      deviceId = 'dev_${rawHash.substring(0, 16)}';
      await prefs.setString(_prefKeyDeviceId, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Sets the currently authenticated user identifier.
  static Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUserId, userId);
  }

  /// Retrieves the currently authenticated user identifier, if any.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserId);
  }

  /// Clears stored identity upon logout.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyUserId);
  }
}
