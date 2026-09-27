import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/api/api.dart';
import 'package:goalsync/features/auth/services/auth_api_service.dart';
import 'package:goalsync/features/profile/services/profile_api_service.dart';
import 'package:goalsync/features/onboarding/models/financial_profile_model.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_api_service.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';
import 'package:goalsync/features/transactions/services/transaction_api_service.dart';

void main() {
  setUp(() {
    ApiConfig.baseUrl = 'http://127.0.0.1:8000';
    ApiClient.instance.clearAuthToken();
  });

  group('Live FastAPI + MongoDB Atlas E2E Integration', () {
    final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
    final emailA = 'flutter_e2e_$randomSuffix@test.com';
    final phoneA = '+919876$randomSuffix';
    final passwordA = 'SecurePass123!';

    String? tokenA;
    String? userIdA;

    test('1. Verify Sign Up (POST /auth/register)', () async {
      final authApi = AuthApiService();
      final res = await authApi.register(
        fullName: 'Flutter Test User',
        phone: phoneA,
        countryCode: '+91',
        email: emailA,
        password: passwordA,
      );

      expect(res.accessToken, isNotEmpty);
      expect(res.user.email, emailA);
      expect(res.user.id, isNotEmpty);

      tokenA = res.accessToken;
      userIdA = res.user.id;
    });

    test('2. Verify Login (POST /auth/login)', () async {
      final authApi = AuthApiService();
      final res = await authApi.login(
        identifier: emailA,
        password: passwordA,
      );

      expect(res.accessToken, isNotEmpty);
      expect(res.user.email, emailA);
      tokenA = res.accessToken;
      ApiClient.instance.setAuthToken(tokenA);
    });

    test('3. Verify GET /users/me', () async {
      ApiClient.instance.setAuthToken(tokenA);
      final profileApi = ProfileApiService();
      final me = await profileApi.getMe();

      expect(me.id, userIdA);
      expect(me.email, emailA);
      expect(me.fullName, 'Flutter Test User');
    });

    test('4. Verify Financial Profile (POST, GET, PUT /financial-profile)', () async {
      ApiClient.instance.setAuthToken(tokenA);
      final profileApi = ProfileApiService();

      final newProfile = FinancialProfile(
        userId: userIdA!,
        age: 29,
        occupation: 'Software Developer',
        dependents: 1,
        monthlyIncome: 95000.0,
        incomeType: 'Salary',
        additionalIncome: 5000.0,
        currentSavings: 200000.0,
        monthlyFixedExpenses: 30000.0,
        monthlyVariableExpenses: 15000.0,
        existingLoanEmi: 10000.0,
        activeLoansCount: 1,
        completedAt: DateTime.now(),
      );

      // POST /financial-profile
      final created = await profileApi.saveFinancialProfile(newProfile);
      expect(created.userId, userIdA);
      expect(created.occupation, 'Software Developer');
      expect(created.monthlyIncome, 95000.0);

      // GET /financial-profile
      final fetched = await profileApi.getFinancialProfile();
      expect(fetched, isNotNull);
      expect(fetched!.monthlyIncome, 95000.0);
      expect(fetched.monthlyFixedExpenses, 30000.0);

      // PUT /financial-profile
      final updatedProfile = FinancialProfile(
        userId: userIdA!,
        age: 30,
        occupation: 'Senior Software Developer',
        dependents: 1,
        monthlyIncome: 110000.0,
        incomeType: 'Salary',
        additionalIncome: 8000.0,
        currentSavings: 250000.0,
        monthlyFixedExpenses: 32000.0,
        monthlyVariableExpenses: 16000.0,
        existingLoanEmi: 10000.0,
        activeLoansCount: 1,
        completedAt: DateTime.now(),
      );
      final updated = await profileApi.updateFinancialProfile(updatedProfile);
      expect(updated.age, 30);
      expect(updated.monthlyIncome, 110000.0);
      expect(updated.occupation, 'Senior Software Developer');
    });

    test('5. Verify Goal CRUD (POST, GET, PUT, DELETE /goals)', () async {
      ApiClient.instance.setAuthToken(tokenA);
      final goalApi = GoalApiService();

      // POST /goals
      final targetDate = DateTime.now().add(const Duration(days: 365));
      final goal = await goalApi.createGoal(
        name: 'Europe Vacation',
        category: GoalCategory.travel,
        targetAmount: 200000.0,
        currentAmount: 40000.0,
        targetDate: targetDate,
        priority: GoalPriority.important,
      );

      expect(goal.id, isNotEmpty);
      expect(goal.name, 'Europe Vacation');
      expect(goal.userId, userIdA);

      final goalId = goal.id;

      // GET /goals
      final goalsList = await goalApi.getGoals();
      expect(goalsList.any((g) => g.id == goalId), isTrue);

      // GET /goals/{id}
      final singleGoal = await goalApi.getGoalById(goalId);
      expect(singleGoal.name, 'Europe Vacation');

      // PUT /goals/{id}
      final updatedGoal = await goalApi.updateGoal(
        goalId: goalId,
        currentAmount: 55000.0,
        name: 'Japan Vacation',
      );
      expect(updatedGoal.currentAmount, 55000.0);
      expect(updatedGoal.name, 'Japan Vacation');

      // DELETE /goals/{id}
      await goalApi.deleteGoal(goalId);

      // Verify deletion (should throw 404)
      expect(() => goalApi.getGoalById(goalId), throwsA(isA<ApiException>()));
    });

    test('6. Verify Transaction CRUD (POST, GET, PUT, DELETE /transactions)', () async {
      ApiClient.instance.setAuthToken(tokenA);
      final txApi = TransactionApiService();

      // POST /transactions
      final tx = await txApi.createTransaction(
        amount: 3500.0,
        type: TransactionType.debit,
        merchantName: 'Supermarket Store',
        category: 'Groceries',
        dateTime: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
        notes: 'Monthly bulk groceries',
      );

      expect(tx.id, isNotEmpty);
      expect(tx.userId, userIdA);
      expect(tx.merchantName, 'Supermarket Store');
      expect(tx.amount, 3500.0);

      final txId = tx.id;

      // GET /transactions
      final txList = await txApi.getTransactions();
      expect(txList.any((t) => t.id == txId), isTrue);

      // GET /transactions/{id}
      final singleTx = await txApi.getTransactionById(txId);
      expect(singleTx.merchantName, 'Supermarket Store');

      // PUT /transactions/{id}
      final updatedTx = await txApi.updateTransaction(
        transactionId: txId,
        amount: 3800.0,
        notes: 'Updated groceries receipt',
      );
      expect(updatedTx.amount, 3800.0);
      expect(updatedTx.notes, 'Updated groceries receipt');

      // DELETE /transactions/{id}
      await txApi.deleteTransaction(txId);

      // Verify deletion (should throw 404)
      expect(() => txApi.getTransactionById(txId), throwsA(isA<ApiException>()));
    });
  });
}
