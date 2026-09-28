from sqlalchemy import Column, String, Integer, Float, DateTime
from app.models.base import Base, generate_id, utc_now


class FinancialProfile(Base):
    __tablename__ = "financial_profiles"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    userId = Column(String(36), unique=True, index=True, nullable=False)
    age = Column(Integer, nullable=False)
    occupation = Column(String(255), nullable=False)
    dependents = Column(Integer, default=0, nullable=False)
    monthlyIncome = Column(Float, nullable=False)
    incomeType = Column(String(100), default="Salary", nullable=False)
    additionalIncome = Column(Float, default=0.0, nullable=False)
    currentSavings = Column(Float, nullable=False)
    fixedExpenses = Column(Float, nullable=False)
    variableExpenses = Column(Float, nullable=False)
    monthlyEMI = Column(Float, default=0.0, nullable=False)
    activeLoans = Column(Integer, default=0, nullable=False)
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
            "age": self.age,
            "occupation": self.occupation,
            "dependents": self.dependents,
            "monthlyIncome": self.monthlyIncome,
            "incomeType": self.incomeType,
            "additionalIncome": self.additionalIncome,
            "currentSavings": self.currentSavings,
            "fixedExpenses": self.fixedExpenses,
            "variableExpenses": self.variableExpenses,
            "monthlyEMI": self.monthlyEMI,
            "activeLoans": self.activeLoans,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
