import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_user_registration_and_auth_flow():
    unique_str = str(uuid.uuid4())[:8]
    email = f"testuser_{unique_str}@example.com"
    phone = f"+9198765{unique_str[:5]}"
    password = "TestPassword123!"
    full_name = f"Test User {unique_str}"
    
    # 1. Register User
    reg_response = client.post("/auth/register", json={
        "fullName": full_name,
        "phone": phone,
        "email": email,
        "password": password
    })
    assert reg_response.status_code == 201, reg_response.text
    reg_data = reg_response.json()
    assert "access_token" in reg_data
    assert reg_data["user"]["email"] == email
    assert reg_data["user"]["phone"] == phone
    assert "passwordHash" not in reg_data["user"]
    
    token = reg_data["access_token"]
    
    # 2. Duplicate Email Rejection
    dup_email_res = client.post("/auth/register", json={
        "fullName": "Another Name",
        "phone": f"+9199999{unique_str[:5]}",
        "email": email,
        "password": "Password123!"
    })
    assert dup_email_res.status_code == 400
    assert "already exists" in dup_email_res.json()["detail"].lower()
    
    # 3. Duplicate Phone Rejection
    dup_phone_res = client.post("/auth/register", json={
        "fullName": "Another Name",
        "phone": phone,
        "email": f"another_{unique_str}@example.com",
        "password": "Password123!"
    })
    assert dup_phone_res.status_code == 400
    assert "already exists" in dup_phone_res.json()["detail"].lower()
    
    # 4. Login by Email
    login_email_res = client.post("/auth/login", json={
        "identifier": email,
        "password": password
    })
    assert login_email_res.status_code == 200
    assert "access_token" in login_email_res.json()
    
    # 5. Login by Phone
    login_phone_res = client.post("/auth/login", json={
        "identifier": phone,
        "password": password
    })
    assert login_phone_res.status_code == 200
    
    # 6. Invalid Password Rejection
    bad_pass_res = client.post("/auth/login", json={
        "identifier": email,
        "password": "WrongPassword!"
    })
    assert bad_pass_res.status_code == 401
    
    # 7. GET /users/me
    me_res = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["email"] == email
    assert me_data["fullName"] == full_name
    assert "passwordHash" not in me_data
