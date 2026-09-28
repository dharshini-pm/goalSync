from sqlalchemy import Column, String, DateTime
from app.models.base import Base, generate_id, utc_now


class User(Base):
    __tablename__ = "users"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    fullName = Column(String(255), nullable=False)
    phone = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    passwordHash = Column(String(255), nullable=False)
    deviceId = Column(String(255), index=True, nullable=True)
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
            "fullName": self.fullName,
            "phone": self.phone,
            "email": self.email,
            "passwordHash": self.passwordHash,
            "deviceId": self.deviceId,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
