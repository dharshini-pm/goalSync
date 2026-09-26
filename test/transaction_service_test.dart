import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/features/auth/services/auth_service.dart';
import 'package:goalsync/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:goalsync/features/goals/services/goal_service.dart';
import 'package:goalsync/features/onboarding/services/financial_profile_service.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';
import 'package:goalsync/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:goalsync/features/transactions/presentation/pages/transactions_page.dart';
import 'package:goalsync/features/transactions/services/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

TransactionModel makeTransaction({
  String id = 'tx_1',
  String userId = 'user_1',
  double amount = 1250.0,
  TransactionType type = TransactionType.debit,
  String merchantName = 'Starbucks Coffee',
  String category = TransactionCategories.foodAndDining,
  DateTime? dateTime,
  PaymentMethod paymentMethod = PaymentMethod.upi,
  String? notes = 'Morning coffee with team',
}) {
  final now = dateTime ?? DateTime(2026, 9, 26, 10, 30);
  return TransactionModel(
    id: id,
    userId: userId,
    amount: amount,
    type: type,
    merchantName: merchantName,
    category: category,
    dateTime: now,
    paymentMethod: paymentMethod,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetForTesting();
    FinancialProfileService.resetForTesting();
    GoalService.resetForTesting();
    TransactionService.resetForTesting();

    await AuthService.instance.init();
    await FinancialProfileService.instance.init();
    await GoalService.instance.init();
    await TransactionService.instance.init();
  });

  group('TransactionModel Unit Tests', () {
    test('Debit transaction properties and formatting', () {
      final tx = makeTransaction(
        amount: 1250.0,
        type: TransactionType.debit,
      );

      expect(tx.isDebit, isTrue);
      expect(tx.isCredit, isFalse);
      expect(tx.formattedAmount, '₹1250');
      expect(tx.signedFormattedAmount, '- ₹1250');
      expect(tx.type.displayName, 'Debit');
    });

    test('Credit transaction properties and formatting', () {
      final tx = makeTransaction(
        amount: 50000.0,
        type: TransactionType.credit,
        merchantName: 'Acme Corp Salary',
        category: TransactionCategories.salaryAndIncome,
      );

      expect(tx.isDebit, isFalse);
      expect(tx.isCredit, isTrue);
      expect(tx.formattedAmount, '₹50000');
      expect(tx.signedFormattedAmount, '+ ₹50000');
      expect(tx.type.displayName, 'Credit');
    });

    test('Decimal amount formatting', () {
      final tx = makeTransaction(amount: 149.99);
      expect(tx.formattedAmount, '₹149.99');
      expect(tx.signedFormattedAmount, '- ₹149.99');
    });

    test('Date and Time formatting', () {
      final dt = DateTime(2026, 9, 26, 14, 5);
      final tx = makeTransaction(dateTime: dt);

      expect(tx.formattedDate, '26 Sep 2026');
      expect(tx.formattedTime, '02:05 PM');
      expect(tx.formattedDateTime, '26 Sep 2026, 02:05 PM');
    });

    test('Serialization roundtrip preserves all values', () {
      final original = makeTransaction();
      final jsonStr = original.toJson();
      final restored = TransactionModel.fromJson(jsonStr);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.amount, original.amount);
      expect(restored.type, original.type);
      expect(restored.merchantName, original.merchantName);
      expect(restored.category, original.category);
      expect(restored.dateTime, original.dateTime);
      expect(restored.paymentMethod, original.paymentMethod);
      expect(restored.notes, original.notes);
    });

    test('copyWith updates specified fields only', () {
      final tx = makeTransaction();
      final updated = tx.copyWith(
        amount: 2000.0,
        merchantName: 'Blue Tokai',
        notes: 'Cold brew',
      );

      expect(updated.id, tx.id);
      expect(updated.amount, 2000.0);
      expect(updated.merchantName, 'Blue Tokai');
      expect(updated.notes, 'Cold brew');
      expect(updated.category, tx.category);
    });

    test('PaymentMethod enum parsing and display names', () {
      expect(PaymentMethod.upi.displayName, 'UPI');
      expect(PaymentMethod.card.displayName, 'Card');
      expect(PaymentMethod.netBanking.displayName, 'Net Banking');
      expect(PaymentMethod.cash.displayName, 'Cash');
      expect(PaymentMethod.other.displayName, 'Other');

      expect(PaymentMethod.fromString('upi'), PaymentMethod.upi);
      expect(PaymentMethod.fromString('Card'), PaymentMethod.card);
      expect(PaymentMethod.fromString('netbanking'), PaymentMethod.netBanking);
      expect(PaymentMethod.fromString('invalid'), PaymentMethod.other);
      expect(PaymentMethod.fromString(null), PaymentMethod.other);
    });

    test('TransactionType enum parsing', () {
      expect(TransactionType.fromString('debit'), TransactionType.debit);
      expect(TransactionType.fromString('Credit'), TransactionType.credit);
      expect(TransactionType.fromString('invalid'), TransactionType.debit);
      expect(TransactionType.fromString(null), TransactionType.debit);
    });
  });

  group('Transaction Validation Tests', () {
    test('Valid inputs return isValid true with no errors', () {
      final result = validateTransactionInputs(
        amountRaw: '450',
        merchantName: 'Supermarket',
        category: TransactionCategories.groceries,
        dateTime: DateTime.now(),
      );

      expect(result.isValid, isTrue);
      expect(result.amountError, isNull);
      expect(result.merchantError, isNull);
      expect(result.categoryError, isNull);
      expect(result.dateError, isNull);
    });

    test('Invalid amount fails validation', () {
      expect(
        validateTransactionInputs(
          amountRaw: '',
          merchantName: 'Shop',
          category: 'Shopping',
          dateTime: DateTime.now(),
        ).amountError,
        isNotNull,
      );

      expect(
        validateTransactionInputs(
          amountRaw: '0',
          merchantName: 'Shop',
          category: 'Shopping',
          dateTime: DateTime.now(),
        ).amountError,
        isNotNull,
      );

      expect(
        validateTransactionInputs(
          amountRaw: '-50',
          merchantName: 'Shop',
          category: 'Shopping',
          dateTime: DateTime.now(),
        ).amountError,
        isNotNull,
      );

      expect(
        validateTransactionInputs(
          amountRaw: 'abc',
          merchantName: 'Shop',
          category: 'Shopping',
          dateTime: DateTime.now(),
        ).amountError,
        isNotNull,
      );
    });

    test('Empty merchant fails validation', () {
      final result = validateTransactionInputs(
        amountRaw: '100',
        merchantName: '   ',
        category: 'Food',
        dateTime: DateTime.now(),
      );
      expect(result.isValid, isFalse);
      expect(result.merchantError, contains('Merchant name is required'));
    });

    test('Empty category fails validation', () {
      final result = validateTransactionInputs(
        amountRaw: '100',
        merchantName: 'Merchant',
        category: '',
        dateTime: DateTime.now(),
      );
      expect(result.isValid, isFalse);
      expect(result.categoryError, contains('Category is required'));
    });

    test('Null date fails validation', () {
      final result = validateTransactionInputs(
        amountRaw: '100',
        merchantName: 'Merchant',
        category: 'Food',
        dateTime: null,
      );
      expect(result.isValid, isFalse);
      expect(result.dateError, contains('Transaction date is required'));
    });
  });

  group('TransactionService Storage & CRUD Tests', () {
    test('createTransaction persists and retrieves transaction', () async {
      final res = await TransactionService.instance.createTransaction(
        userId: 'u1',
        amountRaw: '1500',
        type: TransactionType.debit,
        merchantName: 'Grocery Store',
        category: TransactionCategories.groceries,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 9, 20),
        notes: 'Weekly pantry run',
      );

      expect(res.isSuccess, isTrue);
      expect(res.transaction, isNotNull);

      final list = TransactionService.instance.getTransactionsForUser('u1');
      expect(list.length, 1);
      expect(list.first.merchantName, 'Grocery Store');
      expect(list.first.amount, 1500);
      expect(list.first.paymentMethod, PaymentMethod.card);
      expect(list.first.notes, 'Weekly pantry run');
    });

    test('User-specific transaction isolation', () async {
      await TransactionService.instance.createTransaction(
        userId: 'user_A',
        amountRaw: '500',
        type: TransactionType.debit,
        merchantName: 'Merchant A',
        category: 'Shopping',
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime.now(),
      );

      await TransactionService.instance.createTransaction(
        userId: 'user_B',
        amountRaw: '1200',
        type: TransactionType.credit,
        merchantName: 'Merchant B',
        category: 'Salary',
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime.now(),
      );

      final listA = TransactionService.instance.getTransactionsForUser('user_A');
      final listB = TransactionService.instance.getTransactionsForUser('user_B');

      expect(listA.length, 1);
      expect(listA.first.merchantName, 'Merchant A');

      expect(listB.length, 1);
      expect(listB.first.merchantName, 'Merchant B');
    });

    test('Transactions are sorted newest first', () async {
      await TransactionService.instance.createTransaction(
        userId: 'u_sort',
        amountRaw: '100',
        type: TransactionType.debit,
        merchantName: 'Older Tx',
        category: 'Food',
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 9, 10),
      );

      await TransactionService.instance.createTransaction(
        userId: 'u_sort',
        amountRaw: '200',
        type: TransactionType.debit,
        merchantName: 'Newer Tx',
        category: 'Food',
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 9, 25),
      );

      final list = TransactionService.instance.getTransactionsForUser('u_sort');
      expect(list.length, 2);
      expect(list[0].merchantName, 'Newer Tx');
      expect(list[1].merchantName, 'Older Tx');
    });

    test('updateTransaction modifies and persists changes', () async {
      final created = await TransactionService.instance.createTransaction(
        userId: 'u_upd',
        amountRaw: '300',
        type: TransactionType.debit,
        merchantName: 'Old Merchant',
        category: 'Food',
        paymentMethod: PaymentMethod.cash,
        dateTime: DateTime(2026, 9, 1),
      );

      final txId = created.transaction!.id;

      final updRes = await TransactionService.instance.updateTransaction(
        userId: 'u_upd',
        id: txId,
        amountRaw: '350',
        type: TransactionType.debit,
        merchantName: 'Updated Merchant',
        category: TransactionCategories.groceries,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 9, 2),
        notes: 'Price updated',
      );

      expect(updRes.isSuccess, isTrue);

      final fetched = TransactionService.instance.getTransactionById('u_upd', txId);
      expect(fetched, isNotNull);
      expect(fetched!.amount, 350);
      expect(fetched.merchantName, 'Updated Merchant');
      expect(fetched.category, TransactionCategories.groceries);
      expect(fetched.paymentMethod, PaymentMethod.card);
      expect(fetched.notes, 'Price updated');
    });

    test('deleteTransaction removes transaction from storage', () async {
      final created = await TransactionService.instance.createTransaction(
        userId: 'u_del',
        amountRaw: '500',
        type: TransactionType.debit,
        merchantName: 'Delete Me',
        category: 'Other',
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime.now(),
      );

      final txId = created.transaction!.id;
      expect(TransactionService.instance.getTransactionsForUser('u_del').length, 1);

      final deleted = await TransactionService.instance.deleteTransaction('u_del', txId);
      expect(deleted, isTrue);
      expect(TransactionService.instance.getTransactionsForUser('u_del').length, 0);
    });

    test('Cash flow calculations: debit, credit, net, and total count', () async {
      const userId = 'u_calc';
      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '50000',
        type: TransactionType.credit,
        merchantName: 'Monthly Salary',
        category: TransactionCategories.salaryAndIncome,
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime(2026, 9, 1),
      );

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '15000',
        type: TransactionType.debit,
        merchantName: 'Rent',
        category: TransactionCategories.billsAndUtilities,
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime(2026, 9, 2),
      );

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '5000',
        type: TransactionType.debit,
        merchantName: 'Groceries',
        category: TransactionCategories.groceries,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 9, 5),
      );

      expect(TransactionService.instance.getTotalCount(userId), 3);
      expect(TransactionService.instance.getTotalCredit(userId), 50000.0);
      expect(TransactionService.instance.getTotalDebit(userId), 20000.0);
      expect(TransactionService.instance.getNetCashFlow(userId), 30000.0);
    });
  });

  group('TransactionsPage Widget Tests', () {
    testWidgets('Displays polished empty state when no transactions exist', (tester) async {
      await AuthService.instance.register(
        fullName: 'Empty User',
        phone: '9000000051',
        countryCode: '+91',
        email: 'empty@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(home: TransactionsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(
        find.text('Transactions will appear when financial data is connected.'),
        findsOneWidget,
      );
      expect(find.text('Add Transaction'), findsWidgets);
    });

    testWidgets('Displays transactions list and summary metrics', (tester) async {
      await AuthService.instance.register(
        fullName: 'Tx User',
        phone: '9000000052',
        countryCode: '+91',
        email: 'txuser@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '750',
        type: TransactionType.debit,
        merchantName: 'Whole Foods Market',
        category: TransactionCategories.groceries,
        paymentMethod: PaymentMethod.card,
        dateTime: DateTime(2026, 9, 25, 14, 0),
      );

      await tester.pumpWidget(
        const MaterialApp(home: TransactionsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Whole Foods Market'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('- ₹750'), findsOneWidget);
      expect(find.text('Total Count'), findsOneWidget);
      expect(find.text('Total Outflow'), findsOneWidget);
      expect(find.text('Total Inflow'), findsOneWidget);
    });

    testWidgets('Filter chips filter between Debit and Credit', (tester) async {
      await AuthService.instance.register(
        fullName: 'Filter User',
        phone: '9000000053',
        countryCode: '+91',
        email: 'filter@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '200',
        type: TransactionType.debit,
        merchantName: 'Coffee Shop',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 9, 20),
      );

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '25000',
        type: TransactionType.credit,
        merchantName: 'Client Payment',
        category: TransactionCategories.salaryAndIncome,
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime(2026, 9, 21),
      );

      await tester.pumpWidget(
        const MaterialApp(home: TransactionsPage()),
      );
      await tester.pumpAndSettle();

      // All: both present
      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Client Payment'), findsOneWidget);

      // Tap Debit chip
      await tester.tap(find.text('Debit'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Client Payment'), findsNothing);

      // Tap Credit chip
      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsNothing);
      expect(find.text('Client Payment'), findsOneWidget);
    });
  });

  group('TransactionDetailPage Widget Tests', () {
    testWidgets('Shows full transaction details and notes', (tester) async {
      final tx = makeTransaction(
        amount: 3499.0,
        type: TransactionType.debit,
        merchantName: 'Nike Retail Store',
        category: TransactionCategories.shopping,
        paymentMethod: PaymentMethod.card,
        notes: 'Running shoes for marathon training',
      );

      await tester.pumpWidget(
        MaterialApp(home: TransactionDetailPage(transaction: tx)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transaction Details'), findsOneWidget);
      expect(find.text('Nike Retail Store'), findsWidgets);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Running shoes for marathon training'), findsOneWidget);
      expect(find.text('- ₹3499'), findsOneWidget);
      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('Edit Transaction'), findsOneWidget);
    });
  });

  group('Dashboard Recent Transactions Section Tests', () {
    testWidgets('Shows empty state when no transactions exist', (tester) async {
      await AuthService.instance.register(
        fullName: 'Dash User',
        phone: '9000000054',
        countryCode: '+91',
        email: 'dash@example.com',
        password: 'Password123',
      );

      await tester.pumpWidget(
        const MaterialApp(home: DashboardPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(
        find.text('Transactions will appear here when your financial data is connected.'),
        findsOneWidget,
      );
      expect(find.text('View All Transactions'), findsOneWidget);
    });

    testWidgets('Shows recent transactions and View All link when transactions exist', (tester) async {
      await AuthService.instance.register(
        fullName: 'Dash Populated',
        phone: '9000000055',
        countryCode: '+91',
        email: 'dashpop@example.com',
        password: 'Password123',
      );
      final userId = AuthService.instance.currentUser!.id;

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '650',
        type: TransactionType.debit,
        merchantName: 'Cafe Coffee Day',
        category: TransactionCategories.foodAndDining,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime.now(),
      );

      await tester.pumpWidget(
        const MaterialApp(home: DashboardPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
      expect(find.text('Cafe Coffee Day'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });
  });
}
