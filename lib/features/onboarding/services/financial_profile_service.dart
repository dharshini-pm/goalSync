import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api.dart';
import '../../profile/services/profile_api_service.dart';
import '../models/financial_profile_model.dart';

/// Service managing storage and retrieval of financial profiles and onboarding state.
/// Integrates with FastAPI backend while maintaining local SharedPreferences fallback.
class FinancialProfileService extends ChangeNotifier {
  static FinancialProfileService? _instance;
  static FinancialProfileService get instance =>
      _instance ??= FinancialProfileService._();

  FinancialProfileService._({ProfileApiService? profileApiService})
      : _profileApiService = profileApiService ?? ProfileApiService();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static const String _keyProfilePrefix = 'goalsync_financial_profile_';
  static const String _keyCompletedPrefix = 'goalsync_onboarding_completed_';

  final ProfileApiService _profileApiService;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize local storage handle.
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    notifyListeners();
  }

  /// Check whether the specified user has completed financial onboarding.
  bool isOnboardingCompleted(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return _prefs?.getBool('$_keyCompletedPrefix$userId') ?? false;
  }

  /// Retrieve the saved financial profile for a user locally.
  FinancialProfile? getProfile(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    final jsonStr = _prefs?.getString('$_keyProfilePrefix$userId');
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return FinancialProfile.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  /// Fetch financial profile from backend GET /financial-profile and sync local storage.
  Future<FinancialProfile?> fetchProfileFromBackend(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    if (ApiClient.instance.authToken == null) {
      return getProfile(userId);
    }

    try {
      final backendProfile = await _profileApiService.getFinancialProfile();
      if (backendProfile != null) {
        if (_prefs == null) await init();
        await _prefs?.setString(
          '$_keyProfilePrefix$userId',
          backendProfile.toJson(),
        );
        await _prefs?.setBool('$_keyCompletedPrefix$userId', true);
        notifyListeners();
        return backendProfile;
      }
    } catch (_) {
      // Offline fallback
    }
    return getProfile(userId);
  }

  /// Persist a completed financial profile locally and to the backend.
  Future<bool> saveProfile(FinancialProfile profile) async {
    if (_prefs == null) {
      await init();
    }

    // 1. Save locally first (local-first safety)
    final localSuccess = await _prefs?.setString(
          '$_keyProfilePrefix${profile.userId}',
          profile.toJson(),
        ) ??
        false;

    await _prefs?.setBool('$_keyCompletedPrefix${profile.userId}', true);

    // 2. Synchronize to backend if authenticated
    if (ApiClient.instance.authToken != null) {
      try {
        final backendProfile =
            await _profileApiService.saveFinancialProfile(profile);
        await _prefs?.setString(
          '$_keyProfilePrefix${profile.userId}',
          backendProfile.toJson(),
        );
      } catch (_) {
        // Backend unavailable; local persistence guarantees data safety
      }
    }

    notifyListeners();
    return localSuccess;
  }

  /// Clear profile (for logout, reset, or testing).
  Future<void> clearProfile(String userId) async {
    if (userId.isEmpty) return;
    await _prefs?.remove('$_keyProfilePrefix$userId');
    await _prefs?.remove('$_keyCompletedPrefix$userId');
    notifyListeners();
  }
}
