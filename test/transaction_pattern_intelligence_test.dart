import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/transaction_intelligence.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';

void main() {
  group('Transaction Pattern Intelligence Tests', () {
    const service = TransactionPatternService();

    TransactionModel buildTx({
      String id = 'tx_1',
      String userId = 'u1',
      double amount = 1000.0,
      TransactionType type = TransactionType.debit,
      String merchantName = 'Test Merchant',
      String category = TransactionCategories.foodAndDining,
      DateTime? dateTime,
      PaymentMethod paymentMethod = PaymentMethod.upi,
      String? notes,
    }) {
      final dt = dateTime ?? DateTime(2026, 6, 1);
      return TransactionModel(
        id: id,
        userId: userId,
        amount: amount,
        type: type,
        merchantName: merchantName,
        category: category,
        dateTime: dt,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: dt,
        updatedAt: dt,
      );
    }

    // 1. Empty transaction list
    test('1. Empty transaction list safely returns zeroed snapshot without crashing', () {
      final snapshot = service.analyze([]);

      expect(snapshot.totalTransactionCount, 0);
      expect(snapshot.totalIncome, 0.0);
      expect(snapshot.totalExpenses, 0.0);
      expect(snapshot.totalCredits, 0.0);
      expect(snapshot.totalDebits, 0.0);
      expect(snapshot.largestExpense, 0.0);
      expect(snapshot.largestIncome, 0.0);
      expect(snapshot.averageExpense, 0.0);
      expect(snapshot.averageIncome, 0.0);
      expect(snapshot.categoryTotals, isEmpty);
      expect(snapshot.merchantTotals, isEmpty);
      expect(snapshot.recurringCandidates, isEmpty);
      expect(snapshot.netCashFlow, 0.0);
    });

    // 2. Transaction count
    test('2. Total transaction count correctly reflects collection size', () {
      final transactions = [
        buildTx(id: '1', amount: 500),
        buildTx(id: '2', amount: 1500),
        buildTx(id: '3', amount: 2500),
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.totalTransactionCount, 3);
    });

    // 3. Total income
    test('3. Total income aggregates only credit transactions', () {
      final transactions = [
        buildTx(id: '1', amount: 65000, type: TransactionType.credit),
        buildTx(id: '2', amount: 15000, type: TransactionType.credit),
        buildTx(id: '3', amount: 4500, type: TransactionType.debit),
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.totalIncome, 80000.0);
      expect(snapshot.totalCredits, 80000.0);
    });

    // 4. Total expenses
    test('4. Total expenses aggregates only debit transactions', () {
      final transactions = [
        buildTx(id: '1', amount: 1200, type: TransactionType.debit),
        buildTx(id: '2', amount: 3800, type: TransactionType.debit),
        buildTx(id: '3', amount: 50000, type: TransactionType.credit),
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.totalExpenses, 5000.0);
      expect(snapshot.totalDebits, 5000.0);
    });

    // 5. Largest expense
    test('5. Largest expense identifies maximum debit amount', () {
      final transactions = [
        buildTx(id: '1', amount: 800, type: TransactionType.debit),
        buildTx(id: '2', amount: 12500, type: TransactionType.debit),
        buildTx(id: '3', amount: 4200, type: TransactionType.debit),
        buildTx(id: '4', amount: 90000, type: TransactionType.credit), // Should not qualify
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.largestExpense, 12500.0);
    });

    // 6. Largest income
    test('6. Largest income identifies maximum credit amount', () {
      final transactions = [
        buildTx(id: '1', amount: 10000, type: TransactionType.credit),
        buildTx(id: '2', amount: 95000, type: TransactionType.credit),
        buildTx(id: '3', amount: 25000, type: TransactionType.credit),
        buildTx(id: '4', amount: 120000, type: TransactionType.debit), // Should not qualify
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.largestIncome, 95000.0);
    });

    // 7. Average expense
    test('7. Average expense calculates mean across debit transactions', () {
      final transactions = [
        buildTx(id: '1', amount: 1000, type: TransactionType.debit),
        buildTx(id: '2', amount: 3000, type: TransactionType.debit),
        buildTx(id: '3', amount: 50000, type: TransactionType.credit), // Ignored in expense avg
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.averageExpense, 2000.0);
    });

    // 8. Average income
    test('8. Average income calculates mean across credit transactions', () {
      final transactions = [
        buildTx(id: '1', amount: 60000, type: TransactionType.credit),
        buildTx(id: '2', amount: 40000, type: TransactionType.credit),
        buildTx(id: '3', amount: 5000, type: TransactionType.debit), // Ignored in income avg
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.averageIncome, 50000.0);
    });

    // 9. Category aggregation
    test('9. Category aggregation groups spending by transaction category', () {
      final transactions = [
        buildTx(
          id: '1',
          amount: 1500,
          category: TransactionCategories.foodAndDining,
          type: TransactionType.debit,
        ),
        buildTx(
          id: '2',
          amount: 3000,
          category: TransactionCategories.foodAndDining,
          type: TransactionType.debit,
        ),
        buildTx(
          id: '3',
          amount: 4500,
          category: TransactionCategories.shopping,
          type: TransactionType.debit,
        ),
        buildTx(
          id: '4',
          amount: 999,
          category: TransactionCategories.entertainment,
          type: TransactionType.debit,
        ),
      ];

      final snapshot = service.analyze(transactions);

      expect(
        snapshot.categoryTotals[TransactionCategories.foodAndDining],
        4500.0,
      );
      expect(
        snapshot.categoryTotals[TransactionCategories.shopping],
        4500.0,
      );
      expect(
        snapshot.categoryTotals[TransactionCategories.entertainment],
        999.0,
      );
    });

    // 10. Merchant aggregation
    test('10. Merchant aggregation groups spending by normalized merchant name', () {
      final transactions = [
        buildTx(
          id: '1',
          amount: 800,
          merchantName: 'SWIGGY*ORDER123',
          type: TransactionType.debit,
        ),
        buildTx(
          id: '2',
          amount: 1200,
          merchantName: 'Swiggy IN',
          type: TransactionType.debit,
        ),
        buildTx(
          id: '3',
          amount: 3400,
          merchantName: 'AMAZON PAY',
          type: TransactionType.debit,
        ),
      ];

      final snapshot = service.analyze(transactions);

      expect(snapshot.merchantTotals['Swiggy'], 2000.0);
      expect(snapshot.merchantTotals['Amazon'], 3400.0);
    });

    // 11. Repeated same merchant detection
    test('11. Repeated same merchant detection identifies recurring candidate presence', () {
      final transactions = [
        buildTx(
          id: 'sub_1',
          merchantName: 'Netflix.com',
          amount: 649,
          dateTime: DateTime(2026, 6, 1),
        ),
        buildTx(
          id: 'sub_2',
          merchantName: 'Netflix',
          amount: 649,
          dateTime: DateTime(2026, 7, 1),
        ),
        buildTx(
          id: 'sub_3',
          merchantName: 'Netflix Entertainment',
          amount: 649,
          dateTime: DateTime(2026, 8, 1),
        ),
      ];

      final snapshot = service.analyze(transactions);

      expect(snapshot.recurringCandidates.isNotEmpty, isTrue);
      final netflixCandidate = snapshot.recurringCandidates.firstWhere(
        (c) => c.merchant == 'Netflix',
      );
      expect(netflixCandidate.occurrenceCount, 3);
      expect(netflixCandidate.merchant, 'Netflix');
    });

    // 12. Similar repeated amount detection
    test('12. Similar repeated amount detection calculates average amount and regular spacing', () {
      final transactions = [
        buildTx(
          id: 'sub_1',
          merchantName: 'Spotify India',
          amount: 119,
          dateTime: DateTime(2026, 5, 15),
        ),
        buildTx(
          id: 'sub_2',
          merchantName: 'Spotify',
          amount: 119,
          dateTime: DateTime(2026, 6, 15),
        ),
        buildTx(
          id: 'sub_3',
          merchantName: 'Spotify',
          amount: 119,
          dateTime: DateTime(2026, 7, 15),
        ),
      ];

      final snapshot = service.analyze(transactions);

      expect(snapshot.recurringCandidates.length, 1);
      final spotify = snapshot.recurringCandidates.first;
      expect(spotify.merchant, 'Spotify');
      expect(spotify.averageAmount, 119.0);
      expect(spotify.occurrenceCount, 3);
      expect(spotify.intervalDays, inInclusiveRange(28, 32));
      expect(spotify.confidence, IntelligenceConfidence.high);
    });

    // 13. Irregular transactions should not automatically become recurring
    test('13. Irregular transactions with different amounts and sporadic dates do not become recurring candidates', () {
      final transactions = [
        buildTx(
          id: 'irr_1',
          merchantName: 'Corner Hardware Store',
          amount: 120,
          dateTime: DateTime(2026, 1, 1),
        ),
        buildTx(
          id: 'irr_2',
          merchantName: 'Corner Hardware Store',
          amount: 4500, // Widely different amount
          dateTime: DateTime(2026, 1, 3), // Only 2 days later
        ),
      ];

      final snapshot = service.analyze(transactions);
      expect(snapshot.recurringCandidates, isEmpty);
    });

    // 14. Multiple merchants
    test('14. Multiple merchants correctly aggregates discrete totals and evaluates candidates', () {
      final transactions = [
        // Recurring subscription 1
        buildTx(
          id: 'n1',
          merchantName: 'Netflix',
          amount: 649,
          category: TransactionCategories.entertainment,
          dateTime: DateTime(2026, 5, 1),
        ),
        buildTx(
          id: 'n2',
          merchantName: 'Netflix',
          amount: 649,
          category: TransactionCategories.entertainment,
          dateTime: DateTime(2026, 6, 1),
        ),
        // One-off Swiggy order
        buildTx(
          id: 's1',
          merchantName: 'SWIGGY*ORDER123',
          amount: 450,
          category: TransactionCategories.foodAndDining,
          dateTime: DateTime(2026, 6, 10),
        ),
        // One-off Uber ride
        buildTx(
          id: 'u1',
          merchantName: 'UBER INDIA',
          amount: 320,
          category: TransactionCategories.transport,
          dateTime: DateTime(2026, 6, 12),
        ),
      ];

      final snapshot = service.analyze(transactions);

      expect(snapshot.totalTransactionCount, 4);
      expect(snapshot.merchantTotals['Netflix'], 1298.0);
      expect(snapshot.merchantTotals['Swiggy'], 450.0);
      expect(snapshot.merchantTotals['Uber'], 320.0);

      expect(snapshot.recurringCandidates.length, 1);
      expect(snapshot.recurringCandidates.first.merchant, 'Netflix');
    });

    // 15. Original TransactionModel objects remain unchanged
    test('15. Original TransactionModel objects remain completely unchanged after analysis', () {
      final originalList = [
        buildTx(
          id: 'imm_1',
          merchantName: 'SWIGGY*ORDER123',
          amount: 450.0,
          category: TransactionCategories.foodAndDining,
          type: TransactionType.debit,
          notes: 'Dinner combo',
        ),
        buildTx(
          id: 'imm_2',
          merchantName: 'Tech Corp Payroll',
          amount: 90000.0,
          category: TransactionCategories.salaryAndIncome,
          type: TransactionType.credit,
          notes: 'June salary',
        ),
      ];

      final originalJsons = originalList.map((tx) => tx.toJson()).toList();

      final snapshot = service.analyze(originalList);

      // Verify analysis completed successfully
      expect(snapshot.totalTransactionCount, 2);
      expect(snapshot.totalIncome, 90000.0);
      expect(snapshot.totalExpenses, 450.0);

      // Verify original objects are unchanged
      for (int i = 0; i < originalList.length; i++) {
        expect(originalList[i].toJson(), originalJsons[i]);
      }
    });
  });
}
