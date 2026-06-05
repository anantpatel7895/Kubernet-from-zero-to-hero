# Project 07 - ConfigMaps & Secrets Demo App
#
# This app demonstrates how to read configuration from:
# 1. ConfigMaps (non-sensitive config)
# 2. Secrets (sensitive data like API keys, passwords)
#
# We'll demonstrate both methods of mounting:
# - Environment variables
# - Volume mounts (files)

from fastapi import FastAPI
from datetime import datetime
import os
import socket

app = FastAPI(
    title="ConfigMaps & Secrets Demo",
    version="1.0.0",
)


@app.get("/")
def read_root():
    """Basic endpoint with pod information"""
    return {
        "message": "ConfigMaps & Secrets Demo",
        "pod": socket.gethostname(),
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/config")
def read_config():
    """
    Read configuration from environment variables.
    These come from ConfigMaps.
    """
    return {
        "app_name": os.getenv("APP_NAME", "not-set"),
        "environment": os.getenv("ENVIRONMENT", "not-set"),
        "log_level": os.getenv("LOG_LEVEL", "not-set"),
        "max_connections": os.getenv("MAX_CONNECTIONS", "not-set"),
        "enable_feature_x": os.getenv("ENABLE_FEATURE_X", "not-set"),
        "pod": socket.gethostname(),
    }


@app.get("/secrets")
def read_secrets():
    """
    Read secrets from environment variables.
    NOTE: In production, you should NEVER expose secrets via API!
    This is for DEMO purposes only.
    """
    api_key = os.getenv("API_KEY", "not-set")
    db_password = os.getenv("DB_PASSWORD", "not-set")
    
    # Mask the actual values for security
    return {
        "api_key": f"{api_key[:4]}...{api_key[-4:]}" if len(api_key) > 8 else "too-short",
        "db_password": f"{db_password[:2]}...{db_password[-2:]}" if len(db_password) > 4 else "too-short",
        "warning": "⚠️ Never expose secrets in real applications!",
        "pod": socket.gethostname(),
    }


@app.get("/config/file")
def read_config_file():
    """
    Read configuration from files mounted from ConfigMaps.
    ConfigMaps can be mounted as volumes.
    """
    try:
        with open("/etc/config/app.properties", "r") as f:
            app_properties = f.read()
    except FileNotFoundError:
        app_properties = "File not found"
    
    try:
        with open("/etc/config/features.json", "r") as f:
            features_json = f.read()
    except FileNotFoundError:
        features_json = "File not found"
    
    return {
        "app_properties": app_properties,
        "features_json": features_json,
        "pod": socket.gethostname(),
    }


@app.get("/secrets/file")
def read_secrets_file():
    """
    Read secrets from files mounted from Secrets.
    Secrets can be mounted as volumes.
    """
    try:
        with open("/etc/secrets/api-key", "r") as f:
            api_key = f.read().strip()
    except FileNotFoundError:
        api_key = "not-found"
    
    try:
        with open("/etc/secrets/db-password", "r") as f:
            db_password = f.read().strip()
    except FileNotFoundError:
        db_password = "not-found"
    
    # Mask the actual values
    return {
        "api_key": f"{api_key[:4]}...{api_key[-4:]}" if len(api_key) > 8 else "too-short",
        "db_password": f"{db_password[:2]}...{db_password[-2:]}" if len(db_password) > 4 else "too-short",
        "warning": "⚠️ Never expose secrets in real applications!",
        "pod": socket.gethostname(),
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}
