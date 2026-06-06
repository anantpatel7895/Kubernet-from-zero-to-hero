# Project 06 - Rolling Updates App
# Same app as Project 02 but we'll deploy multiple versions to demonstrate
# rolling updates and rollbacks.
#
# Build different versions of this image using a build arg:
#   docker build -t fastapi-demo:v1 --build-arg APP_VERSION=1.0.0 .
#   docker build -t fastapi-demo:v2 --build-arg APP_VERSION=2.0.0 .
#   docker build -t fastapi-demo:v3 --build-arg APP_VERSION=3.0.0 .
#
# (We'll use the existing fastapi-demo:v1 image already built in Project 02,
#  plus build v2 and v3 to see updates in action.)

from fastapi import FastAPI
from datetime import datetime
import os
import socket

# Read version from environment (set by the Deployment)
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

app = FastAPI(
    title=f"Rolling Update Demo - v{APP_VERSION}",
    version=APP_VERSION,
)


@app.get("/")
def read_root():
    return {
        "message": f"Hello from FastAPI v{APP_VERSION}!",
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/health")
def health():
    return {"status": "healthy", "version": APP_VERSION}


@app.get("/version")
def version():
    """Endpoint specifically for checking which version a pod is running."""
    return {
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "environment": ENVIRONMENT,
    }
