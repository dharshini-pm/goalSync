from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

class UserResponse(BaseModel):
    id: str = Field(..., alias="_id")
    fullName: str
    phone: str
    email: str
    createdAt: datetime
    updatedAt: datetime

    model_config = ConfigDict(populate_by_name=True)
