from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId
from app.database import get_collection
from app.dependencies import get_current_user
from app.schemas.transaction import TransactionCreate, TransactionUpdate, TransactionResponse

router = APIRouter(prefix="/transactions", tags=["Transactions"])

@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(payload: TransactionCreate, current_user: dict = Depends(get_current_user)):
    coll = get_collection("transactions")
    user_id_obj = ObjectId(current_user["_id"])
    now = datetime.now(timezone.utc)
    
    doc = payload.model_dump()
    doc["userId"] = user_id_obj
    doc["createdAt"] = now
    doc["updatedAt"] = now
    
    res = coll.insert_one(doc)
    doc["_id"] = str(res.inserted_id)
    doc["userId"] = str(doc["userId"])
    return doc

@router.get("", response_model=List[TransactionResponse])
def get_transactions(current_user: dict = Depends(get_current_user)):
    coll = get_collection("transactions")
    user_id_obj = ObjectId(current_user["_id"])
    
    cursor = coll.find({"userId": user_id_obj}).sort("dateTime", -1)
    results = []
    for doc in cursor:
        doc["_id"] = str(doc["_id"])
        doc["userId"] = str(doc["userId"])
        results.append(doc)
    return results

@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(transaction_id: str, current_user: dict = Depends(get_current_user)):
    try:
        tx_obj_id = ObjectId(transaction_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
        
    coll = get_collection("transactions")
    user_id_obj = ObjectId(current_user["_id"])
    
    doc = coll.find_one({"_id": tx_obj_id, "userId": user_id_obj})
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
        
    doc["_id"] = str(doc["_id"])
    doc["userId"] = str(doc["userId"])
    return doc

@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(transaction_id: str, payload: TransactionUpdate, current_user: dict = Depends(get_current_user)):
    try:
        tx_obj_id = ObjectId(transaction_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
        
    coll = get_collection("transactions")
    user_id_obj = ObjectId(current_user["_id"])
    
    doc = coll.find_one({"_id": tx_obj_id, "userId": user_id_obj})
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
        
    update_dict = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    if update_dict:
        update_dict["updatedAt"] = datetime.now(timezone.utc)
        coll.update_one({"_id": tx_obj_id, "userId": user_id_obj}, {"$set": update_dict})
        
    updated = coll.find_one({"_id": tx_obj_id, "userId": user_id_obj})
    updated["_id"] = str(updated["_id"])
    updated["userId"] = str(updated["userId"])
    return updated

@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(transaction_id: str, current_user: dict = Depends(get_current_user)):
    try:
        tx_obj_id = ObjectId(transaction_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
        
    coll = get_collection("transactions")
    user_id_obj = ObjectId(current_user["_id"])
    
    res = coll.delete_one({"_id": tx_obj_id, "userId": user_id_obj})
    if res.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
    return None
