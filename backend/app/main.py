from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.database import get_database, init_indexes
from app.routes import auth, users, financial_profiles, goals, transactions, pipeline, insights

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize MongoDB Atlas indexes on startup
    try:
        init_indexes()
        print("✔ MongoDB Atlas indexes initialized successfully.")
    except Exception as e:
        print(f"⚠ Warning: Index initialization error: {e}")
    yield

app = FastAPI(
    title="GoalSync Backend API",
    description="FastAPI REST API connected to MongoDB Atlas for GoalSync mobile application.",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware for Flutter Web & Mobile development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(financial_profiles.router)
app.include_router(goals.router)
app.include_router(transactions.router)
app.include_router(pipeline.router)
app.include_router(insights.router)

@app.get("/health", tags=["Health"])
def health_check():
    """Basic health check endpoint."""
    return {"status": "ok"}

@app.get("/health/db", tags=["Health"])
def database_health_check():
    """Pings MongoDB Atlas and confirms database connectivity."""
    try:
        db = get_database()
        ping_res = db.command("ping")
        return {
            "status": "ok",
            "database": db.name,
            "ping": ping_res
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"MongoDB Atlas connection failure: {str(e)}"
        )
