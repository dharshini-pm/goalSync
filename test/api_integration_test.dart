import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goalsync/core/api/api.dart';
import 'package:goalsync/features/auth/services/auth_api_service.dart';
import 'package:goalsync/features/profile/services/profile_api_service.dart';
import 'package:goalsync/features/goals/models/goal_model.dart';
import 'package:goalsync/features/goals/services/goal_api_service.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';
import 'package:goalsync/features/transactions/services/transaction_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetForTesting();
    ApiConfig.reset();
  });

  group('ApiConfig Tests', () {
    test('Default base URL is configured and can be overridden', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
      ApiConfig.baseUrl = 'http://test-server:8000/';
      expect(ApiConfig.baseUrl, 'http://test-server:8000');
      ApiConfig.reset();
      expect(ApiConfig.baseUrl, isNotEmpty);
    });
  });

  group('ApiException Tests', () {
    test('Constructs friendly error message for 401 Unauthorized', () {
      final exc = ApiException.fromResponse(401, {'detail': 'Invalid credentials.'});
      expect(exc.isUnauthorized, isTrue);
      expect(exc.message, 'Invalid credentials.');
    });

    test('Constructs friendly error message for 422 Validation Error', () {
      final exc = ApiException.fromResponse(422, {
        'detail': [
          {'loc': ['body', 'email'], 'msg': 'value is not a valid email address'},
        ]
      });
      expect(exc.isValidationError, isTrue);
      expect(exc.message, contains('value is not a valid email address'));
    });

    test('Constructs friendly error message for 404 Not Found', () {
      final exc = ApiException.fromResponse(404, {'detail': 'Goal not found.'});
      expect(exc.isNotFound, isTrue);
      expect(exc.message, 'Goal not found.');
    });

    test('Constructs friendly error message for 500 Server Error', () {
      final exc = ApiException.fromResponse(500, {'detail': 'Internal error'});
      expect(exc.isServerError, isTrue);
      expect(exc.message, 'Server encountered an error. Please try again later.');
    });

    test('Constructs friendly error message for Network Error', () {
      final exc = ApiException.networkError();
      expect(exc.isNetworkError, isTrue);
      expect(exc.message, contains('internet connection'));
    });
  });

  group('ApiClient Tests', () {
    test('Automatically attaches Authorization header when token is set', () async {
      String? capturedAuthHeader;

      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('test_jwt_token_123');

      await apiClient.get('/test-endpoint');

      expect(capturedAuthHeader, 'Bearer test_jwt_token_123');
    });

    test('Does not attach Authorization header for unauthenticated endpoints', () async {
      String? capturedAuthHeader;

      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('test_jwt_token_123');

      await apiClient.post('/auth/login', requiresAuth: false);

      expect(capturedAuthHeader, isNull);
    });

    test('Correctly handles 204 No Content', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final apiClient = ApiClient.withClient(mockClient);
      final result = await apiClient.delete('/goals/123');

      expect(result, isNull);
    });
  });

  group('AuthApiService Tests', () {
    test('register sends correct JSON and parses TokenResponse', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'alex@example.com');
        expect(body['phone'], '+919876543210');
        expect(body['fullName'], 'Alex Rivera');

        return http.Response(
          jsonEncode({
            'access_token': 'fake_jwt_token',
            'token_type': 'bearer',
            'user': {
              '_id': 'user_id_999',
              'fullName': 'Alex Rivera',
              'phone': '+919876543210',
              'email': 'alex@example.com',
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient.withClient(mockClient);
      final authApi = AuthApiService(client: apiClient);

      final res = await authApi.register(
        fullName: 'Alex Rivera',
        phone: '9876543210',
        countryCode: '+91',
        email: 'alex@example.com',
        password: 'Password123!',
      );

      expect(res.accessToken, 'fake_jwt_token');
      expect(res.user.id, 'user_id_999');
      expect(res.user.fullName, 'Alex Rivera');
      expect(apiClient.authToken, 'fake_jwt_token');
    });

    test('login sends identifier and parses TokenResponse', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/login');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['identifier'], 'alex@example.com');
        expect(body['password'], 'Secret123!');

        return http.Response(
          jsonEncode({
            'access_token': 'jwt_logged_in_token',
            'token_type': 'bearer',
            'user': {
              '_id': 'user_id_999',
              'fullName': 'Alex Rivera',
              'phone': '+919876543210',
              'email': 'alex@example.com',
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }
          }),
          200,
        );
      });

      final apiClient = ApiClient.withClient(mockClient);
      final authApi = AuthApiService(client: apiClient);

      final res = await authApi.login(
        identifier: 'alex@example.com',
        password: 'Secret123!',
      );

      expect(res.accessToken, 'jwt_logged_in_token');
      expect(res.user.email, 'alex@example.com');
      expect(apiClient.authToken, 'jwt_logged_in_token');
    });
  });

  group('ProfileApiService Tests', () {
    test('getMe retrieves authenticated user profile', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/users/me');
        expect(request.headers['Authorization'], 'Bearer user_token');
        return http.Response(
          jsonEncode({
            '_id': 'user_id_999',
            'fullName': 'Alex Rivera',
            'phone': '+919876543210',
            'email': 'alex@example.com',
            'createdAt': '2026-09-27T10:00:00.000Z',
            'updatedAt': '2026-09-27T10:00:00.000Z',
          }),
          200,
        );
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('user_token');
      final profileApi = ProfileApiService(client: apiClient);

      final user = await profileApi.getMe();
      expect(user.id, 'user_id_999');
      expect(user.fullName, 'Alex Rivera');
    });

    test('Financial Profile CRUD via ProfileApiService', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/financial-profile');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              '_id': 'fp_123',
              'userId': 'user_id_999',
              'age': 28,
              'occupation': 'Software Engineer',
              'dependents': 1,
              'monthlyIncome': 120000.0,
              'incomeType': 'Salary',
              'additionalIncome': 10000.0,
              'currentSavings': 300000.0,
              'fixedExpenses': 40000.0,
              'variableExpenses': 20000.0,
              'monthlyEMI': 15000.0,
              'activeLoans': 1,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            200,
          );
        } else if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['monthlyIncome'], 120000.0);
          expect(body['fixedExpenses'], 40000.0);
          return http.Response(
            jsonEncode({
              '_id': 'fp_123',
              'userId': 'user_id_999',
              ...body,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            201,
          );
        }
        return http.Response('', 400);
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('user_token');
      final profileApi = ProfileApiService(client: apiClient);

      final profile = await profileApi.getFinancialProfile();
      expect(profile, isNotNull);
      expect(profile!.age, 28);
      expect(profile.monthlyIncome, 120000.0);
      expect(profile.monthlyFixedExpenses, 40000.0);
    });
  });

  group('GoalApiService Tests', () {
    test('getGoals, createGoal, updateGoal, deleteGoal', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/goals') {
          return http.Response(
            jsonEncode([
              {
                '_id': 'goal_1',
                'userId': 'user_id_999',
                'name': 'Emergency Fund',
                'category': 'emergencyFund',
                'targetAmount': 100000.0,
                'currentAmount': 25000.0,
                'targetDate': '2027-09-27T00:00:00.000Z',
                'priority': 'essential',
                'createdAt': '2026-09-27T10:00:00.000Z',
                'updatedAt': '2026-09-27T10:00:00.000Z',
              }
            ]),
            200,
          );
        } else if (request.method == 'POST' && request.url.path == '/goals') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              '_id': 'goal_2',
              'userId': 'user_id_999',
              ...body,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            201,
          );
        } else if (request.method == 'PUT' && request.url.path == '/goals/goal_1') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              '_id': 'goal_1',
              'userId': 'user_id_999',
              'name': 'Updated Goal',
              'category': 'emergencyFund',
              'targetAmount': 120000.0,
              'currentAmount': 30000.0,
              'targetDate': '2027-09-27T00:00:00.000Z',
              'priority': 'essential',
              ...body,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            200,
          );
        } else if (request.method == 'DELETE' && request.url.path == '/goals/goal_1') {
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('user_token');
      final goalApi = GoalApiService(client: apiClient);

      // 1. GET /goals
      final goals = await goalApi.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'Emergency Fund');

      // 2. POST /goals
      final created = await goalApi.createGoal(
        name: 'New Car',
        category: GoalCategory.vehicle,
        targetAmount: 500000.0,
        currentAmount: 50000.0,
        targetDate: DateTime(2028, 1, 1),
        priority: GoalPriority.important,
      );
      expect(created.id, 'goal_2');
      expect(created.name, 'New Car');

      // 3. PUT /goals/goal_1
      final updated = await goalApi.updateGoal(
        goalId: 'goal_1',
        name: 'Updated Emergency Fund',
      );
      expect(updated.name, 'Updated Emergency Fund');

      // 4. DELETE /goals/goal_1
      await goalApi.deleteGoal('goal_1');
    });
  });

  group('TransactionApiService Tests', () {
    test('getTransactions, createTransaction, updateTransaction, deleteTransaction', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/transactions') {
          return http.Response(
            jsonEncode([
              {
                '_id': 'tx_1',
                'userId': 'user_id_999',
                'amount': 2500.0,
                'type': 'debit',
                'merchantName': 'Grocery Mart',
                'category': 'Groceries',
                'dateTime': '2026-09-27T10:00:00.000Z',
                'paymentMethod': 'upi',
                'notes': 'Weekly groceries',
                'createdAt': '2026-09-27T10:00:00.000Z',
                'updatedAt': '2026-09-27T10:00:00.000Z',
              }
            ]),
            200,
          );
        } else if (request.method == 'POST' && request.url.path == '/transactions') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              '_id': 'tx_2',
              'userId': 'user_id_999',
              ...body,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            201,
          );
        } else if (request.method == 'PUT' && request.url.path == '/transactions/tx_1') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              '_id': 'tx_1',
              'userId': 'user_id_999',
              'amount': 3000.0,
              'type': 'debit',
              'merchantName': 'Grocery Supermart',
              'category': 'Groceries',
              'dateTime': '2026-09-27T10:00:00.000Z',
              'paymentMethod': 'upi',
              'notes': 'Updated',
              ...body,
              'createdAt': '2026-09-27T10:00:00.000Z',
              'updatedAt': '2026-09-27T10:00:00.000Z',
            }),
            200,
          );
        } else if (request.method == 'DELETE' && request.url.path == '/transactions/tx_1') {
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient.withClient(mockClient);
      apiClient.setAuthToken('user_token');
      final txApi = TransactionApiService(client: apiClient);

      // 1. GET /transactions
      final list = await txApi.getTransactions();
      expect(list.length, 1);
      expect(list.first.merchantName, 'Grocery Mart');
      expect(list.first.amount, 2500.0);

      // 2. POST /transactions
      final created = await txApi.createTransaction(
        amount: 80000.0,
        type: TransactionType.credit,
        merchantName: 'Acme Corp',
        category: 'Salary & Income',
        dateTime: DateTime.now(),
        paymentMethod: PaymentMethod.netBanking,
        notes: 'Monthly salary',
      );
      expect(created.id, 'tx_2');
      expect(created.isCredit, isTrue);

      // 3. PUT /transactions/tx_1
      final updated = await txApi.updateTransaction(
        transactionId: 'tx_1',
        merchantName: 'Grocery Supermart',
      );
      expect(updated.merchantName, 'Grocery Supermart');

      // 4. DELETE /transactions/tx_1
      await txApi.deleteTransaction('tx_1');
    });
  });
}
