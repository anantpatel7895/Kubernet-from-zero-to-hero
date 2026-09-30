from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {
        "service": "frontend",
        "message": "Welcome to Frontend"
    }

@app.get("/health")
def health():
    return {
        "app_name": "frontend",
        "status": "healthy"
    }
