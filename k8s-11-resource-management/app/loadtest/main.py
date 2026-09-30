from fastapi import FastAPI
import time
import os
import tempfile

app = FastAPI()

# Keeps allocated memory blocks alive so we can watch memory grow.
_memory_hog = []
_disk_files = []


@app.get("/")
def home():
    return {
        "service": "loadtest",
        "message": "Resource Management Demo",
        "endpoints": [
            "/burn-cpu?seconds=10   -> burns CPU (watch throttling)",
            "/eat-memory?mb=100     -> allocates memory (watch OOMKill)",
            "/release               -> frees allocated memory",
        ],
    }


@app.get("/burn-cpu")
def burn_cpu(seconds: int = 10):
    """Busy-loop to consume CPU. With a low CPU limit you'll see throttling."""
    start = time.time()
    count = 0
    while time.time() - start < seconds:
        count += 1
    return {
        "action": "burn-cpu",
        "seconds_requested": seconds,
        "iterations": count,
    }


@app.get("/eat-memory")
def eat_memory(mb: int = 100):
    """Allocate `mb` megabytes. Exceed the memory limit and the Pod is OOMKilled."""
    block = bytearray(mb * 1024 * 1024)
    _memory_hog.append(block)
    total_mb = sum(len(b) for b in _memory_hog) // (1024 * 1024)
    return {
        "action": "eat-memory",
        "added_mb": mb,
        "total_held_mb": total_mb,
    }

@app.get("/write-disk")
def write_disk(mb: int = 100):
    """
    Consume ephemeral storage.

    Useful for demonstrating:
    - ephemeral-storage limits
    - DiskPressure
    - eviction behavior
    """

    fd, path = tempfile.mkstemp(prefix="loadtest-", suffix=".bin")

    with os.fdopen(fd, "wb") as f:
        f.write(b"0" * mb * 1024 * 1024)

    _disk_files.append(path)

    total_mb = len(_disk_files) * mb

    return {
        "action": "write-disk",
        "added_mb": mb,
        "files": len(_disk_files),
        "estimated_total_mb": total_mb,
    }

@app.get("/cleanup-disk")
def cleanup_disk():

    removed = 0

    for file in _disk_files:
        try:
            os.remove(file)
            removed += 1
        except FileNotFoundError:
            pass

    _disk_files.clear()

    return {
        "action": "cleanup-disk",
        "removed_files": removed,
    }


@app.get("/release")
def release():
    """Drop all held memory."""
    _memory_hog.clear()
    return {"action": "release", "total_held_mb": 0}


@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/status")
def status():

    memory_mb = sum(
        len(block)
        for block in _memory_hog
    ) // (1024 * 1024)

    return {
        "memory_mb": memory_mb,
        "disk_files": len(_disk_files),
        "health": "ok",
    }
