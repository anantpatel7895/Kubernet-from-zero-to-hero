# 03 - The Four Metric Types

---

# Learning Objectives

* Counter, Gauge, Histogram, Summary - what each is for
* Why you almost never query a counter directly
* How a histogram is actually stored
* Why percentiles cannot be averaged
* Naming and labelling rules
* The cardinality trap

---

# The Exposition Format

Everything Prometheus scrapes is plain text:

```text
# HELP http_requests_total Total HTTP requests processed.
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/work",status="200"} 4821
http_requests_total{method="GET",path="/error",status="500"} 37

# HELP http_requests_in_progress Number of requests currently being served.
# TYPE http_requests_in_progress gauge
http_requests_in_progress 3
```

```text
# HELP  -> human description
# TYPE  -> counter | gauge | histogram | summary
line   -> name{labels} value
```

See it yourself:

```bash
kubectl exec -n monitoring deploy/metrics-app -- \
  python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/metrics').read().decode())"
```

---

# 1. Counter

**A number that only ever goes up, or resets to 0 on restart.**

```text
requests:  0 -> 14 -> 31 -> 52 -> 88 -> [restart] -> 0 -> 9
```

Use for: requests served, errors, bytes sent, tasks completed.

```python
REQUESTS = Counter("http_requests_total", "...", ["method", "path", "status"])
REQUESTS.labels("GET", "/work", "200").inc()
```

### The rule: never graph a counter raw

```promql
http_requests_total              # a line that only goes up. useless.
rate(http_requests_total[5m])    # requests per second. this is what you want.
```

`rate()` also **handles counter resets for you**. When a Pod restarts and the
counter drops to zero, `rate()` detects the drop and treats it as a reset
instead of reporting a huge negative number.

```text
Counter convention: the name MUST end in _total
```

---

# 2. Gauge

**A number that goes up and down.**

```text
queue depth:  4 -> 9 -> 2 -> 0 -> 17
```

Use for: memory in use, queue length, in-flight requests, temperature,
replica count.

```python
QUEUE_DEPTH = Gauge("app_queue_depth", "...")
QUEUE_DEPTH.set(17)
QUEUE_DEPTH.inc()
QUEUE_DEPTH.dec()
```

Query it directly - `rate()` on a gauge is meaningless:

```promql
app_queue_depth                       # current value
avg_over_time(app_queue_depth[1h])    # smoothed
max_over_time(app_queue_depth[24h])   # worst point today
delta(app_queue_depth[1h])            # change over the hour
```

### Counter or gauge?

```text
"Can this number ever get smaller for a reason other than a restart?"

  yes -> gauge
  no  -> counter
```

---

# 3. Histogram

**Counts observations into cumulative buckets.** This is how you get latency
percentiles.

```python
LATENCY = Histogram(
    "http_request_duration_seconds", "...",
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
LATENCY.observe(0.237)
```

One histogram produces **many** series:

```text
http_request_duration_seconds_bucket{le="0.005"}  120
http_request_duration_seconds_bucket{le="0.01"}   340
http_request_duration_seconds_bucket{le="0.025"}  812
http_request_duration_seconds_bucket{le="0.05"}   1190
...
http_request_duration_seconds_bucket{le="+Inf"}   1400
http_request_duration_seconds_sum                 183.4
http_request_duration_seconds_count               1400
```

Three things to notice:

```text
1. Buckets are CUMULATIVE.
   le="0.05" means "requests that took <= 0.05s", which includes
   everything in the smaller buckets.

2. le="+Inf" always equals _count.

3. Every bucket is its own time series.
   10 buckets + sum + count = 12 series PER LABEL COMBINATION.
```

### Getting a percentile

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

Read it inside out:

```text
rate(..._bucket[5m])   per-second rate for each bucket
sum by (le) (...)      merge all pods together, KEEPING the le label
histogram_quantile     interpolate the 95th percentile from the buckets
```

Forgetting `by (le)` is the most common PromQL mistake there is -
`histogram_quantile` has nothing to work with and returns `NaN`.

### Histograms are approximate

The result is interpolated **within** a bucket. If your buckets are
`0.5` and `1.0` and everything lands between them, p95 is a guess somewhere
in that range. Choose buckets around the SLO you care about:

```text
SLO: 99% of requests under 300ms
  -> make sure you have a bucket boundary at exactly 0.3
```

### Why average latency lies

```text
100 requests: 99 took 10ms, 1 took 5s
average = (99*0.01 + 5) / 100 = 59ms      "looks fine!"
p99     = 5s                              "one user waited 5 seconds"
```

Averages hide exactly the users who are suffering. Alert on percentiles.

### And why you cannot average percentiles

```text
pod A p95 = 100ms
pod B p95 = 900ms
avg(p95)  = 500ms           <-- MEANINGLESS
```

p95 of the *fleet* requires merging the raw bucket counts first - which is
exactly why the `sum by (le)` goes **inside** `histogram_quantile`, never
outside it.

---

# 4. Summary

**Calculates quantiles in the client, at observation time.**

```text
http_request_duration_seconds{quantile="0.5"}   0.021
http_request_duration_seconds{quantile="0.9"}   0.230
http_request_duration_seconds{quantile="0.99"}  1.100
http_request_duration_seconds_sum               183.4
http_request_duration_seconds_count             1400
```

| | Histogram | Summary |
|---|---|---|
| Quantile computed | at query time, in Prometheus | at observation time, in the app |
| Aggregatable across pods | **yes** | **no** |
| Pick quantiles later | yes | no - fixed at compile time |
| Cost | more series | more CPU in the app |

```text
Rule of thumb: use a HISTOGRAM.
Summaries cannot be aggregated across instances, which in Kubernetes
(where you always have N replicas) makes them nearly useless.
```

### Native histograms

Newer Prometheus versions support *native histograms*: exponential buckets
stored in one series instead of one series per bucket. They solve the
cardinality cost and remove the "did I pick the right buckets?" problem.
Still opt-in at the time of writing, but this is where the ecosystem is going.

---

# Naming Rules

```text
<namespace>_<subsystem>_<name>_<unit>[_total]

http_requests_total                 counter, note the _total
http_request_duration_seconds       histogram, base unit = seconds
node_memory_MemAvailable_bytes      base unit = bytes
process_cpu_seconds_total           counter of CPU-seconds
```

```text
ALWAYS use base units:  seconds, bytes, ratios (0-1)
NEVER:                  milliseconds, megabytes, percentages

Why? So `rate()` and arithmetic across metrics just work, and so Grafana
can format the unit for display.
```

---

# The Cardinality Trap

Cardinality = the number of distinct time series a metric produces.

```text
series = (values of label 1) x (values of label 2) x ...
```

A reasonable metric:

```text
method (4) x path (20) x status (5) = 400 series.   Fine.
```

A disaster:

```python
REQUESTS.labels(user_id=user.id).inc()        # 2 million users
REQUESTS.labels(path=request.url.path).inc()  # /order/8f3a..., unbounded
```

```text
400 x 2,000,000 = 800,000,000 series
-> Prometheus eats all the RAM and is OOMKilled
-> this is THE classic production outage caused by monitoring
```

### The rule

```text
Never use as a label:
  user id, email, session id, request id, trace id,
  raw URL containing an id, full error message, timestamp

Those belong in LOGS and TRACES, not in metrics.
```

This is why the demo app records the route **template**:

```python
route = request.scope.get("route")
path = route.path if route else "unmatched"   # "/items/{id}", never "/items/42"
```

### Find your worst offenders

```promql
topk(10, count by (__name__)({__name__=~".+"}))     # biggest metrics
prometheus_tsdb_head_series                         # total active series
scrape_samples_scraped                              # samples per target
```

---

# Key Takeaways

```text
1. Counter  -> only goes up      -> always wrap in rate()
2. Gauge    -> goes up and down  -> query directly
3. Histogram-> buckets           -> histogram_quantile(..., sum by (le) (rate(...)))
4. Summary  -> client quantiles  -> cannot aggregate; avoid in Kubernetes
5. Base units, _total suffix, low cardinality. Always.
```

---

# Interview Questions

**Q: Histogram or Summary?**
Histogram, because its buckets can be summed across pods and the quantile is
computed at query time. A summary's quantiles are pre-computed per instance
and mathematically cannot be merged.

**Q: Why `rate()` and not `increase()` or the raw counter?**
The raw counter is a meaningless rising line. `rate()` gives a per-second
average and correctly handles counter resets on restart. `increase()` is just
`rate() * range` and is fine for "how many in the last hour" panels.

**Q: What is cardinality and why does it matter?**
Cardinality is the number of distinct label combinations. Prometheus holds
every active series in memory, so an unbounded label (user id, request id)
multiplies series count until the server OOMs.

**Q: Why is p95 latency better than average latency?**
The average is dominated by the many fast requests and hides the tail. p95/p99
describes what your slowest real users actually experience.
