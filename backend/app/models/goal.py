from sqlalchemy import Column, String, Float, DateTime
from app.models.base import Base, generate_id, utc_now


class Goal(Base):
    __tablename__ = "goals"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    userId = Column(String(36), index=True, nullable=False)
    name = Column(String(100), nullable=False)
    category = Column(String(50), nullable=False)
    targetAmount = Column(Float, nullable=False)
    currentAmount = Column(Float, default=0.0, nullable=False)
    targetDate = Column(DateTime, nullable=False)
    priority = Column(String(20), nullable=False)
    createdAt = Column(DateTime, default=utc_now, nullable=False)
    updatedAt = Column(DateTime, default=utc_now, onupdate=utc_now, nullable=False)

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
            "name": self.name,
            "category": self.category,
            "targetAmount": self.targetAmount,
            "currentAmount": self.currentAmount,
            "targetDate": self.targetDate,
            "priority": self.priority,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
