import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tests.test_connection import test_mongodb_connection

if __name__ == "__main__":
    test_mongodb_connection()
