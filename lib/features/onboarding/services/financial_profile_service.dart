import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_profile_model.dart';

/// Local service managing storage and retrieval of financial profiles and onboarding state.
class FinancialProfileService extends ChangeNotifier {
  static FinancialProfileService? _instance;
  static FinancialProfileService get instance =>
      _instance ??= FinancialProfileService._();

  FinancialProfileService._();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static const String _keyProfilePrefix = 'goalsync_financial_profile_';
  static const String _keyCompletedPrefix = 'goalsync_onboarding_completed_';

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

  /// Retrieve the saved financial profile for a user.
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

  /// Persist a completed financial profile locally and mark onboarding complete.
  Future<bool> saveProfile(FinancialProfile profile) async {
    if (_prefs == null) {
      await init();
    }
    final success = await _prefs?.setString(
          '$_keyProfilePrefix${profile.userId}',
          profile.toJson(),
        ) ??
        false;

    await _prefs?.setBool('$_keyCompletedPrefix${profile.userId}', true);
    notifyListeners();
    return success;
  }

  /// Clear profile (for logout, reset, or testing).
  Future<void> clearProfile(String userId) async {
    if (userId.isEmpty) return;
    await _prefs?.remove('$_keyProfilePrefix$userId');
    await _prefs?.remove('$_keyCompletedPrefix$userId');
    notifyListeners();
  }
}
