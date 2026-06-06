from fastapi import FastAPI
from datetime import datetime
import os
import socket

app = FastAPI(title="FastAPI Demo", version="1.0.0")

@app.get("/")
async def root():
    """
    Root endpoint - returns welcome message
    """
    return {
        "message": "Hello from FastAPI on Kubernetes!",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    """
    Health check endpoint
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/info")
async def info():
    """
    Returns pod/container information
    """
    return {
        "hostname": socket.gethostname(),
        "environment": os.getenv("ENVIRONMENT", "development"),
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/v1/users")
async def get_users():
    """
    Sample API endpoint
    """
    return {
        "users": [
            {"id": 1, "name": "Alice", "email": "alice@example.com"},
            {"id": 2, "name": "Bob", "email": "bob@example.com"},
            {"id": 3, "name": "Charlie", "email": "charlie@example.com"}
        ],
        "total": 3
    }

@app.get("/api/v1/users/{user_id}")
async def get_user(user_id: int):
    """
    Get a specific user by ID
    """
    users = {
        1: {"id": 1, "name": "Alice", "email": "alice@example.com"},
        2: {"id": 2, "name": "Bob", "email": "bob@example.com"},
        3: {"id": 3, "name": "Charlie", "email": "charlie@example.com"}
    }
    
    user = users.get(user_id)
    if user:
        return user
    return {"error": "User not found"}, 404

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
