from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.database import get_collection
from app.services.auth_service import decode_access_token

security = HTTPBearer()


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    Validates JWT bearer token, verifies user existence in SQLite database,
    and returns the authenticated user document.
    """
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
        user_id_str: str = payload.get("sub")
        if not user_id_str:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials: sub claim missing",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not isinstance(user_id_str, str) or not user_id_str.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID in token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    users_collection = get_collection("users")
    user_doc = users_collection.find_one({"_id": user_id_str.strip()})

    if not user_doc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Format _id to string for consistent downstream consumption
    user_doc["_id"] = str(user_doc["_id"])
    return user_doc
