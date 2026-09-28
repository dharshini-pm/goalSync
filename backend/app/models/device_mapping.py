from sqlalchemy import Column, String, DateTime
from app.models.base import Base, generate_id, utc_now


class DeviceMapping(Base):
    __tablename__ = "device_mappings"

    id = Column("_id", String(36), primary_key=True, default=generate_id)
    deviceId = Column(String(100), unique=True, index=True, nullable=False)
    userId = Column(String(36), index=True, nullable=False)
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
            "deviceId": self.deviceId,
            "userId": str(self.userId),
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
