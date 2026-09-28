from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.database import get_collection
from app.dependencies import get_current_user
from app.schemas.goal import GoalCreate, GoalUpdate, GoalResponse

router = APIRouter(prefix="/goals", tags=["Goals"])


@router.post("", response_model=GoalResponse, status_code=status.HTTP_201_CREATED)
def create_goal(payload: GoalCreate, current_user: dict = Depends(get_current_user)):
    coll = get_collection("goals")
    user_id = str(current_user["_id"])
    now = datetime.now(timezone.utc)

    doc = payload.model_dump()
    doc["userId"] = user_id
    doc["createdAt"] = now
    doc["updatedAt"] = now

    res = coll.insert_one(doc)
    doc["_id"] = str(res.inserted_id)
    doc["userId"] = str(doc["userId"])
    return doc


@router.get("", response_model=List[GoalResponse])
def get_goals(current_user: dict = Depends(get_current_user)):
    coll = get_collection("goals")
    user_id = str(current_user["_id"])

    cursor = coll.find({"userId": user_id}).sort("createdAt", -1)
    results = []
    for doc in cursor:
        doc["_id"] = str(doc["_id"])
        doc["userId"] = str(doc["userId"])
        results.append(doc)
    return results


@router.get("/{goal_id}", response_model=GoalResponse)
def get_goal(goal_id: str, current_user: dict = Depends(get_current_user)):
    clean_goal_id = str(goal_id).strip()
    if not clean_goal_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")

    coll = get_collection("goals")
    user_id = str(current_user["_id"])

    # Strictly filter by both goal_id AND authenticated userId
    doc = coll.find_one({"_id": clean_goal_id, "userId": user_id})
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")

    doc["_id"] = str(doc["_id"])
    doc["userId"] = str(doc["userId"])
    return doc


@router.put("/{goal_id}", response_model=GoalResponse)
def update_goal(goal_id: str, payload: GoalUpdate, current_user: dict = Depends(get_current_user)):
    clean_goal_id = str(goal_id).strip()
    if not clean_goal_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")

    coll = get_collection("goals")
    user_id = str(current_user["_id"])

    doc = coll.find_one({"_id": clean_goal_id, "userId": user_id})
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")

    update_dict = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    if update_dict:
        update_dict["updatedAt"] = datetime.now(timezone.utc)
        coll.update_one({"_id": clean_goal_id, "userId": user_id}, {"$set": update_dict})

    updated = coll.find_one({"_id": clean_goal_id, "userId": user_id})
    updated["_id"] = str(updated["_id"])
    updated["userId"] = str(updated["userId"])
    return updated


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_goal(goal_id: str, current_user: dict = Depends(get_current_user)):
    clean_goal_id = str(goal_id).strip()
    if not clean_goal_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")

    coll = get_collection("goals")
    user_id = str(current_user["_id"])

    res = coll.delete_one({"_id": clean_goal_id, "userId": user_id})
    if res.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found.")
    return None
