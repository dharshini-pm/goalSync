import certifi
from pymongo import MongoClient
from pymongo.database import Database
from pymongo.collection import Collection
from app.config import settings

_client: MongoClient | None = None

def get_client() -> MongoClient:
    """
    Returns a PyMongo MongoClient instance.
    Lazy initialization prevents blocking at module import time.
    """
    global _client
    if _client is None:
        _client = MongoClient(
            settings.MONGODB_URI,
            tlsCAFile=certifi.where(),
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=5000,
            socketTimeoutMS=5000
        )
    return _client

def get_database() -> Database:
    """Returns the GoalSync database handle."""
    return get_client()[settings.DATABASE_NAME]

def get_collection(collection_name: str) -> Collection:
    """Returns a specific collection handle from the GoalSync database."""
    return get_database()[collection_name]

def init_indexes():
    """
    Initializes unique and lookup indexes on MongoDB Atlas collections.
    """
    db = get_database()
    
    # 1. users collection indexes
    db.users.create_index("email", unique=True, name="idx_users_email_unique")
    db.users.create_index("phone", unique=True, name="idx_users_phone_unique")
    
    # 2. financial_profiles collection indexes (1-to-1 relationship with user)
    db.financial_profiles.create_index("userId", unique=True, name="idx_financial_profiles_userId_unique")
    
    # 3. goals collection indexes
    db.goals.create_index("userId", name="idx_goals_userId")
    
    # 4. transactions collection indexes
    db.transactions.create_index("userId", name="idx_transactions_userId")
    db.transactions.create_index(
        [("userId", 1), ("eventId", 1)],
        unique=True,
        sparse=True,
        name="idx_transactions_userId_eventId_unique"
    )
    db.transactions.create_index(
        [("userId", 1), ("fingerprint", 1)],
        name="idx_transactions_userId_fingerprint"
    )

    # 5. transaction_processing_records collection indexes (idempotency & agent execution history)
    db.transaction_processing_records.create_index(
        [("userId", 1), ("eventId", 1)],
        unique=True,
        name="idx_proc_userId_eventId_unique"
    )
    db.transaction_processing_records.create_index(
        [("userId", 1), ("fingerprint", 1)],
        name="idx_proc_userId_fingerprint"
    )
