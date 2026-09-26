import 'dart:convert';

/// Represents a financial goal category.
enum GoalCategory {
  education,
  travel,
  vehicle,
  home,
  emergencyFund,
  investment,
  personal,
  other;

  String get displayName {
    switch (this) {
      case GoalCategory.education:
        return 'Education';
      case GoalCategory.travel:
        return 'Travel';
      case GoalCategory.vehicle:
        return 'Vehicle';
      case GoalCategory.home:
        return 'Home';
      case GoalCategory.emergencyFund:
        return 'Emergency Fund';
      case GoalCategory.investment:
        return 'Investment';
      case GoalCategory.personal:
        return 'Personal';
      case GoalCategory.other:
        return 'Other';
    }
  }
}

/// Represents a goal priority level.
enum GoalPriority {
  essential,
  important,
  flexible;

  String get displayName {
    switch (this) {
      case GoalPriority.essential:
        return 'Essential';
      case GoalPriority.important:
        return 'Important';
      case GoalPriority.flexible:
        return 'Flexible';
    }
  }
}

/// Represents a user financial goal in GoalSync.
class GoalModel {
  final String id;
  final String userId;
  final String name;
  final GoalCategory category;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final GoalPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress fraction between 0.0 and 1.0.
  double get progressFraction =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Progress percentage string.
  String get progressPercentage =>
      '${(progressFraction * 100).toStringAsFixed(0)}%';

  /// Amount remaining to reach the target.
  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  /// Whether the goal has been fully funded.
  bool get isCompleted => currentAmount >= targetAmount;

  /// Days remaining until target date (from today, ignoring time).
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  /// Human-readable goal status.
  String get statusLabel {
    if (isCompleted) return 'Completed';
    if (daysRemaining < 0) return 'Overdue';
    if (daysRemaining == 0) return 'Due Today';
    if (daysRemaining <= 30) return 'Due Soon';
    return 'On Track';
  }

  GoalModel copyWith({
    String? id,
    String? userId,
    String? name,
    GoalCategory? category,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    GoalPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'category': category.name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: GoalCategory.values.firstWhere(
        (e) => e.name == (map['category'] as String? ?? ''),
        orElse: () => GoalCategory.other,
      ),
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      priority: GoalPriority.values.firstWhere(
        (e) => e.name == (map['priority'] as String? ?? ''),
        orElse: () => GoalPriority.flexible,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GoalModel.fromJson(String source) =>
      GoalModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
