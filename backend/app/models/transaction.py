from sqlalchemy import Column, String, Float, DateTime, Text, Index
from app.models.base import Base, generate_id, utc_now


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    userId = Column(String(36), index=True, nullable=False)
    amount = Column(Float, nullable=False)
    type = Column(String(10), nullable=False)
    merchantName = Column(String(120), nullable=False)
    category = Column(String(60), nullable=False)
    dateTime = Column(DateTime, nullable=False)
    paymentMethod = Column(String(30), nullable=False)
    notes = Column(Text, nullable=True)
    source = Column(String(50), nullable=True)
    eventId = Column(String(100), nullable=True)
    fingerprint = Column(String(100), nullable=True)
    confidence = Column(String(50), nullable=True)
    createdAt = Column(DateTime, default=utc_now, nullable=False)
    updatedAt = Column(DateTime, default=utc_now, onupdate=utc_now, nullable=False)

    __table_args__ = (
        Index(
            "idx_transactions_userId_eventId",
            "userId",
            "eventId",
            unique=True,
            sqlite_where=Column("eventId").is_not(None),
        ),
        Index("idx_transactions_userId_fingerprint", "userId", "fingerprint"),
    )

    @property
    def _id(self):
        return self.id

    @_id.setter
    def _id(self, val):
        self.id = val

    def to_dict(self):
        return {
            "_id": str(self.id),
            "userId": str(self.userId),
            "amount": self.amount,
            "type": self.type,
            "merchantName": self.merchantName,
            "category": self.category,
            "dateTime": self.dateTime,
            "paymentMethod": self.paymentMethod,
            "notes": self.notes,
            "source": self.source,
            "eventId": self.eventId,
            "fingerprint": self.fingerprint,
            "confidence": self.confidence,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
