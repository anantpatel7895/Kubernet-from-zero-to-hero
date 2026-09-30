from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {
        "service": "admin",
        "message": "Admin Dashboard"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }

@app.get("/users/{user_id}")
def get_user_info(user_id: int):
    user_data = [{
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com"
    },
    {
        "id": 2,
        "name": "Bob",
        "email": "bob@example.com"
    }]

    try:
        user = next(user for user in user_data if user["id"] == user_id)
        return user
    except StopIteration:
        return None