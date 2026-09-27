from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field, ConfigDict

class TransactionBase(BaseModel):
    amount: float = Field(..., gt=0.0)
    type: Literal["debit", "credit"]
    merchantName: str = Field(..., min_length=1, max_length=120)
    category: str = Field(..., min_length=1, max_length=60)
    dateTime: datetime
    paymentMethod: str = Field(..., min_length=1, max_length=30)
    notes: Optional[str] = Field(None, max_length=500)

class TransactionCreate(TransactionBase):
    pass

class TransactionUpdate(BaseModel):
    amount: Optional[float] = Field(None, gt=0.0)
    type: Optional[Literal["debit", "credit"]] = None
    merchantName: Optional[str] = Field(None, min_length=1, max_length=120)
    category: Optional[str] = Field(None, min_length=1, max_length=60)
    dateTime: Optional[datetime] = None
    paymentMethod: Optional[str] = Field(None, min_length=1, max_length=30)
    notes: Optional[str] = Field(None, max_length=500)

class TransactionResponse(TransactionBase):
    id: str = Field(..., alias="_id")
    userId: str
    createdAt: datetime
    updatedAt: datetime

    model_config = ConfigDict(populate_by_name=True)
