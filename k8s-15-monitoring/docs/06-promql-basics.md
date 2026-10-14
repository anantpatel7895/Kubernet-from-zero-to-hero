# 06 - PromQL

---

# Learning Objectives

* Instant vectors vs range vectors
* Selectors and label matchers
* rate, irate, increase - and when each is wrong
* Aggregation with `by` and `without`
* Binary operators and vector matching
* The queries you will actually use every day

---

# Two Data Types You Must Keep Straight

### Instant vector - one value per series, at one moment

```promql
http_requests_total
```

```text
http_requests_total{pod="app-1", status="200"}  4821   @ now
http_requests_total{pod="app-2", status="200"}  4790   @ now
http_requests_total{pod="app-1", status="500"}    37   @ now
```

### Range vector - a window of values per series

```promql
http_requests_total[5m]
```

```text
http_requests_total{pod="app-1", status="200"}
    4700 @ 09:55:00
    4745 @ 09:55:15
    4780 @ 09:55:30
    ...
```

```text
You CANNOT graph a range vector.
It is raw material for a function like rate() or avg_over_time().

  http_requests_total[5m]           -> error in a graph panel
  rate(http_requests_total[5m])     -> a number. graphable.
```

---

# Selectors

```promql
http_requests_total                              # everything
http_requests_total{status="500"}                # exact match
http_requests_total{status!="200"}               # not equal
http_requests_total{status=~"5.."}               # regex match
http_requests_total{status!~"2..|3.."}           # regex not-match
http_requests_total{namespace="monitoring", path="/work"}   # AND
```

```text
=   equals          !=   not equals
=~  regex matches   !~   regex does not match

Regexes are fully anchored: `5..` means `^5..$`.
```

The metric name is itself a label:

```promql
{__name__=~"http_request.*", status="500"}
```

### Offset and @

```promql
http_requests_total offset 1h          # value as of one hour ago
rate(http_requests_total[5m] offset 1w)   # same time last week
```

---

# rate, irate, increase

All three take a **range vector** over a **counter**.

```promql
rate(http_requests_total[5m])
```

```text
rate     = per-second average over the whole window
           smooth; the default choice; what you use in alerts
irate    = per-second rate using only the LAST TWO samples
           spiky; for fast-moving dashboards only, never for alerts
increase = total growth over the window = rate * window_seconds
           for "how many errors in the last hour" panels
```

```text
rate(http_requests_total[5m])      -> 3.2 requests/second
increase(http_requests_total[1h])  -> 11,520 requests
```

### The window rule

```text
The range MUST cover at least 4 scrape intervals.

scrape_interval = 15s  ->  use [1m] minimum, [5m] in practice.

Too short -> gaps and NaN when one scrape is slow or missed.
Too long  -> real spikes get smoothed into invisibility.
```

### rate() on a gauge is a bug

```promql
rate(app_queue_depth[5m])      # WRONG - nonsense output
deriv(app_queue_depth[5m])     # if you really want slope
delta(app_queue_depth[5m])     # change across the window
```

`rate()` assumes any decrease is a counter reset, so on a gauge it silently
produces garbage instead of an error.

---

# Aggregation

```promql
sum(rate(http_requests_total[5m]))                    # one number for everything
sum by (status) (rate(http_requests_total[5m]))       # one line per status
sum without (pod) (rate(http_requests_total[5m]))     # merge pods, keep the rest
```

```text
by      -> KEEP only these labels
without -> keep everything EXCEPT these labels
```

Operators: `sum, min, max, avg, count, stddev, stdvar, topk, bottomk,
quantile, count_values, group`.

```promql
topk(5, sum by (pod) (rate(http_requests_total[5m])))   # 5 busiest pods
count(up{job="kubernetes-pods"} == 1)                   # healthy targets
count by (namespace) (kube_pod_info)                    # pods per namespace
```

### Order matters: always aggregate the rate, never rate the aggregate

```promql
sum(rate(http_requests_total[5m]))     # CORRECT
rate(sum(http_requests_total)[5m:])    # WRONG
```

Summing first destroys per-series counter-reset information. When one pod
restarts, the summed counter drops and the second form reports a wrong,
often negative, value.

---

# The Queries You Will Actually Use

### Request rate

```promql
sum by (path) (rate(http_requests_total[5m]))
```

### Error ratio

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))
```

Division where the denominator can be zero gives `NaN`. Guard it:

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
clamp_min(sum(rate(http_requests_total[5m])), 1e-10)
```

### Latency percentile

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

### Average latency (when you really do want the mean)

```promql
rate(http_request_duration_seconds_sum[5m])
  /
rate(http_request_duration_seconds_count[5m])
```

### CPU per pod, in cores

```promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="monitoring", container!=""}[5m])
)
```

`container_cpu_usage_seconds_total` counts CPU-seconds, so its per-second rate
*is* the number of cores in use. `0.25` = 250m.

### Memory per pod

```promql
sum by (pod) (
  container_memory_working_set_bytes{namespace="monitoring", container!=""}
)
```

Use `working_set`, not `container_memory_usage_bytes` - the latter includes
reclaimable page cache and will have you chasing phantom leaks. The working
set is what the OOM killer actually looks at.

### How close is a container to its memory limit?

```promql
container_memory_working_set_bytes{container!=""}
  /
kube_pod_container_resource_limits{resource="memory"}
```

This is a **vector match**: the two metrics come from different sources
(cAdvisor and kube-state-metrics) and Prometheus pairs the series that share
identical labels on both sides.

### Is my CPU being throttled?

```promql
rate(container_cpu_cfs_throttled_periods_total[5m])
  /
rate(container_cpu_cfs_periods_total[5m])
```

Anything sustained above ~0.25 means the CPU limit is hurting you. (Project 11
covered why.)

### Pod restarts

```promql
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

### Node CPU utilisation

```promql
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))
```

There is no "cpu used" metric - you measure idle and subtract.

### Node disk about to fill

```promql
node_filesystem_avail_bytes{mountpoint="/"}
  /
node_filesystem_size_bytes{mountpoint="/"} < 0.10
```

### Deployment not at full strength

```promql
kube_deployment_status_replicas_available
  <
kube_deployment_spec_replicas
```

---

# Vector Matching

When two instant vectors meet, Prometheus pairs series with **identical label
sets**. Series that find no partner vanish from the result - which is why a
query can mysteriously return nothing.

### ignoring / on

```promql
# Only match on these labels:
a / on(pod, namespace) b

# Match on everything EXCEPT these:
a / ignoring(instance) b
```

### group_left - many-to-one

```promql
container_memory_working_set_bytes
  / on(namespace, pod, container)
  group_left
kube_pod_container_resource_limits{resource="memory"}
```

```text
group_left  -> the LEFT side has many series per right-side series
group_right -> the other way round
```

The classic use is attaching metadata from an info metric:

```promql
sum by (pod) (rate(http_requests_total[5m]))
  * on(pod) group_left(version) app_info
```

---

# Subqueries

Run a query over a range, then aggregate the result:

```promql
max_over_time( rate(http_requests_total[5m])[1h:1m] )
```

```text
[1h:1m]  -> evaluate the inner expression every 1m, over the last 1h
```

Powerful, and expensive. Prefer a recording rule (doc 07) if you need it often.

---

# Functions Worth Remembering

```text
Over time:    avg_over_time, max_over_time, min_over_time,
              sum_over_time, count_over_time, stddev_over_time,
              last_over_time, present_over_time

Counters:     rate, irate, increase, resets

Gauges:       delta, deriv, idelta, predict_linear, changes

Math:         abs, ceil, floor, round, clamp_min, clamp_max, sgn,
              ln, log2, log10, exp, sqrt

Time:         time(), timestamp(), day_of_week(), hour()

Labels:       label_replace, label_join

Sorting:      sort, sort_desc
Missing data: absent, absent_over_time
```

Two that save you in real incidents:

```promql
# "Will the disk be full within 4 hours?" - based on the last 6h trend
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 4*3600) < 0

# "This metric has disappeared entirely" - you cannot alert on a missing
# series with ==, because there is nothing to compare.
absent(up{job="metrics-app"})
```

---

# Key Takeaways

```text
1. Instant vector vs range vector. Only instant vectors are graphable.
2. rate() for alerts and dashboards; irate() only for fast graphs;
   increase() for totals.
3. Range window >= 4 scrape intervals. [5m] with a 15s interval.
4. sum(rate(x)) - never rate(sum(x)).
5. Use working_set for memory, idle-subtraction for node CPU.
6. Binary ops need matching label sets; that is what on/ignoring/group_left
   are for.
```

---

# Interview Questions

**Q: Difference between rate and irate?**
`rate` averages across the whole window, giving a smooth line suitable for
alerting. `irate` uses only the last two samples, which is responsive but
jumpy - never use it in an alert rule.

**Q: Why is `rate(sum(...))` wrong?**
Summing merges series and loses per-series reset detection, so a single pod
restart corrupts the result. Always `sum(rate(...))`.

**Q: How do you compute a 95th percentile?**
`histogram_quantile(0.95, sum by (le) (rate(metric_bucket[5m])))`. The
`by (le)` is mandatory.

**Q: Your division query returns no data. Why?**
The two sides have different label sets, so no series match. Use
`on(...)`/`ignoring(...)` to control matching, and `group_left` for
many-to-one joins.

**Q: How do you alert that a target vanished entirely?**
`absent(up{job="x"})` - a comparison cannot fire on a series that does not
exist.
