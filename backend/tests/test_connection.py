import sys
import os

# Ensure backend root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import get_database, get_collection, init_db


def test_sqlite_connection():
    """
    Verifies SQLite connectivity, database access, table/collection access, and ping.
    """
    try:
        init_db()
        db = get_database()
        ping_res = db.command("ping")
        assert ping_res.get("ok") == 1.0 or ping_res.get("ok") == 1

        users_coll = get_collection("users")
        coll_name = users_coll.name
        assert coll_name == "users"

        print("\nSQLite connection successful")
        print(f"Database: {db.name}")
        print(f"Collection/table access: {coll_name}")
        print("Connection test passed")
    except Exception as e:
        print(f"\nSQLite Connection Failed: {str(e)}")
        raise e


# Backward compatibility alias
test_mongodb_connection = test_sqlite_connection

if __name__ == "__main__":
    test_sqlite_connection()
