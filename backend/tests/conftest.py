import pytest
import mongomock
from unittest.mock import patch

@pytest.fixture(autouse=True)
def mock_mongo_database():
    """
    Automated in-memory MongoMock fixture for pytest execution.
    Ensures unit & integration tests run instantly without external network dependency.
    """
    mock_client = mongomock.MongoClient()
    mock_db = mock_client["goalsync"]
    
    def get_mock_coll(name: str):
        return mock_db[name]
        
    with patch("app.database.get_client", return_value=mock_client), \
         patch("app.database.get_database", return_value=mock_db), \
         patch("app.database.get_collection", side_effect=get_mock_coll), \
         patch("app.dependencies.get_collection", side_effect=get_mock_coll), \
         patch("app.routes.auth.get_collection", side_effect=get_mock_coll), \
         patch("app.routes.financial_profiles.get_collection", side_effect=get_mock_coll), \
         patch("app.routes.goals.get_collection", side_effect=get_mock_coll), \
         patch("app.routes.transactions.get_collection", side_effect=get_mock_coll):
        yield mock_db
