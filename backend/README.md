# GoalSync FastAPI Backend API

High-performance, secure FastAPI backend for **GoalSync**, connected to MongoDB Atlas.

---

## 🚀 Quick Start Guide

### 1. Virtual Environment Setup
```bash
cd backend
python -m venv venv
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Environment Configuration
Copy `.env.example` to `.env` and configure your settings:
```bash
cp .env.example .env
```

```env
MONGODB_URI=your_mongodb_connection_string
DATABASE_NAME=goalsync
JWT_SECRET=your_secure_jwt_secret_key_change_in_production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

---

## 🧪 Testing & Verification

### 1. Verify MongoDB Connection
Run the connection test script to confirm connectivity to MongoDB Atlas `goalsync` database and `users` collection:
```bash
python tests/test_connection.py
```

### 2. Run Complete Test Suite
Run `pytest` to execute all integration and authorization isolation tests:
```bash
pytest
```

---

## 🏃 Running the Application

Start the local development server with live reload:
```bash
uvicorn app.main:app --reload
```

* **API Base URL:** `http://127.0.0.1:8000`
* **Interactive Swagger UI Documentation:** `http://127.0.0.1:8000/docs`
* **ReDoc Documentation:** `http://127.0.0.1:8000/redoc`

---

## 🔑 Authentication

All protected endpoints require a JWT access token sent in the `Authorization` header:

```text
Authorization: Bearer <your_access_token>
```

---

## 📄 API Endpoints Summary

### Health Endpoints
* `GET /health` — Basic API health check
* `GET /health/db` — MongoDB Atlas database connectivity check

### Authentication (`/auth`)
* `POST /auth/register` — Register a new user (`fullName`, `phone`, `email`, `password`)
* `POST /auth/login` — Login using email or phone number (`identifier`, `password`)

### User Profile (`/users`)
* `GET /users/me` — Retrieve profile of the currently authenticated user

### Financial Profile (`/financial-profile`)
* `POST /financial-profile` — Create or update financial profile
* `GET /financial-profile` — Retrieve user's financial profile
* `PUT /financial-profile` — Update financial profile

### Goals (`/goals`)
* `POST /goals` — Create a new financial goal
* `GET /goals` — List all goals owned by authenticated user
* `GET /goals/{goal_id}` — Get single goal details
* `PUT /goals/{goal_id}` — Update goal
* `DELETE /goals/{goal_id}` — Delete goal

### Transactions (`/transactions`)
* `POST /transactions` — Record a transaction (`debit` / `credit`)
* `GET /transactions` — List all user transactions
* `GET /transactions/{transaction_id}` — Get single transaction details
* `PUT /transactions/{transaction_id}` — Update transaction
* `DELETE /transactions/{transaction_id}` — Delete transaction
