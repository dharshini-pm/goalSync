"""Hybrid merchant resolution service combining deterministic priority with vector retrieval."""

from typing import List, Optional
from .models import (
    MerchantKnowledgeDocument,
    MerchantResolutionResult,
    RetrievalConfidence,
)
from .knowledge import get_seed_knowledge_documents
from .embeddings import EmbeddingGenerator
from .vector_store import FaissVectorStore
from .retriever import MerchantSemanticRetriever, DEFAULT_SEMANTIC_THRESHOLD


class MerchantHybridResolutionService:
    """Combines deterministic merchant/alias resolution with semantic vector retrieval.

    Precedence:
    1. Deterministic Exact Match (confidence: EXACT, score: 1.0)
    2. Deterministic Alias Match (confidence: ALIAS, score: 0.95)
    3. Semantic Vector Match (confidence: SEMANTIC, score: cosine similarity >= threshold)
    4. Unresolved / Fallback (status: NO_RELIABLE_MATCH, matched: False)
    """

    def __init__(
        self,
        retriever: MerchantSemanticRetriever,
        documents: Optional[List[MerchantKnowledgeDocument]] = None,
        threshold: float = DEFAULT_SEMANTIC_THRESHOLD,
    ):
        self.retriever = retriever
        self.documents = documents if documents is not None else get_seed_knowledge_documents()
        self.threshold = threshold

        # Build fast lookup indexes for deterministic exact & alias matching
        self._exact_map = {}
        self._alias_map = {}
        self._build_deterministic_lookups()

    def _build_deterministic_lookups(self) -> None:
        for doc in self.documents:
            # Exact key
            exact_key = doc.merchant_name.strip().upper()
            self._exact_map[exact_key] = doc

            # Aliases
            for alias in doc.aliases:
                alias_key = alias.strip().upper()
                if alias_key:
                    self._alias_map[alias_key] = doc

    def resolve(self, query: str) -> MerchantResolutionResult:
        """Resolves a merchant query according to the strict priority hierarchy.

        Deterministic matching is checked first. Only if deterministic lookup
        yields no match does the engine execute semantic vector retrieval.
        """
        clean_query = query.strip() if query else ""
        if not clean_query:
            return MerchantResolutionResult.no_match()

        query_upper = clean_query.upper()

        # Step 1: Exact deterministic match
        if query_upper in self._exact_map:
            doc = self._exact_map[query_upper]
            return MerchantResolutionResult(
                matched=True,
                merchant_name=doc.merchant_name,
                category=doc.category,
                description=doc.description,
                confidence=RetrievalConfidence.EXACT,
                similarity_score=1.0,
                matched_term=clean_query,
                status="MATCH",
            )

        # Step 2: Alias deterministic match
        if query_upper in self._alias_map:
            doc = self._alias_map[query_upper]
            return MerchantResolutionResult(
                matched=True,
                merchant_name=doc.merchant_name,
                category=doc.category,
                description=doc.description,
                confidence=RetrievalConfidence.ALIAS,
                similarity_score=0.95,
                matched_term=clean_query,
                status="MATCH",
            )

        # Also check if any known alias is contained within the query string or vice-versa
        for alias_key, doc in self._alias_map.items():
            if len(alias_key) >= 3 and (alias_key in query_upper or query_upper in alias_key):
                return MerchantResolutionResult(
                    matched=True,
                    merchant_name=doc.merchant_name,
                    category=doc.category,
                    description=doc.description,
                    confidence=RetrievalConfidence.ALIAS,
                    similarity_score=0.90,
                    matched_term=clean_query,
                    status="MATCH",
                )

        # Step 3: Semantic vector retrieval
        semantic_best = self.retriever.retrieve_best_match(clean_query, threshold=self.threshold)
        if semantic_best is not None:
            return MerchantResolutionResult(
                matched=True,
                merchant_name=semantic_best.merchant_name,
                category=semantic_best.category,
                description=semantic_best.description,
                confidence=RetrievalConfidence.SEMANTIC,
                similarity_score=semantic_best.similarity_score,
                matched_term=clean_query,
                status="MATCH",
            )

        # Step 4: Unknown / Below threshold -> Reject safely
        return MerchantResolutionResult.no_match()

    @classmethod
    def create_default(
        cls,
        embedding_generator: Optional[EmbeddingGenerator] = None,
        threshold: float = DEFAULT_SEMANTIC_THRESHOLD,
    ) -> "MerchantHybridResolutionService":
        """Factory method to instantiate a fully configured service with seed documents."""
        docs = get_seed_knowledge_documents()
        generator = embedding_generator or EmbeddingGenerator()
        embeddings = generator.encode_documents(docs)

        store = FaissVectorStore(dimension=generator.dimension)
        store.build_index(docs, embeddings)

        retriever = MerchantSemanticRetriever(
            vector_store=store,
            embedding_generator=generator,
            threshold=threshold,
        )

        return cls(retriever=retriever, documents=docs, threshold=threshold)
