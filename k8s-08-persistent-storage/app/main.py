# Project 08 - Persistent Storage Demo App
#
# This app demonstrates persistent storage in Kubernetes:
# - Write files to persistent volumes
# - Read files from persistent volumes
# - List all stored files
# - Delete files
# - Verify data persists across pod restarts

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from datetime import datetime
from pathlib import Path
import os
import socket
import json

# Storage directory (will be mounted from PVC)
STORAGE_DIR = Path(os.getenv("STORAGE_PATH", "/data"))
STORAGE_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="Persistent Storage Demo",
    version="1.0.0",
)


@app.get("/")
def read_root():
    """Basic endpoint with pod and storage information"""
    return {
        "message": "Persistent Storage Demo",
        "pod": socket.gethostname(),
        "storage_path": str(STORAGE_DIR),
        "storage_exists": STORAGE_DIR.exists(),
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    storage_writable = os.access(STORAGE_DIR, os.W_OK)
    storage_readable = os.access(STORAGE_DIR, os.R_OK)
    
    return {
        "status": "healthy" if storage_writable and storage_readable else "unhealthy",
        "storage_writable": storage_writable,
        "storage_readable": storage_readable,
        "pod": socket.gethostname(),
    }


@app.post("/files/{filename}")
def write_file(filename: str, content: str):
    """
    Write content to a file in persistent storage.
    This data will survive pod restarts!
    """
    try:
        file_path = STORAGE_DIR / filename
        
        # Prevent directory traversal
        if ".." in filename or filename.startswith("/"):
            raise HTTPException(status_code=400, detail="Invalid filename")
        
        # Write file with metadata
        data = {
            "content": content,
            "created_at": datetime.now().isoformat(),
            "created_by_pod": socket.gethostname(),
        }
        
        file_path.write_text(json.dumps(data, indent=2))
        
        return {
            "message": f"File '{filename}' written successfully",
            "path": str(file_path),
            "size": file_path.stat().st_size,
            "pod": socket.gethostname(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/files/{filename}")
def read_file(filename: str):
    """
    Read a file from persistent storage.
    This will work even after pod restart!
    """
    try:
        file_path = STORAGE_DIR / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File '{filename}' not found")
        
        data = json.loads(file_path.read_text())
        
        return {
            "filename": filename,
            "data": data,
            "size": file_path.stat().st_size,
            "read_by_pod": socket.gethostname(),
            "timestamp": datetime.now().isoformat(),
        }
    except json.JSONDecodeError:
        # Handle non-JSON files
        return {
            "filename": filename,
            "content": file_path.read_text(),
            "size": file_path.stat().st_size,
            "read_by_pod": socket.gethostname(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/files")
def list_files():
    """List all files in persistent storage"""
    try:
        files = []
        for file_path in STORAGE_DIR.iterdir():
            if file_path.is_file():
                files.append({
                    "filename": file_path.name,
                    "size": file_path.stat().st_size,
                    "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat(),
                })
        
        return {
            "files": files,
            "count": len(files),
            "storage_path": str(STORAGE_DIR),
            "pod": socket.gethostname(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/files/{filename}")
def delete_file(filename: str):
    """Delete a file from persistent storage"""
    try:
        file_path = STORAGE_DIR / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File '{filename}' not found")
        
        file_path.unlink()
        
        return {
            "message": f"File '{filename}' deleted successfully",
            "pod": socket.gethostname(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """Upload a file to persistent storage"""
    try:
        file_path = STORAGE_DIR / file.filename
        
        # Write uploaded file
        content = await file.read()
        file_path.write_bytes(content)
        
        return {
            "message": f"File '{file.filename}' uploaded successfully",
            "filename": file.filename,
            "size": len(content),
            "path": str(file_path),
            "pod": socket.gethostname(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/storage/info")
def storage_info():
    """Get storage information"""
    try:
        import shutil
        
        total, used, free = shutil.disk_usage(STORAGE_DIR)
        
        return {
            "storage_path": str(STORAGE_DIR),
            "total_gb": round(total / (1024**3), 2),
            "used_gb": round(used / (1024**3), 2),
            "free_gb": round(free / (1024**3), 2),
            "used_percent": round((used / total) * 100, 2),
            "pod": socket.gethostname(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
