import uuid
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def create_test_user(prefix: str):
    u_str = str(uuid.uuid4())[:8]
    email = f"{prefix}_{u_str}@example.com"
    phone = f"+91777{prefix[:2]}{u_str[:5]}"
    res = client.post("/auth/register", json={
        "fullName": f"{prefix} User",
        "phone": phone,
        "email": email,
        "password": "Password123!"
    })
    data = res.json()
    return data["access_token"], data["user"]["_id"]

def test_financial_profiles_and_transactions_isolation():
    token_a, user_id_a = create_test_user("user_a_tx")
    token_b, user_id_b = create_test_user("user_b_tx")
    
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}
    
    # -------------------------------------------------------------
    # 1. Financial Profile CRUD & Isolation
    # -------------------------------------------------------------
    profile_data = {
        "age": 28,
        "occupation": "Software Engineer",
        "dependents": 1,
        "monthlyIncome": 120000.0,
        "incomeType": "Salary",
        "additionalIncome": 10000.0,
        "currentSavings": 300000.0,
        "fixedExpenses": 40000.0,
        "variableExpenses": 20000.0,
        "monthlyEMI": 15000.0,
        "activeLoans": 1
    }
    
    create_prof_res = client.post("/financial-profile", json=profile_data, headers=headers_a)
    assert create_prof_res.status_code == 201
    prof_a = create_prof_res.json()
    assert prof_a["userId"] == user_id_a
    
    get_prof_a = client.get("/financial-profile", headers=headers_a)
    assert get_prof_a.status_code == 200
    assert get_prof_a.json()["occupation"] == "Software Engineer"
    
    # User B checks profile -> must be 404 since User B has not created one
    get_prof_b = client.get("/financial-profile", headers=headers_b)
    assert get_prof_b.status_code == 404
    
    # -------------------------------------------------------------
    # 2. Transactions CRUD & Isolation
    # -------------------------------------------------------------
    tx_payload = {
        "amount": 2500.0,
        "type": "debit",
        "merchantName": "Grocery Mart",
        "category": "Groceries",
        "dateTime": datetime.now(timezone.utc).isoformat(),
        "paymentMethod": "upi",
        "notes": "Weekly groceries purchase"
    }
    
    tx_create_res = client.post("/transactions", json=tx_payload, headers=headers_a)
    assert tx_create_res.status_code == 201, tx_create_res.text
    tx_a = tx_create_res.json()
    tx_id_a = tx_a["_id"]
    assert tx_a["userId"] == user_id_a
    
    # User A lists transactions
    tx_list_res = client.get("/transactions", headers=headers_a)
    assert tx_list_res.status_code == 200
    tx_list = tx_list_res.json()
    assert len(tx_list) >= 1
    assert any(t["_id"] == tx_id_a for t in tx_list)
    
    # User B lists transactions -> should NOT see User A's transaction
    tx_list_b = client.get("/transactions", headers=headers_b)
    assert tx_list_b.status_code == 200
    assert not any(t["_id"] == tx_id_a for t in tx_list_b.json())
    
    # User B tries to read User A's transaction -> 404
    assert client.get(f"/transactions/{tx_id_a}", headers=headers_b).status_code == 404
    
    # User B tries to update User A's transaction -> 404
    assert client.put(f"/transactions/{tx_id_a}", json={"amount": 9999.0}, headers=headers_b).status_code == 404
    
    # User B tries to delete User A's transaction -> 404
    assert client.delete(f"/transactions/{tx_id_a}", headers=headers_b).status_code == 404
    
    # User A deletes their transaction
    assert client.delete(f"/transactions/{tx_id_a}", headers=headers_a).status_code == 204
    assert client.get(f"/transactions/{tx_id_a}", headers=headers_a).status_code == 404
