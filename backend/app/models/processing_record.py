from sqlalchemy import Column, String, DateTime, Text, JSON, Index
from app.models.base import Base, generate_id, utc_now


class TransactionProcessingRecord(Base):
    __tablename__ = "transaction_processing_records"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    userId = Column(String(36), index=True, nullable=False)
    eventId = Column(String(100), nullable=True)
    fingerprint = Column(String(100), nullable=True)
    status = Column(String(20), nullable=False)
    source = Column(String(50), nullable=True)
    transactionId = Column(String(36), nullable=True)
    completed_stages = Column(JSON, nullable=True)
    errors = Column(JSON, nullable=True)
    execution_trace = Column(JSON, nullable=True)
    error = Column(Text, nullable=True)
    transaction_result = Column(JSON, nullable=True)
    financial_state_result = Column(JSON, nullable=True)
    goal_result = Column(JSON, nullable=True)
    conflict_result = Column(JSON, nullable=True)
    scenario_result = Column(JSON, nullable=True)
    explanation_result = Column(JSON, nullable=True)
    createdAt = Column(DateTime, default=utc_now, nullable=False)
    updatedAt = Column(DateTime, default=utc_now, onupdate=utc_now, nullable=False)

    __table_args__ = (
        Index(
            "idx_proc_userId_eventId_unique",
            "userId",
            "eventId",
            unique=True,
            sqlite_where=Column("eventId").is_not(None),
        ),
        Index("idx_proc_userId_fingerprint", "userId", "fingerprint"),
        Index("idx_proc_userId_status_updatedAt", "userId", "status", "updatedAt"),
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
            "eventId": self.eventId,
            "fingerprint": self.fingerprint,
            "status": self.status,
            "source": self.source,
            "transactionId": str(self.transactionId) if self.transactionId else None,
            "completed_stages": self.completed_stages or [],
            "errors": self.errors,
            "execution_trace": self.execution_trace,
            "error": self.error,
            "transaction_result": self.transaction_result,
            "financial_state_result": self.financial_state_result,
            "goal_result": self.goal_result,
            "conflict_result": self.conflict_result,
            "scenario_result": self.scenario_result,
            "explanation_result": self.explanation_result,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
