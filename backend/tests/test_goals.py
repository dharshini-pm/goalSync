import uuid
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def create_test_user(prefix: str):
    u_str = str(uuid.uuid4())[:8]
    email = f"{prefix}_{u_str}@example.com"
    phone = f"+91888{prefix[:2]}{u_str[:5]}"
    res = client.post("/auth/register", json={
        "fullName": f"{prefix} User",
        "phone": phone,
        "email": email,
        "password": "Password123!"
    })
    data = res.json()
    return data["access_token"], data["user"]["_id"]

def test_goals_crud_and_isolation():
    token_a, user_id_a = create_test_user("user_a_goals")
    token_b, user_id_b = create_test_user("user_b_goals")
    
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}
    
    target_date = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
    
    # 1. User A creates a goal
    goal_payload = {
        "name": "Buy Emergency Fund",
        "category": "emergencyFund",
        "targetAmount": 100000.0,
        "currentAmount": 25000.0,
        "targetDate": target_date,
        "priority": "essential"
    }
    create_res = client.post("/goals", json=goal_payload, headers=headers_a)
    assert create_res.status_code == 201, create_res.text
    goal_a = create_res.json()
    goal_id_a = goal_a["_id"]
    assert goal_a["userId"] == user_id_a
    assert goal_a["name"] == "Buy Emergency Fund"
    
    # 2. User A fetches goals
    list_res = client.get("/goals", headers=headers_a)
    assert list_res.status_code == 200
    goals_list = list_res.json()
    assert len(goals_list) >= 1
    assert any(g["_id"] == goal_id_a for g in goals_list)
    
    # 3. User A gets single goal
    get_res = client.get(f"/goals/{goal_id_a}", headers=headers_a)
    assert get_res.status_code == 200
    assert get_res.json()["_id"] == goal_id_a
    
    # 4. User A updates goal
    update_res = client.put(f"/goals/{goal_id_a}", json={"currentAmount": 35000.0}, headers=headers_a)
    assert update_res.status_code == 200
    assert update_res.json()["currentAmount"] == 35000.0
    
    # 5. CROSS-USER AUTHORIZATION PROTECTION TESTS
    # User B tries to access User A's goal -> Must return 404
    cross_get_res = client.get(f"/goals/{goal_id_a}", headers=headers_b)
    assert cross_get_res.status_code == 404
    
    # User B tries to update User A's goal -> Must return 404
    cross_put_res = client.put(f"/goals/{goal_id_a}", json={"name": "Hacked Goal"}, headers=headers_b)
    assert cross_put_res.status_code == 404
    
    # User B tries to delete User A's goal -> Must return 404
    cross_del_res = client.delete(f"/goals/{goal_id_a}", headers=headers_b)
    assert cross_del_res.status_code == 404
    
    # Verify User A's goal was not modified or deleted by User B
    verify_res = client.get(f"/goals/{goal_id_a}", headers=headers_a)
    assert verify_res.status_code == 200
    assert verify_res.json()["name"] == "Buy Emergency Fund"
    
    # 6. User A deletes goal
    del_res = client.delete(f"/goals/{goal_id_a}", headers=headers_a)
    assert del_res.status_code == 204
    
    get_del_res = client.get(f"/goals/{goal_id_a}", headers=headers_a)
    assert get_del_res.status_code == 404
