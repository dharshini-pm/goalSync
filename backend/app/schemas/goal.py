from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict

class GoalBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    category: str = Field(..., min_length=1, max_length=50)
    targetAmount: float = Field(..., gt=0.0)
    currentAmount: float = Field(0.0, ge=0.0)
    targetDate: datetime
    priority: str = Field(..., min_length=1, max_length=20)

class GoalCreate(GoalBase):
    pass

class GoalUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    category: Optional[str] = Field(None, min_length=1, max_length=50)
    targetAmount: Optional[float] = Field(None, gt=0.0)
    currentAmount: Optional[float] = Field(None, ge=0.0)
    targetDate: Optional[datetime] = None
    priority: Optional[str] = Field(None, min_length=1, max_length=20)

class GoalResponse(GoalBase):
    id: str = Field(..., alias="_id")
    userId: str
    createdAt: datetime
    updatedAt: datetime

    model_config = ConfigDict(populate_by_name=True)
