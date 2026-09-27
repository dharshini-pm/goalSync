import 'package:flutter_test/flutter_test.dart';
import 'package:goalsync/core/intelligence/models/transaction_intelligence.dart';
import 'package:goalsync/core/rag/rag.dart';

void main() {
  group('MerchantKnowledgeRetriever Foundation Tests', () {
    late MerchantKnowledgeRetriever retriever;
    late MerchantKnowledgeService service;

    setUp(() {
      retriever = const MerchantKnowledgeRetriever();
      service = MerchantKnowledgeService(retriever: retriever);
    });

    // 1. Exact Swiggy match
    test('1. Exact Swiggy match returns Swiggy with Food category and EXACT confidence', () {
      final result = retriever.retrieve('Swiggy');

      expect(result.matched, isTrue);
      expect(result.confidence, RetrievalConfidence.exact);
      expect(result.confidence.isExact, isTrue);
      expect(result.merchantKnowledge, isNotNull);
      expect(result.merchantKnowledge!.merchantName, 'Swiggy');
      expect(result.merchantKnowledge!.category, InferredCategory.food);
      expect(result.matchedTerm, 'Swiggy');
    });

    // 2. Exact Amazon match
    test('2. Exact Amazon match returns Amazon with Shopping category and EXACT confidence', () {
      final result = retriever.retrieve('Amazon');

      expect(result.matched, isTrue);
      expect(result.confidence, RetrievalConfidence.exact);
      expect(result.confidence.isExact, isTrue);
      expect(result.merchantKnowledge, isNotNull);
      expect(result.merchantKnowledge!.merchantName, 'Amazon');
      expect(result.merchantKnowledge!.category, InferredCategory.shopping);
      expect(result.matchedTerm, 'Amazon');
    });

    // 3. Alias match
    test('3. Alias match correctly resolves merchant aliases with ALIAS confidence', () {
      final swiggyIn = retriever.retrieve('SWIGGY IN');
      expect(swiggyIn.matched, isTrue);
      expect(swiggyIn.confidence, RetrievalConfidence.alias);
      expect(swiggyIn.confidence.isAlias, isTrue);
      expect(swiggyIn.merchantKnowledge!.merchantName, 'Swiggy');
      expect(swiggyIn.merchantKnowledge!.category, InferredCategory.food);

      final amazonPay = retriever.retrieve('AMAZON PAY');
      expect(amazonPay.matched, isTrue);
      expect(amazonPay.confidence, RetrievalConfidence.alias);
      expect(amazonPay.confidence.isAlias, isTrue);
      expect(amazonPay.merchantKnowledge!.merchantName, 'Amazon');
      expect(amazonPay.merchantKnowledge!.category, InferredCategory.shopping);
    });

    // 4. Uber alias match
    test('4. Uber alias match resolves variations like UBER INDIA and UBER TRIP', () {
      final uberIndia = retriever.retrieve('UBER INDIA');
      expect(uberIndia.matched, isTrue);
      expect(uberIndia.confidence, RetrievalConfidence.alias);
      expect(uberIndia.merchantKnowledge!.merchantName, 'Uber');
      expect(uberIndia.merchantKnowledge!.category, InferredCategory.transport);

      final uberTrip = retriever.retrieve('UBER TRIP');
      expect(uberTrip.matched, isTrue);
      expect(uberTrip.confidence, RetrievalConfidence.alias);
      expect(uberTrip.merchantKnowledge!.merchantName, 'Uber');
      expect(uberTrip.merchantKnowledge!.category, InferredCategory.transport);
    });

    // 5. Case-insensitive matching
    test('5. Case-insensitive matching handles lower, upper, and mixed case queries', () {
      final lower = retriever.retrieve('amazon');
      expect(lower.matched, isTrue);
      expect(lower.confidence, RetrievalConfidence.exact);
      expect(lower.merchantKnowledge!.merchantName, 'Amazon');

      final mixed = retriever.retrieve('SwIgGy');
      expect(mixed.matched, isTrue);
      expect(mixed.confidence, RetrievalConfidence.exact);
      expect(mixed.merchantKnowledge!.merchantName, 'Swiggy');

      final mixedAlias = retriever.retrieve('uBeR iNdIa');
      expect(mixedAlias.matched, isTrue);
      expect(mixedAlias.confidence, RetrievalConfidence.alias);
      expect(mixedAlias.merchantKnowledge!.merchantName, 'Uber');
    });

    // 6. Normalized merchant matching
    test('6. Normalized merchant matching resolves punctuated queries like SWIGGY*ORDER123 and AMAZON.IN', () {
      final swiggyOrder = retriever.retrieve('SWIGGY*ORDER123');
      expect(swiggyOrder.matched, isTrue);
      expect(swiggyOrder.confidence, RetrievalConfidence.alias);
      expect(swiggyOrder.merchantKnowledge!.merchantName, 'Swiggy');

      final amazonIn = retriever.retrieve('AMAZON.IN');
      expect(amazonIn.matched, isTrue);
      expect(amazonIn.confidence, RetrievalConfidence.alias);
      expect(amazonIn.merchantKnowledge!.merchantName, 'Amazon');
    });

    // 7. Similar token matching
    test('7. Similar token matching identifies distinctive merchant names embedded in sentences', () {
      final query = retriever.retrieve('Subscription payment to Netflix today');
      expect(query.matched, isTrue);
      expect(query.confidence, RetrievalConfidence.similar);
      expect(query.confidence.isSimilar, isTrue);
      expect(query.merchantKnowledge!.merchantName, 'Netflix');
      expect(query.merchantKnowledge!.category, InferredCategory.entertainment);

      final zomatoOrder = retriever.retrieve('Order placed on Zomato food delivery');
      expect(zomatoOrder.matched, isTrue);
      expect(zomatoOrder.merchantKnowledge!.merchantName, 'Zomato');
      expect(zomatoOrder.merchantKnowledge!.category, InferredCategory.food);
    });

    // 8. Unknown merchant returns no match
    test('8. Unknown merchant returns no match and NONE confidence', () {
      final result1 = retriever.retrieve('ABC RETAIL PVT LTD');
      expect(result1.matched, isFalse);
      expect(result1.confidence, RetrievalConfidence.none);
      expect(result1.confidence.isNone, isTrue);
      expect(result1.merchantKnowledge, isNull);

      final result2 = retriever.retrieve('Dr. Sen Orthopedic Care Clinic');
      expect(result2.matched, isFalse);
      expect(result2.confidence, RetrievalConfidence.none);
      expect(result2.merchantKnowledge, isNull);
    });

    // 9. Unknown merchant is NOT assigned a category
    test('9. Unknown merchant is NOT assigned a category', () {
      final result = retriever.retrieve('Local Corner Kirana Store XYZ');
      expect(result.matched, isFalse);
      expect(result.merchantKnowledge, isNull);
      // Category is completely inaccessible because merchantKnowledge is null
      expect(result.merchantKnowledge?.category, isNull);
    });

    // 10. Correct confidence level
    test('10. Correct confidence levels are assigned deterministically', () {
      // EXACT
      final exactRes = retriever.retrieve('Spotify');
      expect(exactRes.confidence, RetrievalConfidence.exact);
      expect(exactRes.confidence.displayName, 'EXACT');

      // ALIAS
      final aliasRes = retriever.retrieve('SPOTIFY INDIA');
      expect(aliasRes.confidence, RetrievalConfidence.alias);
      expect(aliasRes.confidence.displayName, 'ALIAS');

      // SIMILAR
      final similarRes = retriever.retrieve('Recurring fee for Spotify music');
      expect(similarRes.confidence, RetrievalConfidence.similar);
      expect(similarRes.confidence.displayName, 'SIMILAR');

      // NONE
      final noneRes = retriever.retrieve('Completely Unregistered Unknown Entity');
      expect(noneRes.confidence, RetrievalConfidence.none);
      expect(noneRes.confidence.displayName, 'NONE');
    });

    // 11. Multiple aliases
    test('11. Multiple aliases across merchant catalog resolve to their canonical merchant', () {
      const amazonAliases = [
        'AMAZON',
        'AMAZON.IN',
        'AMAZON PAY',
        'AMAZON RETAIL',
      ];

      for (final alias in amazonAliases) {
        final res = retriever.retrieve(alias);
        expect(res.matched, isTrue);
        expect(res.merchantKnowledge!.merchantName, 'Amazon');
      }

      const airtelAliases = [
        'AIRTEL',
        'AIRTEL PREPAID',
        'AIRTEL BILL',
      ];

      for (final alias in airtelAliases) {
        final res = retriever.retrieve(alias);
        expect(res.matched, isTrue);
        expect(res.merchantKnowledge!.merchantName, 'Airtel');
        expect(res.merchantKnowledge!.category, InferredCategory.utilities);
      }
    });

    // 12. Empty merchant input
    test('12. Empty and whitespace-only merchant input returns safe no-match without crashing', () {
      final emptyResult = retriever.retrieve('');
      expect(emptyResult.matched, isFalse);
      expect(emptyResult.confidence, RetrievalConfidence.none);
      expect(emptyResult.merchantKnowledge, isNull);

      final whitespaceResult = retriever.retrieve('    ');
      expect(whitespaceResult.matched, isFalse);
      expect(whitespaceResult.confidence, RetrievalConfidence.none);
      expect(whitespaceResult.merchantKnowledge, isNull);
    });

    // 13. Whitespace normalization
    test('13. Whitespace normalization trims leading, trailing, and internal whitespace', () {
      final paddedExact = retriever.retrieve('   Swiggy   ');
      expect(paddedExact.matched, isTrue);
      expect(paddedExact.confidence, RetrievalConfidence.exact);
      expect(paddedExact.merchantKnowledge!.merchantName, 'Swiggy');

      final paddedAlias = retriever.retrieve('   UBER    INDIA   ');
      expect(paddedAlias.matched, isTrue);
      expect(paddedAlias.confidence, RetrievalConfidence.alias);
      expect(paddedAlias.merchantKnowledge!.merchantName, 'Uber');
    });

    // 14. Retriever never invents a merchant
    test('14. Retriever never invents a merchant and preserves service boundary', () {
      const unknownQuery = 'Global Enterprises Trading Limited';

      final retrieverRes = retriever.retrieve(unknownQuery);
      expect(retrieverRes.matched, isFalse);
      expect(retrieverRes.merchantKnowledge, isNull);
      expect(retrieverRes.matchedTerm, isNull);

      final serviceRes = service.resolveMerchant(unknownQuery);
      expect(serviceRes.matched, isFalse);
      expect(serviceRes.merchantKnowledge, isNull);
      expect(service.isKnownMerchant(unknownQuery), isFalse);

      // Verify known merchant through service
      final knownServiceRes = service.resolveMerchant('Swiggy');
      expect(knownServiceRes.matched, isTrue);
      expect(service.isKnownMerchant('Swiggy'), isTrue);
    });
  });
}
