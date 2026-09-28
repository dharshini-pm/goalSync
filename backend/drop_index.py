from app.database import get_database

db = get_database()
db.transactions.drop_index("idx_transactions_userId_eventId_unique")
print("Dropped stale index.")
