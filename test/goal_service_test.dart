import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoalService.resetForTesting();
    await GoalService.instance.init();
  });

  // ── GoalModel Unit Tests ─────────────────────────────────────
  group('GoalModel', () {
    final now = DateTime.now();
    final future = now.add(const Duration(days: 365));

    GoalModel makeGoal({
      double target = 100000,
      double current = 0,
      DateTime? targetDate,
    }) {
      return GoalModel(
        id: 'test_goal',
        userId: 'user_1',
        name: 'Test Goal',
        category: GoalCategory.personal,
        targetAmount: target,
        currentAmount: current,
        targetDate: targetDate ?? future,
        priority: GoalPriority.important,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('progressFraction is 0 when current is 0', () {
      final g = makeGoal();
      expect(g.progressFraction, 0.0);
    });

    test('progressFraction is 1 when fully funded', () {
      final g = makeGoal(current: 100000);
      expect(g.progressFraction, 1.0);
    });

    test('progressFraction clamps at 1.0 when over-funded', () {
      final g = makeGoal(current: 200000);
      expect(g.progressFraction, 1.0);
    });

    test('progressFraction calculates correctly at 50%', () {
      final g = makeGoal(current: 50000);
      expect(g.progressFraction, closeTo(0.5, 0.001));
    });

    test('isCompleted when current >= target', () {
      expect(makeGoal(current: 100000).isCompleted, isTrue);
      expect(makeGoal(current: 99999).isCompleted, isFalse);
    });

    test('remainingAmount is correct', () {
      final g = makeGoal(current: 30000);
      expect(g.remainingAmount, closeTo(70000, 0.01));
    });

    test('remainingAmount is 0 when completed', () {
      final g = makeGoal(current: 150000);
      expect(g.remainingAmount, 0.0);
    });

    test('statusLabel is Completed when done', () {
      expect(makeGoal(current: 100000).statusLabel, 'Completed');
    });

    test('statusLabel is Overdue when date has passed', () {
      final past = now.subtract(const Duration(days: 1));
      expect(makeGoal(targetDate: past).statusLabel, 'Overdue');
    });

    test('statusLabel is Due Soon within 30 days', () {
      final soon = now.add(const Duration(days: 15));
      expect(makeGoal(targetDate: soon).statusLabel, 'Due Soon');
    });

    test('statusLabel is On Track when far in future', () {
      expect(makeGoal().statusLabel, 'On Track');
    });

    test('serialization roundtrip preserves all fields', () {
      final g = makeGoal(current: 45000);
      final json = g.toJson();
      final restored = GoalModel.fromJson(json);
      expect(restored.id, g.id);
      expect(restored.name, g.name);
      expect(restored.targetAmount, g.targetAmount);
      expect(restored.currentAmount, g.currentAmount);
      expect(restored.category, g.category);
      expect(restored.priority, g.priority);
    });

    test('copyWith creates new instance with updated fields', () {
      final g = makeGoal();
      final updated = g.copyWith(name: 'Updated', currentAmount: 25000);
      expect(updated.name, 'Updated');
      expect(updated.currentAmount, 25000);
      expect(updated.id, g.id);
    });
  });

  // ── GoalValidation Tests ─────────────────────────────────────
  group('GoalValidation', () {
    final futureDate = DateTime.now().add(const Duration(days: 365));
    final pastDate = DateTime.now().subtract(const Duration(days: 1));

    test('valid inputs pass validation', () {
      final result = validateGoalInputs(
        name: 'Europe Trip',
        targetAmountRaw: '150000',
        currentAmountRaw: '10000',
        targetDate: futureDate,
      );
      expect(result.isValid, isTrue);
    });

    test('empty name fails validation', () {
      final result = validateGoalInputs(
        name: '',
        targetAmountRaw: '150000',
        currentAmountRaw: '0',
        targetDate: futureDate,
      );
      expect(result.nameError, isNotNull);
    });

    test('zero target amount fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '0',
        currentAmountRaw: '0',
        targetDate: futureDate,
      );
      expect(result.targetAmountError, isNotNull);
    });

    test('negative target amount fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '-500',
        currentAmountRaw: '0',
        targetDate: futureDate,
      );
      expect(result.targetAmountError, isNotNull);
    });

    test('negative current amount fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '100000',
        currentAmountRaw: '-1',
        targetDate: futureDate,
      );
      expect(result.currentAmountError, isNotNull);
    });

    test('current amount exceeding target fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '50000',
        currentAmountRaw: '60000',
        targetDate: futureDate,
      );
      expect(result.currentAmountError, isNotNull);
    });

    test('past target date fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '100000',
        currentAmountRaw: '0',
        targetDate: pastDate,
      );
      expect(result.targetDateError, isNotNull);
    });

    test('null target date fails validation', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: '100000',
        currentAmountRaw: '0',
        targetDate: null,
      );
      expect(result.targetDateError, isNotNull);
    });

    test('non-numeric target amount fails', () {
      final result = validateGoalInputs(
        name: 'Goal',
        targetAmountRaw: 'abc',
        currentAmountRaw: '0',
        targetDate: futureDate,
      );
      expect(result.targetAmountError, isNotNull);
    });
  });

  // ── GoalService CRUD Tests ───────────────────────────────────
  group('GoalService', () {
    const userId = 'user_test_123';
    final futureDate = DateTime.now().add(const Duration(days: 365));

    Future<GoalResult> createGoalHelper({
      String name = 'Test Goal',
      String target = '100000',
      String current = '0',
    }) =>
        GoalService.instance.createGoal(
          userId: userId,
          name: name,
          category: GoalCategory.personal,
          targetAmountRaw: target,
          currentAmountRaw: current,
          targetDate: futureDate,
          priority: GoalPriority.important,
        );

    test('creates a goal successfully', () async {
      final result = await createGoalHelper(name: 'Europe Trip');
      expect(result.isSuccess, isTrue);
      expect(result.goal?.name, 'Europe Trip');
      expect(result.goal?.userId, userId);
    });

    test('goal is persisted and retrievable', () async {
      await createGoalHelper(name: 'Saved Goal');
      final goals = GoalService.instance.getGoalsForUser(userId);
      expect(goals.length, 1);
      expect(goals.first.name, 'Saved Goal');
    });

    test('empty state when user has no goals', () {
      final goals = GoalService.instance.getGoalsForUser(userId);
      expect(goals, isEmpty);
    });

    test('goals are user-specific', () async {
      await createGoalHelper(name: 'User 1 Goal');
      final goalsUser1 = GoalService.instance.getGoalsForUser(userId);
      final goalsUser2 = GoalService.instance.getGoalsForUser('other_user');
      expect(goalsUser1.length, 1);
      expect(goalsUser2, isEmpty);
    });

    test('multiple goals can be created', () async {
      await createGoalHelper(name: 'Goal 1');
      await createGoalHelper(name: 'Goal 2');
      await createGoalHelper(name: 'Goal 3');
      final goals = GoalService.instance.getGoalsForUser(userId);
      expect(goals.length, 3);
    });

    test('fails to create goal with invalid data', () async {
      final result = await GoalService.instance.createGoal(
        userId: userId,
        name: '',
        category: GoalCategory.personal,
        targetAmountRaw: '0',
        currentAmountRaw: '0',
        targetDate: null,
        priority: GoalPriority.flexible,
      );
      expect(result.isSuccess, isFalse);
    });

    test('deletes a goal successfully', () async {
      final created = await createGoalHelper(name: 'To Delete');
      final goalId = created.goal!.id;
      final deleted =
          await GoalService.instance.deleteGoal(userId: userId, goalId: goalId);
      expect(deleted, isTrue);
      final goals = GoalService.instance.getGoalsForUser(userId);
      expect(goals, isEmpty);
    });

    test('delete returns false for non-existent goal', () async {
      final deleted = await GoalService.instance.deleteGoal(
          userId: userId, goalId: 'nonexistent_id');
      expect(deleted, isFalse);
    });

    test('updates a goal successfully', () async {
      final created = await createGoalHelper(name: 'Original Name');
      final goalId = created.goal!.id;

      final updated = await GoalService.instance.updateGoal(
        userId: userId,
        goalId: goalId,
        name: 'Updated Name',
        category: GoalCategory.travel,
        targetAmountRaw: '200000',
        currentAmountRaw: '50000',
        targetDate: futureDate,
        priority: GoalPriority.essential,
      );

      expect(updated.isSuccess, isTrue);
      expect(updated.goal?.name, 'Updated Name');
      expect(updated.goal?.category, GoalCategory.travel);
      expect(updated.goal?.targetAmount, 200000);
      expect(updated.goal?.currentAmount, 50000);
      expect(updated.goal?.priority, GoalPriority.essential);
    });

    test('goals persist across service re-initialization', () async {
      await createGoalHelper(name: 'Persistent Goal');

      // Simulate app restart by reinitializing service
      GoalService.resetForTesting();
      await GoalService.instance.init();

      final goals = GoalService.instance.getGoalsForUser(userId);
      expect(goals.length, 1);
      expect(goals.first.name, 'Persistent Goal');
    });
  });
}
