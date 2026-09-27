from pydantic import BaseModel, EmailStr, Field
from app.schemas.user import UserResponse

class RegisterSchema(BaseModel):
    fullName: str = Field(..., min_length=1, max_length=120)
    phone: str = Field(..., min_length=7, max_length=20)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=128)

class LoginSchema(BaseModel):
    identifier: str = Field(..., description="User email or phone number")
    password: str = Field(..., min_length=1)

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
