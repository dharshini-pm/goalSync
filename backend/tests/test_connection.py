import sys
import os

# Ensure backend root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import get_database, get_collection

def test_mongodb_connection():
    """
    Verifies MongoDB Atlas connectivity, database access, and collection access.
    """
    try:
        db = get_database()
        ping_res = db.command("ping")
        assert ping_res.get("ok") == 1.0 or ping_res.get("ok") == 1
        
        users_coll = get_collection("users")
        coll_name = users_coll.name
        assert coll_name == "users"
        
        print("\nMongoDB connection successful")
        print(f"Database: {db.name}")
        print(f"Collection access: {coll_name}")
        print("Connection test passed")
    except Exception as e:
        print(f"\nMongoDB Connection Failed: {str(e)}")
        raise e

if __name__ == "__main__":
    test_mongodb_connection()
