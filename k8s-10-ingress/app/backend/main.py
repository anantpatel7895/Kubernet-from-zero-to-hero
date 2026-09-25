from fastapi import FastAPI
import requests

app = FastAPI(root_path="/api")

@app.get("/")
def home():
    return {
        "service": "backend",
        "message": "Backend Root"
    }

@app.get("/users")
def users():
    return {
        "users": [
            "John",
            "Alice",
            "Bob"
        ]
    }

@app.get("/admin-health")
def admin_health():
    
    try:
        response = requests.get("http://admin-service-ingress/health")
        if response.status_code == 200:
            return {
                "admin_status": response.json()
            }
        else:
            return {
                "admin_status": "unhealthy"
            }
    except Exception as e:
        return {
            "admin_status": "unhealthy",
            "error": str(e)
        }