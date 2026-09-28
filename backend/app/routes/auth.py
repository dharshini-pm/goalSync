from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from app.database import get_collection
from app.schemas.auth import RegisterSchema, LoginSchema, TokenResponse
from app.schemas.user import UserResponse
from app.services.auth_service import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register_user(payload: RegisterSchema):
    users_collection = get_collection("users")
    
    clean_email = payload.email.lower().strip()
    clean_phone = payload.phone.strip()
    
    # Check existing email
    if users_collection.find_one({"email": clean_email}):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email address already exists."
        )
        
    # Check existing phone
    if users_collection.find_one({"phone": clean_phone}):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this phone number already exists."
        )
        
    hashed_pwd = hash_password(payload.password)
    now = datetime.now(timezone.utc)
    
    user_doc = {
        "fullName": payload.fullName.strip(),
        "phone": clean_phone,
        "email": clean_email,
        "passwordHash": hashed_pwd,
        "createdAt": now,
        "updatedAt": now
    }
    
    result = users_collection.insert_one(user_doc)
    user_id_str = str(result.inserted_id)
    
    token = create_access_token({"sub": user_id_str, "email": clean_email})
    
    user_response = UserResponse(
        _id=user_id_str,
        fullName=user_doc["fullName"],
        phone=user_doc["phone"],
        email=user_doc["email"],
        createdAt=user_doc["createdAt"],
        updatedAt=user_doc["updatedAt"]
    )
    
    return TokenResponse(access_token=token, token_type="bearer", user=user_response)

@router.post("/login", response_model=TokenResponse)
def login_user(payload: LoginSchema):
    users_collection = get_collection("users")
    ident = payload.identifier.strip()
    
    # Try finding by email (lowercased) or phone
    user_doc = users_collection.find_one({
        "$or": [
            {"email": ident.lower()},
            {"phone": ident}
        ]
    })
    
    if not user_doc or not verify_password(payload.password, user_doc["passwordHash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please check your email/phone and password."
        )
        
    user_id_str = str(user_doc["_id"])
    token = create_access_token({"sub": user_id_str, "email": user_doc["email"]})
    
    user_response = UserResponse(
        _id=user_id_str,
        fullName=user_doc["fullName"],
        phone=user_doc["phone"],
        email=user_doc["email"],
        createdAt=user_doc["createdAt"],
        updatedAt=user_doc["updatedAt"]
    )
    
    return TokenResponse(access_token=token, token_type="bearer", user=user_response)
