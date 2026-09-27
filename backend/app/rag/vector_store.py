"""FAISS vector store implementation using IndexFlatIP for cosine similarity."""

from typing import List, Tuple, Optional
import numpy as np
import faiss

from .models import MerchantKnowledgeDocument


class FaissVectorStore:
    """In-memory FAISS vector index using normalized Inner Product (cosine similarity)."""

    def __init__(self, dimension: int = 384):
        self.dimension = dimension
        self._index: Optional[faiss.IndexFlatIP] = None
        self._documents: List[MerchantKnowledgeDocument] = []

    @property
    def is_built(self) -> bool:
        """Returns True if the index contains documents and is ready for queries."""
        return self._index is not None and self._index.ntotal > 0

    @property
    def count(self) -> int:
        """Returns the number of documents indexed."""
        return len(self._documents)

    def build_index(
        self,
        documents: List[MerchantKnowledgeDocument],
        embeddings: np.ndarray,
    ) -> None:
        """Builds a FAISS IndexFlatIP from knowledge documents and normalized embeddings.

        Args:
            documents: List of MerchantKnowledgeDocument items.
            embeddings: 2D numpy array of shape (N, dimension) with float32 dtype.
        """
        if len(documents) != embeddings.shape[0]:
            raise ValueError(
                f"Document count ({len(documents)}) does not match embedding count ({embeddings.shape[0]})"
            )

        if embeddings.shape[1] != self.dimension:
            raise ValueError(
                f"Embedding dimension ({embeddings.shape[1]}) does not match index dimension ({self.dimension})"
            )

        # Ensure float32 and C-contiguous
        emb_matrix = np.ascontiguousarray(embeddings, dtype=np.float32)

        index = faiss.IndexFlatIP(self.dimension)
        index.add(emb_matrix)

        self._index = index
        self._documents = list(documents)

    def search(
        self,
        query_vector: np.ndarray,
        top_k: int = 3,
    ) -> List[Tuple[MerchantKnowledgeDocument, float]]:
        """Searches the index for the most similar documents to the query vector.

        Args:
            query_vector: 1D or 2D normalized vector representing the query.
            top_k: Maximum number of results to return.

        Returns:
            List of (MerchantKnowledgeDocument, similarity_score) sorted by descending similarity.
        """
        if not self.is_built or self._index is None:
            return []

        # Prepare query array of shape (1, dimension)
        q = np.asarray(query_vector, dtype=np.float32)
        if q.ndim == 1:
            q = q.reshape(1, -1)
        q = np.ascontiguousarray(q)

        k = min(top_k, self.count)
        if k <= 0:
            return []

        distances, indices = self._index.search(q, k)

        results: List[Tuple[MerchantKnowledgeDocument, float]] = []
        for dist, idx in zip(distances[0], indices[0]):
            if idx >= 0 and idx < len(self._documents):
                results.append((self._documents[idx], float(dist)))

        return results
