"""Tests for GoalSync Semantic Vector Retrieval Layer and Hybrid Resolution."""

import copy
import numpy as np
import pytest

from app.rag.models import (
    MerchantKnowledgeDocument,
    MerchantSearchResult,
    MerchantResolutionResult,
    RetrievalConfidence,
)
from app.rag.knowledge import (
    SEED_MERCHANT_DOCUMENTS,
    get_seed_knowledge_documents,
)
from app.rag.embeddings import (
    EmbeddingGenerator,
    EMBEDDING_DIMENSION,
    DEFAULT_MODEL_NAME,
)
from app.rag.vector_store import FaissVectorStore
from app.rag.retriever import (
    MerchantSemanticRetriever,
    DEFAULT_SEMANTIC_THRESHOLD,
)
from app.rag.service import MerchantHybridResolutionService


@pytest.fixture(scope="module")
def embedding_generator():
    """Initializes the embedding generator once for testing."""
    return EmbeddingGenerator()


@pytest.fixture(scope="module")
def seed_documents():
    """Returns fresh seed documents."""
    return get_seed_knowledge_documents()


@pytest.fixture(scope="module")
def vector_store(embedding_generator, seed_documents):
    """Builds and returns a populated FAISS vector store."""
    embeddings = embedding_generator.encode_documents(seed_documents)
    store = FaissVectorStore(dimension=embedding_generator.dimension)
    store.build_index(seed_documents, embeddings)
    return store


@pytest.fixture(scope="module")
def semantic_retriever(vector_store, embedding_generator):
    """Initializes semantic retriever."""
    return MerchantSemanticRetriever(
        vector_store=vector_store,
        embedding_generator=embedding_generator,
        threshold=DEFAULT_SEMANTIC_THRESHOLD,
    )


@pytest.fixture(scope="module")
def hybrid_service(semantic_retriever, seed_documents):
    """Initializes hybrid resolution service."""
    return MerchantHybridResolutionService(
        retriever=semantic_retriever,
        documents=seed_documents,
        threshold=DEFAULT_SEMANTIC_THRESHOLD,
    )


# ---------------------------------------------------------------------------
# Test Cases (1 to 16)
# ---------------------------------------------------------------------------

def test_1_embedding_model_initializes(embedding_generator):
    """Test 1: Embedding model initializes and reports correct dimension."""
    assert embedding_generator is not None
    assert embedding_generator.dimension == EMBEDDING_DIMENSION
    assert embedding_generator.dimension == 384


def test_2_knowledge_documents_generate_embeddings(embedding_generator, seed_documents):
    """Test 2: Knowledge documents generate embeddings properly."""
    embeddings = embedding_generator.encode_documents(seed_documents)
    assert isinstance(embeddings, np.ndarray)
    assert embeddings.shape[0] == len(seed_documents)
    assert embeddings.shape[1] == EMBEDDING_DIMENSION


def test_3_embedding_dimensions_are_consistent(embedding_generator):
    """Test 3: Embedding dimensions are consistent across single and multi-text encodings."""
    q_vec = embedding_generator.encode_text("Swiggy food order")
    docs_vec = embedding_generator.encode_texts(["Uber trip", "Amazon purchase", "Netflix"])

    assert q_vec.shape == (EMBEDDING_DIMENSION,)
    assert docs_vec.shape == (3, EMBEDDING_DIMENSION)
    assert q_vec.dtype == np.float32
    assert docs_vec.dtype == np.float32


def test_4_embeddings_are_normalized(embedding_generator, seed_documents):
    """Test 4: Embeddings are L2 normalized (unit length)."""
    embeddings = embedding_generator.encode_documents(seed_documents)
    norms = np.linalg.norm(embeddings, axis=1)

    # Each vector norm should be approximately 1.0 within float precision
    for norm in norms:
        assert pytest.approx(norm, rel=1e-4) == 1.0

    single_vec = embedding_generator.encode_text("random query")
    single_norm = np.linalg.norm(single_vec)
    assert pytest.approx(single_norm, rel=1e-4) == 1.0


def test_5_faiss_index_builds_successfully(vector_store, seed_documents):
    """Test 5: FAISS index builds successfully with expected count and state."""
    assert vector_store.is_built is True
    assert vector_store.count == len(seed_documents)
    assert vector_store.count == 11


def test_6_exact_semantic_query_retrieves_expected_merchant(semantic_retriever):
    """Test 6: Exact semantic query retrieves expected merchant with high similarity."""
    results = semantic_retriever.retrieve("Swiggy", top_k=1)
    assert len(results) == 1
    assert results[0].merchant_name == "Swiggy"
    assert results[0].category == "Food"
    assert results[0].similarity_score >= DEFAULT_SEMANTIC_THRESHOLD


def test_7_food_delivery_retrieves_food_related_merchant(semantic_retriever):
    """Test 7: 'food delivery' retrieves food-related merchant (Swiggy or Zomato)."""
    results = semantic_retriever.retrieve("food delivery", top_k=2)
    assert len(results) >= 1
    top_merchant = results[0]
    assert top_merchant.category == "Food"
    assert top_merchant.merchant_name in ["Swiggy", "Zomato"]
    assert top_merchant.similarity_score >= DEFAULT_SEMANTIC_THRESHOLD


def test_8_online_shopping_retrieves_shopping_related_merchant(semantic_retriever):
    """Test 8: 'online shopping' retrieves shopping-related merchant (Amazon or Flipkart)."""
    results = semantic_retriever.retrieve("online shopping", top_k=2)
    assert len(results) >= 1
    top_merchant = results[0]
    assert top_merchant.category == "Shopping"
    assert top_merchant.merchant_name in ["Amazon", "Flipkart"]
    assert top_merchant.similarity_score >= DEFAULT_SEMANTIC_THRESHOLD


def test_9_transport_query_retrieves_uber_or_ola(semantic_retriever):
    """Test 9: Transport query retrieves Uber or Ola."""
    queries = ["city taxi cab booking", "book an auto ride", "rideshare commute"]
    for q in queries:
        results = semantic_retriever.retrieve(q, top_k=2)
        assert len(results) >= 1
        top_match = results[0]
        assert top_match.category == "Transport"
        assert top_match.merchant_name in ["Uber", "Ola"]


def test_10_entertainment_query_retrieves_netflix_or_spotify(semantic_retriever):
    """Test 10: Entertainment query retrieves Netflix or Spotify."""
    # Video / movies
    movie_results = semantic_retriever.retrieve("watch movies and streaming tv series", top_k=2)
    assert len(movie_results) >= 1
    assert movie_results[0].category == "Entertainment"
    assert movie_results[0].merchant_name in ["Netflix", "Spotify"]

    # Music / audio
    music_results = semantic_retriever.retrieve("music podcast playlist streaming", top_k=2)
    assert len(music_results) >= 1
    assert music_results[0].category == "Entertainment"
    assert music_results[0].merchant_name == "Spotify"


def test_11_top_k_results_are_returned(semantic_retriever):
    """Test 11: Top-K results are returned respecting requested k limit."""
    results_1 = semantic_retriever.retrieve("monthly utilities payment", top_k=1)
    results_3 = semantic_retriever.retrieve("monthly utilities payment", top_k=3)
    results_5 = semantic_retriever.retrieve("monthly utilities payment", top_k=5)

    assert len(results_1) == 1
    assert len(results_3) == 3
    assert len(results_5) == 5

    # Check order is descending by similarity score
    scores = [r.similarity_score for r in results_5]
    assert scores == sorted(scores, reverse=True)


def test_12_similarity_scores_are_returned(semantic_retriever):
    """Test 12: Similarity scores are valid floating point numbers in range [-1.0, 1.0]."""
    results = semantic_retriever.retrieve("broadband internet recharge", top_k=3)
    assert len(results) > 0
    for r in results:
        assert isinstance(r.similarity_score, float)
        assert -1.0 <= r.similarity_score <= 1.0
        assert r.description != ""
        assert r.merchant_name != ""


def test_13_low_confidence_query_returns_no_reliable_match(hybrid_service, semantic_retriever):
    """Test 13: Low-confidence queries below threshold return NO_RELIABLE_MATCH."""
    low_confidence_query = "quantum mechanical physics laboratory equipment"

    # Direct retriever threshold check
    best_semantic = semantic_retriever.retrieve_best_match(low_confidence_query)
    assert best_semantic is None

    # Service resolution check
    resolution = hybrid_service.resolve(low_confidence_query)
    assert resolution.matched is False
    assert resolution.merchant_name is None
    assert resolution.category is None
    assert resolution.confidence == RetrievalConfidence.NONE
    assert resolution.status == "NO_RELIABLE_MATCH"


def test_14_deterministic_retrieval_has_priority_over_semantic_retrieval(hybrid_service):
    """Test 14: Deterministic exact & alias matching takes precedence over semantic vector retrieval."""
    # Exact match on Swiggy
    res_exact = hybrid_service.resolve("Swiggy")
    assert res_exact.matched is True
    assert res_exact.merchant_name == "Swiggy"
    assert res_exact.category == "Food"
    assert res_exact.confidence == RetrievalConfidence.EXACT
    assert res_exact.similarity_score == 1.0

    # Alias match on AMZN
    res_alias = hybrid_service.resolve("AMZN")
    assert res_alias.matched is True
    assert res_alias.merchant_name == "Amazon"
    assert res_alias.category == "Shopping"
    assert res_alias.confidence == RetrievalConfidence.ALIAS
    assert res_alias.similarity_score >= 0.90

    # Semantic match (no exact/alias match exists for this phrase)
    res_semantic = hybrid_service.resolve("order food delivery")
    assert res_semantic.matched is True
    assert res_semantic.merchant_name in ["Swiggy", "Zomato"]
    assert res_semantic.category == "Food"
    assert res_semantic.confidence == RetrievalConfidence.SEMANTIC
    assert res_semantic.similarity_score >= DEFAULT_SEMANTIC_THRESHOLD


def test_15_unknown_merchant_is_never_invented(hybrid_service):
    """Test 15: Unknown, ambiguous or noise inputs never invent hallucinated merchants."""
    unknown_inputs = [
        "Unregistered local garage 9876",
        "XYZ Random Corporate LLC 1999",
        "Medical dental clinic treatment",
        "Agricultural fertilizer distributor",
        "1234567890",
        "",
        "   ",
    ]

    for inp in unknown_inputs:
        result = hybrid_service.resolve(inp)
        assert result.matched is False, f"Failed for input: {inp}"
        assert result.merchant_name is None
        assert result.category is None
        assert result.status == "NO_RELIABLE_MATCH"
        assert result.confidence == RetrievalConfidence.NONE


def test_16_original_knowledge_documents_remain_unchanged():
    """Test 16: Original knowledge documents remain immutable and unmodified during operations."""
    original_docs = get_seed_knowledge_documents()
    snapshot = copy.deepcopy(original_docs)

    # Perform embedding, vector store building and hybrid resolution
    generator = EmbeddingGenerator()
    embeddings = generator.encode_documents(original_docs)
    store = FaissVectorStore(dimension=generator.dimension)
    store.build_index(original_docs, embeddings)
    retriever = MerchantSemanticRetriever(vector_store=store, embedding_generator=generator)
    service = MerchantHybridResolutionService(retriever=retriever, documents=original_docs)

    service.resolve("food delivery")
    service.resolve("Netflix")
    service.resolve("Random unknown entity")

    # Verify original_docs matches snapshot exactly
    assert len(original_docs) == len(snapshot)
    for orig, snap in zip(original_docs, snapshot):
        assert orig.merchant_name == snap.merchant_name
        assert orig.aliases == snap.aliases
        assert orig.category == snap.category
        assert orig.description == snap.description
        assert orig.keywords == snap.keywords

    # Also verify global constant SEED_MERCHANT_DOCUMENTS remains identical
    assert len(SEED_MERCHANT_DOCUMENTS) == 11
