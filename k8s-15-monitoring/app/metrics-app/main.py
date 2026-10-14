"""
metrics-app - a small FastAPI service that exposes Prometheus metrics.

The point of this app is to produce *interesting* metrics on demand so you can
write real PromQL instead of staring at a flat line:

    /            -> index
    /work        -> normal fast request
    /slow        -> slow request (fills the high latency histogram buckets)
    /error       -> returns 500 (drives the error-rate query)
    /queue?n=    -> sets a gauge (a value that goes up AND down)
    /health      -> liveness/readiness probe target
    /metrics     -> Prometheus scrape endpoint
"""

import random
import time

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

app = FastAPI()


# ---------------------------------------------------------------------------
# Metric definitions
#
# Naming rules Prometheus expects:
#   <name>_<unit>_<suffix>     e.g. http_request_duration_seconds
#   counters end in _total     e.g. http_requests_total
#   always use base units      seconds, bytes - never ms or MB
#
# Labels are dimensions you can slice by. Keep cardinality LOW:
# never put a user id, email, or raw URL with an id in a label.
# ---------------------------------------------------------------------------

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests processed.",
    ["method", "path", "status"],
)

LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path"],
    # Buckets are cumulative upper bounds. Pick them around your SLO.
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "Number of HTTP requests currently being served.",
)

QUEUE_DEPTH = Gauge(
    "app_queue_depth",
    "Simulated work queue depth - a value that can go up and down.",
)

APP_INFO = Gauge(
    "app_info",
    "Build information. Always 1; the data lives in the labels.",
    ["version"],
)
APP_INFO.labels(version="v1").set(1)


# ---------------------------------------------------------------------------
# Middleware: record one Counter sample and one Histogram sample per request.
#
# We use `request.scope["route"].path` (the *template*, e.g. /items/{id})
# and NOT request.url.path, otherwise every id creates a new time series.
# That mistake is the #1 cause of a Prometheus OOM in production.
# ---------------------------------------------------------------------------
@app.middleware("http")
async def record_metrics(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    start = time.perf_counter()
    IN_PROGRESS.inc()

    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:
        status = 500
        raise
    finally:
        IN_PROGRESS.dec()
        route = request.scope.get("route")
        path = route.path if route else "unmatched"
        elapsed = time.perf_counter() - start
        LATENCY.labels(request.method, path).observe(elapsed)
        REQUESTS.labels(request.method, path, str(status)).inc()

    return response


@app.get("/")
def home():
    return {
        "service": "metrics-app",
        "message": "Prometheus + Grafana monitoring demo",
        "endpoints": [
            "/work          -> fast request",
            "/slow          -> slow request (0.5-3s)",
            "/error         -> returns HTTP 500",
            "/queue?n=42    -> set the app_queue_depth gauge",
            "/health        -> probe endpoint",
            "/metrics       -> Prometheus scrape endpoint",
        ],
    }


@app.get("/work")
def work():
    """Fast path. Lands in the low latency buckets."""
    time.sleep(random.uniform(0.005, 0.05))
    return {"action": "work", "status": "done"}


@app.get("/slow")
def slow():
    """Slow path. Pushes the p95/p99 up so your dashboard has something to show."""
    delay = random.uniform(0.5, 3.0)
    time.sleep(delay)
    return {"action": "slow", "slept_seconds": round(delay, 3)}


@app.get("/error")
def error():
    """Always fails. Use it to drive the error-rate panel and the alert rule."""
    return JSONResponse(status_code=500, content={"error": "intentional failure"})


@app.get("/flaky")
def flaky():
    """Fails roughly 30% of the time - more realistic than /error."""
    if random.random() < 0.3:
        return JSONResponse(status_code=500, content={"error": "flaky failure"})
    return {"action": "flaky", "status": "ok"}


@app.get("/queue")
def queue(n: int = 0):
    """Set the gauge. Counters only go up; gauges go both ways."""
    QUEUE_DEPTH.set(n)
    return {"action": "queue", "app_queue_depth": n}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/metrics")
def metrics():
    """
    The scrape endpoint.

    Prometheus does a plain HTTP GET here every `scrape_interval` and parses
    the text exposition format. The app never pushes anything.
    """
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
