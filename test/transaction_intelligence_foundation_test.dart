import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/transaction_intelligence.dart';
import 'package:goalsync/features/transactions/models/transaction_model.dart';

void main() {
  group('Foundational Transaction Intelligence Tests', () {
    late TransactionIntelligenceService service;

    setUp(() {
      service = TransactionIntelligenceService();
    });

    TransactionModel buildTestTransaction({
      String id = 'tx_123',
      String userId = 'user_001',
      double amount = 500.0,
      TransactionType type = TransactionType.debit,
      String merchantName = 'Swiggy',
      String category = TransactionCategories.other,
      DateTime? dateTime,
      PaymentMethod paymentMethod = PaymentMethod.upi,
      String? notes,
    }) {
      final dt = dateTime ?? DateTime(2026, 9, 27, 10, 30);
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

    // 1. Swiggy normalization
    test('1. Swiggy normalization handles variations to canonical "Swiggy"', () {
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('SWIGGY*ORDER123'),
        'Swiggy',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('Swiggy'),
        'Swiggy',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('SWIGGY IN'),
        'Swiggy',
      );
    });

    // 2. Amazon normalization
    test('2. Amazon normalization handles variations to canonical "Amazon"', () {
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('AMAZON PAY'),
        'Amazon',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('AMAZON.IN'),
        'Amazon',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('Amazon'),
        'Amazon',
      );
    });

    // 3. Uber normalization
    test('3. Uber normalization handles variations to canonical "Uber"', () {
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('UBER INDIA'),
        'Uber',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('UBER'),
        'Uber',
      );
      expect(
        TransactionIntelligenceEngine.normalizeMerchant('Uber Trip'),
        'Uber',
      );
    });

    // 4. Known category inference
    test('4. Known category inference correctly maps known merchants to categories', () {
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Swiggy'),
        InferredCategory.food,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Swiggy').displayName,
        'Food',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Zomato'),
        InferredCategory.food,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Zomato').displayName,
        'Food',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Amazon'),
        InferredCategory.shopping,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Amazon').displayName,
        'Shopping',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Uber'),
        InferredCategory.transport,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Uber').displayName,
        'Transport',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Ola'),
        InferredCategory.transport,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Ola').displayName,
        'Transport',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Netflix'),
        InferredCategory.entertainment,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Netflix').displayName,
        'Entertainment',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Spotify'),
        InferredCategory.entertainment,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Spotify').displayName,
        'Entertainment',
      );

      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Electricity Board'),
        InferredCategory.utilities,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Electricity Board').displayName,
        'Utilities',
      );
    });

    // 5. Unknown merchant -> Other
    test('5. Unknown merchant infers category as Other', () {
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Unknown Corner Kirana'),
        InferredCategory.other,
      );
      expect(
        TransactionIntelligenceEngine.inferCategoryForMerchant('Unknown Corner Kirana').displayName,
        'Other',
      );

      final tx = buildTestTransaction(
        merchantName: 'Unrecognized Vendor 987',
      );
      final intelligence = service.analyze(tx);

      expect(intelligence.inferredCategory, InferredCategory.other);
      expect(intelligence.inferredCategory.displayName, 'Other');
    });

    // 6. Debit -> Expense
    test('6. Debit transaction produces Expense financial impact', () {
      final tx = buildTestTransaction(
        type: TransactionType.debit,
        amount: 450.0,
        merchantName: 'Swiggy',
      );

      final impact = TransactionIntelligenceEngine.determineFinancialImpact(tx.type, tx.amount);
      expect(impact, FinancialImpact.expense);
      expect(impact.isExpense, isTrue);
      expect(impact.displayName, 'Expense');

      final intelligence = service.analyze(tx);
      expect(intelligence.financialImpact, FinancialImpact.expense);
      expect(intelligence.isExpense, isTrue);
    });

    // 7. Credit -> Income
    test('7. Credit transaction produces Income financial impact', () {
      final tx = buildTestTransaction(
        type: TransactionType.credit,
        amount: 85000.0,
        merchantName: 'Tech Corp Payroll',
      );

      final impact = TransactionIntelligenceEngine.determineFinancialImpact(tx.type, tx.amount);
      expect(impact, FinancialImpact.income);
      expect(impact.isIncome, isTrue);
      expect(impact.displayName, 'Income');

      final intelligence = service.analyze(tx);
      expect(intelligence.financialImpact, FinancialImpact.income);
      expect(intelligence.isIncome, isTrue);
    });

    // 8. Known merchant confidence -> High
    test('8. Known merchant classification produces high confidence', () {
      final swiggyConfidence = TransactionIntelligenceEngine.determineConfidence(
        merchantName: 'SWIGGY*ORDER123',
      );
      expect(swiggyConfidence, IntelligenceConfidence.high);
      expect(swiggyConfidence.isHigh, isTrue);

      final amazonTx = buildTestTransaction(
        merchantName: 'AMAZON PAY',
      );
      final intelligence = service.analyze(amazonTx);
      expect(intelligence.confidence, IntelligenceConfidence.high);
      expect(intelligence.confidence.isHigh, isTrue);
    });

    // 9. Unknown merchant confidence -> Low
    test('9. Unknown merchant classification produces low confidence', () {
      final unknownConfidence = TransactionIntelligenceEngine.determineConfidence(
        merchantName: 'Unknown Chai Stall 404',
      );
      expect(unknownConfidence, IntelligenceConfidence.low);
      expect(unknownConfidence.isLow, isTrue);

      final unknownTx = buildTestTransaction(
        merchantName: 'Completely New Vendor XYZ',
      );
      final intelligence = service.analyze(unknownTx);
      expect(intelligence.confidence, IntelligenceConfidence.low);
      expect(intelligence.confidence.isLow, isTrue);
    });

    // 10. Original TransactionModel remains unchanged
    test('10. Original TransactionModel remains completely unchanged after analysis', () {
      final original = buildTestTransaction(
        id: 'tx_immutable_check',
        userId: 'user_safe',
        amount: 1299.99,
        type: TransactionType.debit,
        merchantName: 'SWIGGY*ORDER123',
        category: TransactionCategories.other,
        notes: 'Late dinner order',
      );

      final originalJson = original.toJson();
      final originalId = original.id;
      final originalMerchant = original.merchantName;
      final originalAmount = original.amount;
      final originalType = original.type;
      final originalCategory = original.category;
      final originalNotes = original.notes;

      // Execute analysis through service
      final intelligence = service.analyze(original);

      // Verify derived intelligence has transformed understanding
      expect(intelligence.transactionId, 'tx_immutable_check');
      expect(intelligence.originalMerchantName, 'SWIGGY*ORDER123');
      expect(intelligence.normalizedMerchant, 'Swiggy');
      expect(intelligence.inferredCategory, InferredCategory.food);
      expect(intelligence.transactionType, TransactionType.debit);
      expect(intelligence.financialImpact, FinancialImpact.expense);
      expect(intelligence.confidence, IntelligenceConfidence.high);
      expect(intelligence.isRecurringCandidate, isFalse);

      // Verify original TransactionModel was NOT mutated
      expect(original.id, originalId);
      expect(original.merchantName, originalMerchant);
      expect(original.amount, originalAmount);
      expect(original.type, originalType);
      expect(original.category, originalCategory);
      expect(original.notes, originalNotes);
      expect(original.toJson(), originalJson);
    });
  });
}
