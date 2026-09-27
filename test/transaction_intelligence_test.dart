import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/intelligence.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';
import 'package:goalsync/features/transactions/services/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TransactionService.resetForTesting();
    TransactionIntelligenceService.resetForTesting();
    await TransactionService.instance.init();
  });

  TransactionModel createTx({
    String id = 'tx_test',
    String userId = 'u1',
    double amount = 1000.0,
    TransactionType type = TransactionType.debit,
    String merchantName = 'Test Merchant',
    String category = TransactionCategories.other,
    DateTime? dateTime,
    PaymentMethod paymentMethod = PaymentMethod.upi,
    String? notes,
  }) {
    final now = dateTime ?? DateTime(2026, 9, 26);
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

  group('Transaction Intelligence Tests', () {
    test('1. Debit transaction produces expense impact', () {
      final tx = createTx(
        type: TransactionType.debit,
        amount: 850.0,
      );

      final intelligence = TransactionIntelligenceEngine.analyzeTransaction(tx);

      expect(intelligence.financialImpact, FinancialImpact.expense);
      expect(intelligence.isExpense, isTrue);
      expect(intelligence.isIncome, isFalse);
      expect(intelligence.isNeutral, isFalse);
      expect(intelligence.tags, contains('expense'));
    });

    test('2. Credit transaction produces income impact', () {
      final tx = createTx(
        type: TransactionType.credit,
        amount: 75000.0,
        merchantName: 'Tech Corp Salary',
      );

      final intelligence = TransactionIntelligenceEngine.analyzeTransaction(tx);

      expect(intelligence.financialImpact, FinancialImpact.income);
      expect(intelligence.isIncome, isTrue);
      expect(intelligence.isExpense, isFalse);
      expect(intelligence.isNeutral, isFalse);
      expect(intelligence.tags, contains('income'));
    });

    test('3. Merchant normalization works for known merchant variations', () {
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('AMAZON PAY INDIA'),
        'Amazon',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('Amazon.in'),
        'Amazon',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('SWIGGY INSTAMART'),
        'Swiggy',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('SWIGGY FOOD'),
        'Swiggy',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('ZOMATO ORDER'),
        'Zomato',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('UBER TRIP'),
        'Uber',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('NETFLIX ENTERTAINMENT'),
        'Netflix',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('TATA STARBUCKS'),
        'Starbucks',
      );
    });

    test('4. Unknown merchant remains unchanged', () {
      const unknown1 = 'Local Corner Chai Stall';
      const unknown2 = 'Dr. Sen Orthopedic Care';

      expect(
        TransactionIntelligenceEngine.normalizeMerchant(unknown1),
        unknown1,
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant(unknown2),
        unknown2,
      );
      expect(
        TransactionIntelligenceEngine.isKnownMerchant(unknown1),
        isFalse,
      );
    });

    test('5. Existing category is preserved', () {
      final tx = createTx(
        merchantName: 'Amazon',
        category: 'Custom Electronics', // User specified category
      );

      final category = TransactionIntelligenceEngine.inferCategory(
        rawMerchant: tx.merchantName,
        currentCategory: tx.category,
      );

      expect(category, 'Custom Electronics');
    });

    test('6. Missing category can be inferred from known merchant', () {
      // Swiggy with empty category -> Food & Dining
      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'SWIGGY INSTAMART',
          currentCategory: '',
        ),
        TransactionCategories.foodAndDining,
      );

      // Netflix with Other category -> Entertainment
      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'Netflix.com',
          currentCategory: TransactionCategories.other,
        ),
        TransactionCategories.entertainment,
      );

      // Uber India with Other category -> Transport
      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'Uber India',
          currentCategory: TransactionCategories.other,
        ),
        TransactionCategories.transport,
      );

      // Amazon with empty category -> Shopping
      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'Amazon Retail',
          currentCategory: '',
        ),
        TransactionCategories.shopping,
      );
    });

    test('7. Unknown category becomes Other', () {
      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'Completely Unknown Vendor XYZ',
          currentCategory: '',
        ),
        TransactionCategories.other,
      );

      expect(
        TransactionIntelligenceEngine.inferCategory(
          rawMerchant: 'ABC Enterprise 123',
          currentCategory: TransactionCategories.other,
        ),
        TransactionCategories.other,
      );
    });

    test('8. Spending aggregation by category is correct', () {
      final transactions = [
        createTx(
          id: '1',
          amount: 500,
          category: TransactionCategories.foodAndDining,
          type: TransactionType.debit,
        ),
        createTx(
          id: '2',
          amount: 1500,
          category: TransactionCategories.foodAndDining,
          type: TransactionType.debit,
        ),
        createTx(
          id: '3',
          amount: 3000,
          category: TransactionCategories.shopping,
          type: TransactionType.debit,
        ),
        createTx(
          id: '4',
          amount: 50000,
          category: TransactionCategories.salaryAndIncome,
          type: TransactionType.credit, // Credit should NOT be counted in category spending
        ),
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);
      final summary = TransactionIntelligenceEngine.summarize(analyzed);

      expect(
        summary.spendingByCategory[TransactionCategories.foodAndDining],
        2000.0,
      );
      expect(
        summary.spendingByCategory[TransactionCategories.shopping],
        3000.0,
      );
      // Credit salary should not appear in debit spending
      expect(
        summary.spendingByCategory.containsKey(TransactionCategories.salaryAndIncome),
        isFalse,
      );
    });

    test('9. Spending aggregation by merchant groups variations to normalized name', () {
      final transactions = [
        createTx(
          id: '1',
          merchantName: 'AMAZON PAY INDIA',
          amount: 1200,
          type: TransactionType.debit,
        ),
        createTx(
          id: '2',
          merchantName: 'Amazon.in',
          amount: 800,
          type: TransactionType.debit,
        ),
        createTx(
          id: '3',
          merchantName: 'Swiggy Food',
          amount: 450,
          type: TransactionType.debit,
        ),
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);
      final summary = TransactionIntelligenceEngine.summarize(analyzed);

      // Both Amazon variants aggregated under 'Amazon'
      expect(summary.spendingByMerchant['Amazon'], 2000.0);
      expect(summary.spendingByMerchant['Swiggy'], 450.0);
    });

    test('10. Largest expense is detected correctly', () {
      final transactions = [
        createTx(id: '1', amount: 450, type: TransactionType.debit),
        createTx(id: '2', amount: 15000, type: TransactionType.debit), // Largest
        createTx(id: '3', amount: 3200, type: TransactionType.debit),
        createTx(id: '4', amount: 90000, type: TransactionType.credit), // Credit should not be largest expense
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);
      final summary = TransactionIntelligenceEngine.summarize(analyzed);

      expect(summary.largestExpense, isNotNull);
      expect(summary.largestExpense!.amount, 15000.0);
      expect(summary.largestExpense!.transactionId, '2');
    });

    test('11. Largest income is detected correctly', () {
      final transactions = [
        createTx(id: '1', amount: 10000, type: TransactionType.credit),
        createTx(id: '2', amount: 95000, type: TransactionType.credit), // Largest
        createTx(id: '3', amount: 20000, type: TransactionType.credit),
        createTx(id: '4', amount: 120000, type: TransactionType.debit), // Debit should not be largest income
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);
      final summary = TransactionIntelligenceEngine.summarize(analyzed);

      expect(summary.largestIncome, isNotNull);
      expect(summary.largestIncome!.amount, 95000.0);
      expect(summary.largestIncome!.transactionId, '2');
    });

    test('12. Average transaction amount is correct', () {
      final transactions = [
        createTx(id: '1', amount: 80000, type: TransactionType.credit),
        createTx(id: '2', amount: 20000, type: TransactionType.debit),
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);
      final summary = TransactionIntelligenceEngine.summarize(analyzed);

      // (80,000 + 20,000) / 2 = 50,000
      expect(summary.averageTransactionAmount, 50000.0);
    });

    test('13. Recurring candidate detection works for repeated transactions', () {
      // 3 consecutive monthly Netflix subscriptions
      final transactions = [
        createTx(
          id: 'tx_sub_1',
          merchantName: 'Netflix.com',
          amount: 649,
          dateTime: DateTime(2026, 6, 1),
        ),
        createTx(
          id: 'tx_sub_2',
          merchantName: 'Netflix.com',
          amount: 649,
          dateTime: DateTime(2026, 7, 1),
        ),
        createTx(
          id: 'tx_sub_3',
          merchantName: 'Netflix Entertainment',
          amount: 649,
          dateTime: DateTime(2026, 8, 1),
        ),
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);

      expect(analyzed.length, 3);
      for (final item in analyzed) {
        expect(item.isRecurringCandidate, isTrue);
        expect(item.tags, contains('recurring_candidate'));
      }
    });

    test('14. Non-recurring transactions are not incorrectly marked recurring', () {
      final transactions = [
        // Single transaction
        createTx(
          id: 'tx_single',
          merchantName: 'Rare Boutique Store',
          amount: 4500,
          dateTime: DateTime(2026, 1, 15),
        ),
        // Irregular transactions: different amounts and irregular spacing
        createTx(
          id: 'tx_irreg_1',
          merchantName: 'Hardware Depot',
          amount: 120,
          dateTime: DateTime(2026, 1, 1),
        ),
        createTx(
          id: 'tx_irreg_2',
          merchantName: 'Hardware Depot',
          amount: 5800, // Widely different amount
          dateTime: DateTime(2026, 1, 4), // 3 days later
        ),
      ];

      final analyzed = TransactionIntelligenceEngine.analyzeAll(transactions);

      for (final item in analyzed) {
        expect(item.isRecurringCandidate, isFalse);
        expect(item.tags, isNot(contains('recurring_candidate')));
      }
    });

    test('15. Empty transaction history works safely', () {
      final analyzed = TransactionIntelligenceEngine.analyzeAll([]);
      expect(analyzed, isEmpty);

      final summary = TransactionIntelligenceEngine.summarize([]);
      expect(summary.transactionCount, 0);
      expect(summary.totalIncome, 0.0);
      expect(summary.totalExpenses, 0.0);
      expect(summary.averageTransactionAmount, 0.0);
      expect(summary.largestExpense, isNull);
      expect(summary.largestIncome, isNull);
      expect(summary.spendingByCategory, isEmpty);
      expect(summary.spendingByMerchant, isEmpty);
      expect(summary.recurringCandidateCount, 0);
    });

    test('16. No existing TransactionModel data is modified', () {
      final original = createTx(
        id: 'tx_orig_1',
        userId: 'user_test',
        amount: 2500.50,
        type: TransactionType.debit,
        merchantName: 'AMAZON PAY INDIA',
        category: TransactionCategories.other,
        dateTime: DateTime(2026, 9, 26, 14, 30),
        paymentMethod: PaymentMethod.card,
        notes: 'Monthly purchase',
      );

      final originalJson = original.toJson();

      // Run through intelligence analysis
      final intelligence =
          TransactionIntelligenceEngine.analyzeTransaction(original);

      // Verify enriched data is computed
      expect(intelligence.normalizedMerchantName, 'Amazon');
      expect(intelligence.category, TransactionCategories.shopping);

      // Verify the original model is 100% unchanged
      expect(original.id, 'tx_orig_1');
      expect(original.userId, 'user_test');
      expect(original.amount, 2500.50);
      expect(original.type, TransactionType.debit);
      expect(original.merchantName, 'AMAZON PAY INDIA');
      expect(original.category, TransactionCategories.other);
      expect(original.notes, 'Monthly purchase');
      expect(original.toJson(), originalJson);
    });

    test('17. Service loads and summarizes stored transactions for a user', () async {
      const userId = 'user_service_test';
      final service = TransactionIntelligenceService.instance;

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '45000',
        type: TransactionType.credit,
        merchantName: 'Salary Transfer',
        category: TransactionCategories.salaryAndIncome,
        paymentMethod: PaymentMethod.netBanking,
        dateTime: DateTime(2026, 9, 1),
      );

      await TransactionService.instance.createTransaction(
        userId: userId,
        amountRaw: '1200',
        type: TransactionType.debit,
        merchantName: 'SWIGGY FOOD',
        category: TransactionCategories.other,
        paymentMethod: PaymentMethod.upi,
        dateTime: DateTime(2026, 9, 10),
      );

      final summary = await service.buildSummary(userId);

      expect(summary.userId, userId);
      expect(summary.transactionCount, 2);
      expect(summary.totalIncome, 45000.0);
      expect(summary.totalExpenses, 1200.0);
      expect(summary.netCashFlow, 43800.0);
      expect(summary.spendingByMerchant['Swiggy'], 1200.0);

      // Test serialization roundtrip
      final jsonStr = summary.toJson();
      final restored = TransactionIntelligenceSummary.fromJson(jsonStr);
      expect(restored.transactionCount, summary.transactionCount);
      expect(restored.totalIncome, summary.totalIncome);
      expect(restored.spendingByMerchant, summary.spendingByMerchant);
    });
  });
}
