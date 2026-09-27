import '../models/merchant_knowledge.dart';
import '../retrieval/merchant_knowledge_retriever.dart';

/// Service facade for merchant knowledge retrieval in GoalSync.
///
/// Designed as a clean boundary for future AI agents to query merchant and category knowledge
/// without directly dealing with low-level retrieval mechanics.
class MerchantKnowledgeService {
  final MerchantKnowledgeRetriever _retriever;

  const MerchantKnowledgeService({
    MerchantKnowledgeRetriever retriever = const MerchantKnowledgeRetriever(),
  }) : _retriever = retriever;

  /// Resolves merchant information from knowledge base.
  ///
  /// Returns a [MerchantRetrievalResult] indicating whether a match was found,
  /// the associated [MerchantKnowledge], and the deterministic [RetrievalConfidence].
  MerchantRetrievalResult resolveMerchant(String merchantName) {
    return _retriever.retrieve(merchantName);
  }

  /// Convenience helper to check if a merchant is known in the knowledge base.
  bool isKnownMerchant(String merchantName) {
    return resolveMerchant(merchantName).matched;
  }
}
