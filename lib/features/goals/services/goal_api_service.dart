import '../../../core/api/api_client.dart';
import '../models/goal_model.dart';

/// API Service managing goal CRUD operations against the FastAPI backend.
class GoalApiService {
  final ApiClient _client;

  GoalApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Retrieve all goals for the authenticated user: GET /goals.
  Future<List<GoalModel>> getGoals() async {
    final response = await _client.get('/goals', requiresAuth: true);
    if (response is List) {
      return response
          .map((item) => _mapToGoalModel(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieve single goal by ID: GET /goals/{goal_id}.
  Future<GoalModel> getGoalById(String goalId) async {
    final response = await _client.get('/goals/$goalId', requiresAuth: true);
    return _mapToGoalModel(response as Map<String, dynamic>);
  }

  /// Create a new goal: POST /goals.
  Future<GoalModel> createGoal({
    required String name,
    required GoalCategory category,
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
    required GoalPriority priority,
  }) async {
    final response = await _client.post(
      '/goals',
      requiresAuth: true,
      body: {
        'name': name.trim(),
        'category': category.name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate.toUtc().toIso8601String(),
        'priority': priority.name,
      },
    );
    return _mapToGoalModel(response as Map<String, dynamic>);
  }

  /// Update an existing goal: PUT /goals/{goal_id}.
  Future<GoalModel> updateGoal({
    required String goalId,
    String? name,
    GoalCategory? category,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    GoalPriority? priority,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (category != null) body['category'] = category.name;
    if (targetAmount != null) body['targetAmount'] = targetAmount;
    if (currentAmount != null) body['currentAmount'] = currentAmount;
    if (targetDate != null) {
      body['targetDate'] = targetDate.toUtc().toIso8601String();
    }
    if (priority != null) body['priority'] = priority.name;

    final response = await _client.put(
      '/goals/$goalId',
      requiresAuth: true,
      body: body,
    );
    return _mapToGoalModel(response as Map<String, dynamic>);
  }

  /// Delete a goal: DELETE /goals/{goal_id}.
  Future<void> deleteGoal(String goalId) async {
    await _client.delete('/goals/$goalId', requiresAuth: true);
  }

  GoalModel _mapToGoalModel(Map<String, dynamic> map) {
    final id = (map['_id'] ?? map['id'] ?? '').toString();
    final userId = (map['userId'] ?? '').toString();
    final name = (map['name'] ?? '').toString();
    final categoryStr = (map['category'] ?? '').toString();
    final priorityStr = (map['priority'] ?? '').toString();

    final category = GoalCategory.values.firstWhere(
      (c) =>
          c.name.toLowerCase() == categoryStr.toLowerCase() ||
          c.displayName.toLowerCase() == categoryStr.toLowerCase(),
      orElse: () => GoalCategory.other,
    );

    final priority = GoalPriority.values.firstWhere(
      (p) =>
          p.name.toLowerCase() == priorityStr.toLowerCase() ||
          p.displayName.toLowerCase() == priorityStr.toLowerCase(),
      orElse: () => GoalPriority.flexible,
    );

    return GoalModel(
      id: id,
      userId: userId,
      name: name,
      category: category,
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      priority: priority,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}
