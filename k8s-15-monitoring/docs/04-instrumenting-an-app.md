# 04 - Instrumenting Your Application

---

# Learning Objectives

* How a client library turns code into a `/metrics` endpoint
* Reading the demo app line by line
* Why the route template matters
* Multi-process gotchas (gunicorn, uvicorn workers)
* What to instrument first (and what never to)
* Exporters: when you cannot change the code

---

# The Contract

To be scraped, a process must do exactly one thing:

```text
Serve HTTP GET /metrics returning the text exposition format.
```

That's it. No agent, no SDK registration, no push config.

```python
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

`generate_latest()` walks the default registry and renders every metric your
process has declared.

---

# Reading the Demo App

`app/metrics-app/main.py` declares four metrics.

### The counter

```python
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests processed.",
    ["method", "path", "status"],
)
```

Declared **once at import time**, not per request. The label names are fixed
here; the label *values* are supplied at increment time.

### The histogram

```python
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
```

Note `status` is deliberately **not** a latency label: it would multiply the
bucket series by 5 for very little insight.

### The gauge

```python
IN_PROGRESS = Gauge("http_requests_in_progress", "...")
```

Incremented on entry, decremented in a `finally` - so an exception cannot
leak the gauge upward forever.

### The info metric

```python
APP_INFO = Gauge("app_info", "...", ["version"])
APP_INFO.labels(version="v1").set(1)
```

The "info metric" pattern: the value is always `1`, and all the information
lives in the labels. Join it onto other queries:

```promql
job:http_requests:rate5m * on(job) group_left(version) app_info
```

---

# The Middleware

```python
@app.middleware("http")
async def record_metrics(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)          # don't measure the scrape

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
        LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
        REQUESTS.labels(request.method, path, str(status)).inc()

    return response
```

Five deliberate decisions in there:

```text
1. Skip /metrics itself, or every scrape inflates your own request count.

2. perf_counter(), not time() - a monotonic clock cannot go backwards
   when NTP adjusts the system time.

3. The `finally` block records BOTH the success and the exception path.
   An endpoint that throws is exactly the one you need in your error rate.

4. The ROUTE TEMPLATE, not the raw URL:
       route.path      -> "/items/{id}"     bounded, ~20 values
       request.url.path-> "/items/8f3a2b"   unbounded, one series per id
   This single line is the difference between a working Prometheus and
   an OOMKilled one.

5. "unmatched" for 404s. Without it, every scan for /wp-admin.php,
   /.env, /phpmyadmin creates a new time series - an attacker can blow
   up your monitoring from the outside.
```

---

# What to Instrument First

Start with the **RED method** for every request-serving service:

```text
R ate      - requests per second
E rrors    - failed requests per second
D uration  - latency distribution
```

Those three come free from the middleware above. Then add what is specific
to *your* business:

```text
orders_created_total
payment_failures_total{reason="card_declined"}
queue_depth
cache_hits_total / cache_misses_total
background_job_duration_seconds
```

```text
Instrument the thing your USERS care about,
not the thing that is easy to measure.
```

### What never to instrument

```text
* Anything with an unbounded label (see doc 03).
* Values you can already derive. You do not need a `success_total` if you
  have `requests_total{status=...}`.
* A metric per customer in a multi-tenant SaaS. That is a log or a trace.
```

---

# The Multi-Process Problem

This bites almost everyone deploying Python.

```text
gunicorn -w 4 main:app
```

Four worker processes, each with its **own** in-memory registry. The scrape
hits whichever worker the OS routes it to:

```text
scrape 1 -> worker 2 -> http_requests_total 431
scrape 2 -> worker 4 -> http_requests_total 118     <-- looks like a reset!
scrape 3 -> worker 1 -> http_requests_total 502
```

Counters appear to jump backwards and `rate()` produces nonsense.

Three fixes, best first:

```text
1. One process per container. Let Kubernetes do the scaling with
   `replicas:` instead of running N workers in one Pod. This is the
   idiomatic answer and the one this project uses
   (uvicorn with a single worker, replicas: 2).

2. prometheus_client multiprocess mode:
      export PROMETHEUS_MULTIPROC_DIR=/tmp/prom
   Workers write to shared mmap files; the /metrics handler aggregates
   them. Loses some features (no live gauges by default).

3. A sidecar exporter that aggregates - extra moving parts, rarely worth it.
```

Go, Java and Node do not have this problem - they are one process with
threads, sharing a single registry.

---

# Exporters: When You Cannot Change the Code

You cannot add `/metrics` to Postgres, nginx, Redis or a vendor's JAR. So the
community writes an **exporter**: a small process that reads the system's
native stats and republishes them as Prometheus metrics.

```text
  ┌──────────┐  native protocol  ┌────────────────┐  /metrics  ┌────────────┐
  │ Postgres │◄─────────────────►│ postgres_      │◄───────────│ Prometheus │
  │          │   SQL queries     │ exporter       │   scrape   │            │
  └──────────┘                   └────────────────┘            └────────────┘
```

Common ones:

| Exporter | Scrapes |
|---|---|
| node_exporter | Linux host: CPU, memory, disk, network |
| kube-state-metrics | Kubernetes API object state |
| blackbox_exporter | probes URLs/TCP/DNS **from outside** |
| postgres_exporter / mysqld_exporter | databases |
| redis_exporter | Redis |
| nginx-prometheus-exporter | nginx stub_status |
| jmx_exporter | any JVM app, as a java agent |

Deployment pattern:

```text
A machine-level exporter  -> DaemonSet   (node-exporter: one per node)
A per-service exporter    -> sidecar container in the app's Pod
A cluster-wide exporter   -> Deployment  (kube-state-metrics: one per cluster)
```

---

# Verifying Your Instrumentation

```bash
# 1. Is the endpoint serving the right content type?
kubectl exec -n monitoring deploy/metrics-app -- \
  python -c "import urllib.request;r=urllib.request.urlopen('http://localhost:8000/metrics');print(r.headers['content-type'])"
# text/plain; version=0.0.4; charset=utf-8

# 2. Did Prometheus discover it?
#    UI -> Status -> Targets -> job "kubernetes-pods"

# 3. How many series is this target producing?
#    (run in the Prometheus UI)
#    scrape_samples_scraped{job="kubernetes-pods"}

# 4. Validate the output format offline
promtool check metrics < metrics.txt
```

---

# Key Takeaways

```text
1. Instrumentation = serve GET /metrics. Nothing else.
2. Declare metrics once at import time; set label VALUES per event.
3. Use the route template as the `path` label. Never the raw URL.
4. Record metrics in a `finally` so failures are counted too.
5. One process per container, or counters will appear to reset.
6. Cannot change the code? Use an exporter.
```

---

# Interview Questions

**Q: How do you add Prometheus metrics to an existing service?**
Add the client library, declare counters/histograms at module scope, record
them in middleware, and expose `/metrics`. Then let Prometheus discover the
Pod - via annotations or a ServiceMonitor.

**Q: Your counters keep resetting mid-day. What is happening?**
Either the Pod is restarting (check `kube_pod_container_status_restarts_total`)
or you are running multiple worker processes per container, each with its own
registry, and the scrape hits a different worker each time.

**Q: What is an exporter?**
A translator process that exposes a third-party system's statistics in
Prometheus format, used when you cannot instrument the system directly.

**Q: Where should the `path` label come from?**
The routing framework's path template, so the label has a small, bounded set
of values.
