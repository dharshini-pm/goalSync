import pytest
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
from app.database import set_engine, reset_engine, init_db, get_database
from app.models import Base


@pytest.fixture(autouse=True)
def sqlite_test_database():
    """
    Automated in-memory SQLite fixture for pytest execution.
    Ensures unit & integration tests run isolated, fast, and without network/disk dependencies.
    """
    test_engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    set_engine(test_engine)
    init_db(test_engine)
    db = get_database()
    yield db
    Base.metadata.drop_all(bind=test_engine)
    reset_engine()


@pytest.fixture
def mock_mongo_database(sqlite_test_database):
    """Backward compatibility fixture alias for any test expecting mock_mongo_database."""
    yield sqlite_test_database
