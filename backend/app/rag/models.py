"""Data models for Merchant and Category RAG retrieval."""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional


class RetrievalConfidence(str, Enum):
    EXACT = "EXACT"
    ALIAS = "ALIAS"
    SEMANTIC = "SEMANTIC"
    NONE = "NONE"


@dataclass
class MerchantKnowledgeDocument:
    """Represents a curated knowledge document for a commercial merchant."""

    merchant_name: str
    aliases: List[str] = field(default_factory=list)
    category: str = "Other"
    description: str = ""
    keywords: List[str] = field(default_factory=list)

    def to_searchable_text(self) -> str:
        """Builds a rich, searchable textual representation for vector embedding."""
        aliases_str = ", ".join(self.aliases) if self.aliases else "None"
        keywords_str = ", ".join(self.keywords) if self.keywords else "None"
        return (
            f"Merchant: {self.merchant_name}\n"
            f"Aliases: {aliases_str}\n"
            f"Category: {self.category}\n"
            f"Description: {self.description}\n"
            f"Keywords: {keywords_str}"
        )


@dataclass
class MerchantSearchResult:
    """Represents an individual ranked search result from vector retrieval."""

    merchant_name: str
    category: str
    description: str
    similarity_score: float


@dataclass
class MerchantResolutionResult:
    """Represents the final outcome of hybrid merchant resolution."""

    matched: bool
    merchant_name: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    confidence: RetrievalConfidence = RetrievalConfidence.NONE
    similarity_score: float = 0.0
    matched_term: Optional[str] = None
    status: str = "NO_RELIABLE_MATCH"

    @classmethod
    def no_match(cls) -> "MerchantResolutionResult":
        return cls(
            matched=False,
            merchant_name=None,
            category=None,
            description=None,
            confidence=RetrievalConfidence.NONE,
            similarity_score=0.0,
            matched_term=None,
            status="NO_RELIABLE_MATCH",
        )
