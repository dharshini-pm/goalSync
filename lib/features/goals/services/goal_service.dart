import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api.dart';
import '../models/goal_model.dart';
import 'goal_api_service.dart';

/// Result object for goal operations.
class GoalResult {
  final bool isSuccess;
  final String? errorMessage;
  final GoalModel? goal;

  const GoalResult.success([this.goal])
      : isSuccess = true,
        errorMessage = null;

  const GoalResult.failure(this.errorMessage)
      : isSuccess = false,
        goal = null;
}

/// Validation result for goal form fields.
class GoalValidationResult {
  final String? nameError;
  final String? targetAmountError;
  final String? currentAmountError;
  final String? targetDateError;

  const GoalValidationResult({
    this.nameError,
    this.targetAmountError,
    this.currentAmountError,
    this.targetDateError,
  });

  bool get isValid =>
      nameError == null &&
      targetAmountError == null &&
      currentAmountError == null &&
      targetDateError == null;
}

/// Validates goal form inputs without side effects.
GoalValidationResult validateGoalInputs({
  required String name,
  required String targetAmountRaw,
  required String currentAmountRaw,
  required DateTime? targetDate,
}) {
  String? nameError;
  String? targetAmountError;
  String? currentAmountError;
  String? targetDateError;

  if (name.trim().isEmpty) {
    nameError = 'Goal name is required.';
  }

  final targetAmount = double.tryParse(targetAmountRaw.trim());
  if (targetAmount == null) {
    targetAmountError = 'Enter a valid target amount.';
  } else if (targetAmount <= 0) {
    targetAmountError = 'Target amount must be greater than 0.';
  }

  final currentAmount = double.tryParse(currentAmountRaw.trim());
  if (currentAmount == null) {
    currentAmountError = 'Enter a valid current amount.';
  } else if (currentAmount < 0) {
    currentAmountError = 'Current amount cannot be negative.';
  } else if (targetAmount != null && currentAmount > targetAmount) {
    currentAmountError = 'Current amount cannot exceed target amount.';
  }

  if (targetDate == null) {
    targetDateError = 'Target date is required.';
  } else {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dateMidnight =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (!dateMidnight.isAfter(todayMidnight)) {
      targetDateError = 'Target date must be a future date.';
    }
  }

  return GoalValidationResult(
    nameError: nameError,
    targetAmountError: targetAmountError,
    currentAmountError: currentAmountError,
    targetDateError: targetDateError,
  );
}

/// Persistence service for user financial goals.
/// Integrates with FastAPI backend while maintaining local SharedPreferences fallback.
class GoalService extends ChangeNotifier {
  static GoalService? _instance;
  static GoalService get instance => _instance ??= GoalService._();

  GoalService._({GoalApiService? goalApiService})
      : _goalApiService = goalApiService ?? GoalApiService();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static String _keyForUser(String userId) => 'goalsync_goals_$userId';

  final GoalApiService _goalApiService;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize shared preferences.
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    notifyListeners();
  }

  /// Retrieve all goals for a specific user from local cache.
  List<GoalModel> getGoalsForUser(String userId) {
    final raw = _prefs?.getStringList(_keyForUser(userId)) ?? [];
    return raw
        .map((s) {
          try {
            return GoalModel.fromJson(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<GoalModel>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Fetch goals from backend GET /goals and synchronize local storage.
  Future<List<GoalModel>> fetchGoalsFromBackend(String userId) async {
    if (userId.isEmpty) return [];
    if (ApiClient.instance.authToken == null) {
      return getGoalsForUser(userId);
    }

    try {
      final backendGoals = await _goalApiService.getGoals();
      await _saveGoals(userId, backendGoals);
      notifyListeners();
      return backendGoals;
    } catch (_) {
      return getGoalsForUser(userId);
    }
  }

  /// Save the full goal list for a user.
  Future<void> _saveGoals(String userId, List<GoalModel> goals) async {
    if (_prefs == null) await init();
    final list = goals.map((g) => g.toJson()).toList();
    await _prefs?.setStringList(_keyForUser(userId), list);
  }

  /// Create a new goal for the given user after validation.
  Future<GoalResult> createGoal({
    required String userId,
    required String name,
    required GoalCategory category,
    required String targetAmountRaw,
    required String currentAmountRaw,
    required DateTime? targetDate,
    required GoalPriority priority,
  }) async {
    final validation = validateGoalInputs(
      name: name,
      targetAmountRaw: targetAmountRaw,
      currentAmountRaw: currentAmountRaw,
      targetDate: targetDate,
    );

    if (!validation.isValid) {
      final errors = [
        validation.nameError,
        validation.targetAmountError,
        validation.currentAmountError,
        validation.targetDateError,
      ].whereType<String>().join(' ');
      return GoalResult.failure(errors);
    }

    final targetAmount = double.parse(targetAmountRaw.trim());
    final currentAmount = double.parse(currentAmountRaw.trim());

    GoalModel? goal;

    // 1. If connected to backend, create on backend
    if (ApiClient.instance.authToken != null) {
      try {
        goal = await _goalApiService.createGoal(
          name: name,
          category: category,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          targetDate: targetDate!,
          priority: priority,
        );
      } on ApiException catch (e) {
        if (e.isValidationError || e.isUnauthorized) {
          return GoalResult.failure(e.message);
        }
      } catch (_) {
        // Network fallback
      }
    }

    // 2. Local fallback if offline or no backend token
    if (goal == null) {
      final now = DateTime.now();
      goal = GoalModel(
        id: 'goal_${now.millisecondsSinceEpoch}',
        userId: userId,
        name: name.trim(),
        category: category,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: targetDate!,
        priority: priority,
        createdAt: now,
        updatedAt: now,
      );
    }

    final goals = getGoalsForUser(userId);
    goals.insert(0, goal);
    await _saveGoals(userId, goals);
    notifyListeners();

    return GoalResult.success(goal);
  }

  /// Update an existing goal.
  Future<GoalResult> updateGoal({
    required String userId,
    required String goalId,
    required String name,
    required GoalCategory category,
    required String targetAmountRaw,
    required String currentAmountRaw,
    required DateTime? targetDate,
    required GoalPriority priority,
  }) async {
    final validation = validateGoalInputs(
      name: name,
      targetAmountRaw: targetAmountRaw,
      currentAmountRaw: currentAmountRaw,
      targetDate: targetDate,
    );

    if (!validation.isValid) {
      final errors = [
        validation.nameError,
        validation.targetAmountError,
        validation.currentAmountError,
        validation.targetDateError,
      ].whereType<String>().join(' ');
      return GoalResult.failure(errors);
    }

    final targetAmount = double.parse(targetAmountRaw.trim());
    final currentAmount = double.parse(currentAmountRaw.trim());

    GoalModel? updated;

    if (ApiClient.instance.authToken != null) {
      try {
        updated = await _goalApiService.updateGoal(
          goalId: goalId,
          name: name,
          category: category,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          targetDate: targetDate,
          priority: priority,
        );
      } on ApiException catch (e) {
        if (e.isValidationError || e.isUnauthorized) {
          return GoalResult.failure(e.message);
        }
      } catch (_) {}
    }

    final goals = getGoalsForUser(userId);
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx == -1 && updated == null) {
      return const GoalResult.failure('Goal not found.');
    }

    if (updated == null) {
      final existing = goals[idx];
      updated = existing.copyWith(
        name: name.trim(),
        category: category,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: targetDate,
        priority: priority,
        updatedAt: DateTime.now(),
      );
    }

    if (idx != -1) {
      goals[idx] = updated;
    } else {
      goals.insert(0, updated);
    }
    await _saveGoals(userId, goals);
    notifyListeners();

    return GoalResult.success(updated);
  }

  /// Delete a goal by id.
  Future<bool> deleteGoal({
    required String userId,
    required String goalId,
  }) async {
    if (ApiClient.instance.authToken != null) {
      try {
        await _goalApiService.deleteGoal(goalId);
      } catch (_) {}
    }

    final goals = getGoalsForUser(userId);
    final before = goals.length;
    goals.removeWhere((g) => g.id == goalId);
    if (goals.length == before) return false;
    await _saveGoals(userId, goals);
    notifyListeners();
    return true;
  }
}
