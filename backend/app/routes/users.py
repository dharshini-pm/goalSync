from fastapi import APIRouter, Depends
from app.dependencies import get_current_user
from app.schemas.user import UserResponse

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me", response_model=UserResponse)
def get_me(current_user: dict = Depends(get_current_user)):
    """
    Returns profile information of the currently authenticated user.
    """
    return UserResponse(
        _id=current_user["_id"],
        fullName=current_user["fullName"],
        phone=current_user["phone"],
        email=current_user["email"],
        createdAt=current_user["createdAt"],
        updatedAt=current_user["updatedAt"]
    )
