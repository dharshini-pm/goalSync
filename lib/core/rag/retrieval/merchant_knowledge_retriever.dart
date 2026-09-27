import '../data/merchant_knowledge_seed.dart';
import '../models/merchant_knowledge.dart';

/// Deterministic, staged knowledge retriever for merchants and categories.
///
/// Stages:
/// - Stage 1: Exact normalized merchant match (Confidence: EXACT)
/// - Stage 2: Alias match (Confidence: ALIAS)
/// - Stage 3: Distinctive token similarity (Confidence: SIMILAR)
/// - Fallback: No match (Confidence: NONE)
///
/// Guarantees:
/// - Never invents merchants.
/// - Never forces an unknown merchant into a category.
class MerchantKnowledgeRetriever {
  final List<MerchantKnowledge> _knowledgeBase;

  // Generic words that must not trigger a false positive match on their own
  static const Set<String> _genericStopwords = {
    'pvt',
    'ltd',
    'limited',
    'corp',
    'inc',
    'store',
    'shop',
    'retail',
    'services',
    'solutions',
    'enterprise',
    'enterprises',
    'india',
    'order',
    'online',
    'payment',
    'bill',
    'for',
    'and',
    'the',
    'at',
    'in',
    'to',
    'of',
    'co',
    'care',
  };

  const MerchantKnowledgeRetriever({
    List<MerchantKnowledge>? knowledgeBase,
  }) : _knowledgeBase = knowledgeBase ?? MerchantKnowledgeSeed.seedMerchants;

  /// Retrieves merchant knowledge for a given query string.
  ///
  /// Returns [MerchantRetrievalResult.noMatch] if no reliable match is found.
  MerchantRetrievalResult retrieve(String rawMerchant) {
    final trimmed = rawMerchant.trim();
    if (trimmed.isEmpty) {
      return const MerchantRetrievalResult.noMatch();
    }

    final lowerQuery = trimmed.toLowerCase();
    // Normalize punctuation/delimiters like *, -, _, ., / to spaces for token matching
    final cleanAlphanumeric = lowerQuery.replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();

    // ==========================================
    // Stage 1: Exact Normalized Merchant Match
    // ==========================================
    for (final entry in _knowledgeBase) {
      final canonicalLower = entry.merchantName.trim().toLowerCase();
      if (lowerQuery == canonicalLower ||
          cleanAlphanumeric == canonicalLower.replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim()) {
        return MerchantRetrievalResult(
          matched: true,
          merchantKnowledge: entry,
          confidence: RetrievalConfidence.exact,
          matchedTerm: entry.merchantName,
        );
      }
    }

    // ==========================================
    // Stage 2: Alias Match
    // ==========================================
    for (final entry in _knowledgeBase) {
      for (final alias in entry.aliases) {
        final aliasLower = alias.trim().toLowerCase();
        final cleanAlias = aliasLower.replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();

        // Exact match against alias
        if (lowerQuery == aliasLower || cleanAlphanumeric == cleanAlias) {
          return MerchantRetrievalResult(
            matched: true,
            merchantKnowledge: entry,
            confidence: RetrievalConfidence.alias,
            matchedTerm: alias,
          );
        }

        // Prefix match of alias (e.g. "SWIGGY*ORDER123" starts with "swiggy*order")
        if (lowerQuery.startsWith(aliasLower) ||
            cleanAlphanumeric.startsWith(cleanAlias)) {
          return MerchantRetrievalResult(
            matched: true,
            merchantKnowledge: entry,
            confidence: RetrievalConfidence.alias,
            matchedTerm: alias,
          );
        }
      }
    }

    // ==========================================
    // Stage 3: Token / Keyword Similarity
    // ==========================================
    final queryTokens = cleanAlphanumeric
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_genericStopwords.contains(t))
        .toList();

    if (queryTokens.isNotEmpty) {
      // 3A. Prioritize exact token match with canonical merchant name
      for (final entry in _knowledgeBase) {
        final canonicalLower = entry.merchantName.toLowerCase();
        for (final token in queryTokens) {
          if (token == canonicalLower && token.length >= 3) {
            return MerchantRetrievalResult(
              matched: true,
              merchantKnowledge: entry,
              confidence: RetrievalConfidence.similar,
              matchedTerm: entry.merchantName,
            );
          }
        }
      }

      // 3B. Check if query contains unique distinctive keywords
      // Exclude shared category words like food, shopping, delivery from triggering single merchant match
      const commonWords = {'food', 'shopping', 'transport', 'entertainment', 'utilities', 'delivery', 'restaurant', 'store', 'market', 'streaming'};
      for (final entry in _knowledgeBase) {
        for (final keyword in entry.keywords) {
          final kwLower = keyword.toLowerCase();
          if (_genericStopwords.contains(kwLower) || commonWords.contains(kwLower)) {
            continue;
          }

          for (final token in queryTokens) {
            if (token == kwLower && token.length >= 4) {
              return MerchantRetrievalResult(
                matched: true,
                merchantKnowledge: entry,
                confidence: RetrievalConfidence.similar,
                matchedTerm: keyword,
              );
            }
          }
        }
      }
    }

    // If no match across all stages, return NO MATCH (Unknown remains unknown)
    return const MerchantRetrievalResult.noMatch();
  }
}
