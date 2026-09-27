from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId
from app.database import get_collection
from app.dependencies import get_current_user
from app.schemas.financial_profile import (
    FinancialProfileCreate,
    FinancialProfileUpdate,
    FinancialProfileResponse
)

router = APIRouter(prefix="/financial-profile", tags=["Financial Profile"])

@router.post("", response_model=FinancialProfileResponse, status_code=status.HTTP_201_CREATED)
def create_or_update_profile(
    payload: FinancialProfileCreate,
    current_user: dict = Depends(get_current_user)
):
    coll = get_collection("financial_profiles")
    user_id_obj = ObjectId(current_user["_id"])
    now = datetime.now(timezone.utc)
    
    existing = coll.find_one({"userId": user_id_obj})
    if existing:
        # Update existing profile
        update_data = payload.model_dump()
        update_data["updatedAt"] = now
        coll.update_one({"_id": existing["_id"]}, {"$set": update_data})
        updated = coll.find_one({"_id": existing["_id"]})
        updated["_id"] = str(updated["_id"])
        updated["userId"] = str(updated["userId"])
        return updated

    doc = payload.model_dump()
    doc["userId"] = user_id_obj
    doc["createdAt"] = now
    doc["updatedAt"] = now
    
    res = coll.insert_one(doc)
    doc["_id"] = str(res.inserted_id)
    doc["userId"] = str(doc["userId"])
    return doc

@router.get("", response_model=FinancialProfileResponse)
def get_profile(current_user: dict = Depends(get_current_user)):
    coll = get_collection("financial_profiles")
    user_id_obj = ObjectId(current_user["_id"])
    
    doc = coll.find_one({"userId": user_id_obj})
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Financial profile not found for this user."
        )
    doc["_id"] = str(doc["_id"])
    doc["userId"] = str(doc["userId"])
    return doc

@router.put("", response_model=FinancialProfileResponse)
def update_profile(
    payload: FinancialProfileUpdate,
    current_user: dict = Depends(get_current_user)
):
    coll = get_collection("financial_profiles")
    user_id_obj = ObjectId(current_user["_id"])
    
    existing = coll.find_one({"userId": user_id_obj})
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Financial profile does not exist yet. Use POST to create."
        )
        
    update_dict = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    if not update_dict:
        existing["_id"] = str(existing["_id"])
        existing["userId"] = str(existing["userId"])
        return existing

    update_dict["updatedAt"] = datetime.now(timezone.utc)
    coll.update_one({"_id": existing["_id"]}, {"$set": update_dict})
    
    updated = coll.find_one({"_id": existing["_id"]})
    updated["_id"] = str(updated["_id"])
    updated["userId"] = str(updated["userId"])
    return updated
