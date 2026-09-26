import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetForTesting();
    await AuthService.instance.init();
  });

  group('AuthService Tests', () {
    test('Register new user successfully and hashes password', () async {
      final auth = AuthService.instance;
      final result = await auth.register(
        fullName: 'Rahul Sharma',
        phone: '9876543210',
        countryCode: '+91',
        email: 'rahul@example.com',
        password: 'Password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.fullName, 'Rahul Sharma');
      expect(result.user!.email, 'rahul@example.com');
      // Password must NEVER be stored as plain text
      expect(result.user!.passwordHash, isNot(equals('Password123')));
      expect(result.user!.passwordHash.length, 64); // SHA-256 hex length
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.id, result.user!.id);
    });

    test('Prevents duplicate email registration', () async {
      final auth = AuthService.instance;
      await auth.register(
        fullName: 'User One',
        phone: '9876543210',
        countryCode: '+91',
        email: 'user@example.com',
        password: 'Password123',
      );

      final duplicateResult = await auth.register(
        fullName: 'User Two',
        phone: '9123456780',
        countryCode: '+91',
        email: 'user@example.com', // same email
        password: 'Password456',
      );

      expect(duplicateResult.isSuccess, isFalse);
      expect(
        duplicateResult.errorMessage,
        'An account with this email already exists.',
      );
    });

    test('Login with email succeeds with correct credentials', () async {
      final auth = AuthService.instance;
      await auth.register(
        fullName: 'User One',
        phone: '9876543210',
        countryCode: '+91',
        email: 'user@example.com',
        password: 'Password123',
      );

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);

      final loginResult = await auth.login(
        emailOrPhone: 'user@example.com',
        password: 'Password123',
      );

      expect(loginResult.isSuccess, isTrue);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.email, 'user@example.com');
    });

    test('Login with phone succeeds with correct credentials', () async {
      final auth = AuthService.instance;
      await auth.register(
        fullName: 'User One',
        phone: '9876543210',
        countryCode: '+91',
        email: 'user@example.com',
        password: 'Password123',
      );

      await auth.logout();

      final loginResult = await auth.login(
        emailOrPhone: '9876543210',
        password: 'Password123',
      );

      expect(loginResult.isSuccess, isTrue);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.phone, '9876543210');
    });

    test('Login fails with invalid password', () async {
      final auth = AuthService.instance;
      await auth.register(
        fullName: 'User One',
        phone: '9876543210',
        countryCode: '+91',
        email: 'user@example.com',
        password: 'Password123',
      );

      await auth.logout();

      final loginResult = await auth.login(
        emailOrPhone: 'user@example.com',
        password: 'WrongPassword999',
      );

      expect(loginResult.isSuccess, isFalse);
      expect(loginResult.errorMessage, 'Invalid email/phone or password.');
      expect(auth.isLoggedIn, isFalse);
    });

    test('Logout clears session state', () async {
      final auth = AuthService.instance;
      await auth.register(
        fullName: 'User One',
        phone: '9876543210',
        countryCode: '+91',
        email: 'user@example.com',
        password: 'Password123',
      );

      expect(auth.isLoggedIn, isTrue);
      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
    });
  });
}
