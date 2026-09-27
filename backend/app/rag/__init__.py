"""RAG Vector Retrieval Layer for Merchant and Category Knowledge."""

from .models import (
    MerchantKnowledgeDocument,
    MerchantSearchResult,
    MerchantResolutionResult,
    RetrievalConfidence,
)
from .knowledge import SEED_MERCHANT_DOCUMENTS, get_seed_knowledge_documents
from .embeddings import EmbeddingGenerator, DEFAULT_MODEL_NAME, EMBEDDING_DIMENSION
from .vector_store import FaissVectorStore
from .retriever import MerchantSemanticRetriever, DEFAULT_SEMANTIC_THRESHOLD
from .service import MerchantHybridResolutionService

__all__ = [
    "MerchantKnowledgeDocument",
    "MerchantSearchResult",
    "MerchantResolutionResult",
    "RetrievalConfidence",
    "SEED_MERCHANT_DOCUMENTS",
    "get_seed_knowledge_documents",
    "EmbeddingGenerator",
    "DEFAULT_MODEL_NAME",
    "EMBEDDING_DIMENSION",
    "FaissVectorStore",
    "MerchantSemanticRetriever",
    "DEFAULT_SEMANTIC_THRESHOLD",
    "MerchantHybridResolutionService",
]
