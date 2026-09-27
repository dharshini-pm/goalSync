import 'dart:convert';
import '../../intelligence/models/transaction_intelligence.dart';

/// Deterministic confidence levels for merchant knowledge retrieval.
enum RetrievalConfidence {
  exact,
  alias,
  similar,
  none;

  bool get isExact => this == RetrievalConfidence.exact;
  bool get isAlias => this == RetrievalConfidence.alias;
  bool get isSimilar => this == RetrievalConfidence.similar;
  bool get isNone => this == RetrievalConfidence.none;

  String get displayName {
    switch (this) {
      case RetrievalConfidence.exact:
        return 'EXACT';
      case RetrievalConfidence.alias:
        return 'ALIAS';
      case RetrievalConfidence.similar:
        return 'SIMILAR';
      case RetrievalConfidence.none:
        return 'NONE';
    }
  }

  @override
  String toString() => displayName;
}

/// Represents curated knowledge about a commercial merchant and its business category.
class MerchantKnowledge {
  final String merchantName;
  final List<String> aliases;
  final InferredCategory category;
  final String description;
  final List<String> keywords;

  const MerchantKnowledge({
    required this.merchantName,
    this.aliases = const [],
    required this.category,
    this.description = '',
    this.keywords = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'merchantName': merchantName,
      'aliases': aliases,
      'category': category.displayName,
      'description': description,
      'keywords': keywords,
    };
  }

  factory MerchantKnowledge.fromMap(Map<String, dynamic> map) {
    return MerchantKnowledge(
      merchantName: map['merchantName'] as String? ?? '',
      aliases: (map['aliases'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      category: InferredCategory.fromString(map['category'] as String?),
      description: map['description'] as String? ?? '',
      keywords: (map['keywords'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory MerchantKnowledge.fromJson(String source) =>
      MerchantKnowledge.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'MerchantKnowledge(merchant: $merchantName, category: ${category.displayName}, aliases: ${aliases.length})';
}

/// Result returned from knowledge retrieval for a merchant query string.
class MerchantRetrievalResult {
  final bool matched;
  final MerchantKnowledge? merchantKnowledge;
  final RetrievalConfidence confidence;
  final String? matchedTerm;

  const MerchantRetrievalResult({
    required this.matched,
    this.merchantKnowledge,
    required this.confidence,
    this.matchedTerm,
  });

  const MerchantRetrievalResult.noMatch()
      : matched = false,
        merchantKnowledge = null,
        confidence = RetrievalConfidence.none,
        matchedTerm = null;

  String? get matchedAlias => matchedTerm;

  Map<String, dynamic> toMap() {
    return {
      'matched': matched,
      'merchantKnowledge': merchantKnowledge?.toMap(),
      'confidence': confidence.displayName,
      'matchedTerm': matchedTerm,
      'matchedAlias': matchedAlias,
    };
  }

  factory MerchantRetrievalResult.fromMap(Map<String, dynamic> map) {
    final km = map['merchantKnowledge'] as Map<String, dynamic>?;
    final confStr = map['confidence'] as String? ?? 'NONE';
    final conf = RetrievalConfidence.values.firstWhere(
      (c) =>
          c.name.toLowerCase() == confStr.toLowerCase() ||
          c.displayName.toLowerCase() == confStr.toLowerCase(),
      orElse: () => RetrievalConfidence.none,
    );

    return MerchantRetrievalResult(
      matched: map['matched'] as bool? ?? false,
      merchantKnowledge: km != null ? MerchantKnowledge.fromMap(km) : null,
      confidence: conf,
      matchedTerm:
          map['matchedTerm'] as String? ?? map['matchedAlias'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory MerchantRetrievalResult.fromJson(String source) =>
      MerchantRetrievalResult.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'MerchantRetrievalResult(matched: $matched, merchant: ${merchantKnowledge?.merchantName}, confidence: ${confidence.displayName}, matchedTerm: $matchedTerm)';
  }
}
