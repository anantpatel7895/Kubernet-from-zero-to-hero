# 12 - Golden Signals, SLOs and Error Budgets

---

# Learning Objectives

* The four Golden Signals, and the RED and USE methods
* SLI vs SLO vs SLA
* Calculating an error budget
* Burn-rate alerting - the technique that replaces threshold alerting
* What to actually put on your first dashboard

---

# The Four Golden Signals

From Google's SRE book. If you measure only four things, measure these:

```text
1. LATENCY     How long does a request take?
               Measure successful and failed requests SEPARATELY - a fast
               500 would otherwise flatter your latency graph.

2. TRAFFIC     How much demand is there?
               requests/sec, messages/sec, concurrent sessions.

3. ERRORS      What fraction of requests fail?
               Explicit (HTTP 500), implicit (200 with the wrong body),
               and policy failures (served, but took 10s when you promised 1s).

4. SATURATION  How full is the system?
               The resource closest to its limit - queue depth, memory,
               connection pool, disk. The leading indicator of the other three.
```

```promql
# Latency
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))

# Traffic
sum(rate(http_requests_total[5m]))

# Errors
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Saturation
sum(http_requests_in_progress)
max(container_memory_working_set_bytes / kube_pod_container_resource_limits{resource="memory"})
```

---

# RED and USE

Two shorthand methods that map onto the Golden Signals.

### RED - for services (things that handle requests)

```text
Rate       requests per second
Errors     failed requests per second
Duration   latency distribution
```

### USE - for resources (things that have capacity)

```text
Utilisation  % of time the resource was busy
Saturation   how much work is queued waiting for it
Errors       error events
```

```text
For every SERVICE  -> RED
For every RESOURCE -> USE

CPU:    utilisation = non-idle %, saturation = run queue length
Memory: utilisation = used/total,  saturation = swap/page-fault rate
Disk:   utilisation = io_time,     saturation = io queue depth
Network:utilisation = bytes/capacity, saturation = drops
```

---

# SLI, SLO, SLA

```text
SLI  Service Level INDICATOR
     A measurement.              "99.3% of requests succeeded this week"

SLO  Service Level OBJECTIVE
     Your internal target.       "99.5% of requests must succeed"

SLA  Service Level AGREEMENT
     A contract with money.      "below 99% and you get a 10% refund"
```

```text
SLA < SLO always.

Your internal target must be stricter than the contract, so you find out
you are in trouble before the customer's lawyer does.
```

### Writing an SLI properly

Vague:

```text
"The API should be fast and reliable."
```

Precise:

```text
Availability SLI:
  proportion of HTTP requests to /api/* that return a non-5xx status,
  measured at the load balancer, over a rolling 30 days.
  Target: 99.9%

Latency SLI:
  proportion of HTTP requests to /api/* served in under 300ms,
  measured at the load balancer, over a rolling 30 days.
  Target: 99%
```

```text
Every SLI names: WHAT is counted, WHERE it is measured, over WHAT WINDOW.
```

In PromQL:

```promql
# Availability SLI over 30 days
sum(rate(http_requests_total{status!~"5.."}[30d]))
  /
sum(rate(http_requests_total[30d]))

# Latency SLI: fraction under 300ms (needs a bucket boundary at 0.3)
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[30d]))
  /
sum(rate(http_request_duration_seconds_count[30d]))
```

---

# Error Budgets

```text
SLO 99.9%  ->  error budget = 0.1% of requests may fail
```

Over 30 days:

| SLO | Allowed downtime per 30 days |
|---|---|
| 99%     | 7h 12m |
| 99.5%   | 3h 36m |
| 99.9%   | 43m 12s |
| 99.95%  | 21m 36s |
| 99.99%  | 4m 19s |
| 99.999% | 26s |

```text
Each extra nine costs roughly 10x more engineering effort.
99.999% means you cannot even deploy during business hours.
Pick the number the business actually needs - not the most nines.
```

### What the budget is FOR

The budget is not a failure allowance to feel bad about. It is a **decision
tool**:

```text
Budget remaining  -> ship features, take risks, deploy on Friday
Budget exhausted  -> freeze features, spend the sprint on reliability
```

It converts an argument ("is the system reliable enough?") into arithmetic.

```promql
# Budget consumed this month, as a fraction of the 0.1% allowance
(
  sum(rate(http_requests_total{status=~"5.."}[30d]))
    /
  sum(rate(http_requests_total[30d]))
) / 0.001
```

```text
0.4  -> 40% of the budget used. Fine.
1.0  -> budget gone. Freeze.
```

---

# Burn-Rate Alerting

Threshold alerting has a built-in dilemma:

```text
"error rate > 5% for 2m"

Too sensitive -> pages for a 2-minute blip nobody noticed.
Too lenient   -> a slow 1% leak burns the whole month's budget silently.
```

Burn rate fixes this by asking a different question: **how fast are we
consuming the error budget?**

```text
burn rate = observed error rate / error budget rate

SLO 99.9% -> budget = 0.001

error rate 0.001 -> burn rate 1  -> budget lasts exactly 30 days
error rate 0.01  -> burn rate 10 -> budget gone in 3 days
error rate 0.10  -> burn rate 100-> budget gone in 7 hours
```

### Multi-window, multi-burn-rate

The Google SRE recommendation: pair a long window with a short one so you
alert fast on catastrophes and slowly on leaks, without false positives.

```yaml
# Page: 2% of the 30-day budget burned in 1 hour
- alert: ErrorBudgetBurnFast
  expr: |
    (
      sum(rate(http_requests_total{status=~"5.."}[1h]))
        / sum(rate(http_requests_total[1h]))
    ) > (14.4 * 0.001)
    and
    (
      sum(rate(http_requests_total{status=~"5.."}[5m]))
        / sum(rate(http_requests_total[5m]))
    ) > (14.4 * 0.001)
  for: 2m
  labels:
    severity: critical

# Ticket: 10% of the budget burned in 3 days
- alert: ErrorBudgetBurnSlow
  expr: |
    (
      sum(rate(http_requests_total{status=~"5.."}[6h]))
        / sum(rate(http_requests_total[6h]))
    ) > (6 * 0.001)
    and
    (
      sum(rate(http_requests_total{status=~"5.."}[30m]))
        / sum(rate(http_requests_total[30m]))
    ) > (6 * 0.001)
  for: 15m
  labels:
    severity: warning
```

```text
The `and` with the short window is what stops an alert from firing on an
incident that already ended an hour ago - the long window is still elevated,
but the short one has recovered, so the alert resolves immediately.

Standard pairs:
  14.4x over 1h  + 5m    -> page   (2% of budget in 1 hour)
  6x    over 6h  + 30m   -> page   (5% in 6 hours)
  3x    over 1d  + 2h    -> ticket (10% in 1 day)
  1x    over 3d  + 6h    -> ticket (10% in 3 days)
```

Why 14.4? Burning 2% of a 30-day budget in 1 hour means consuming budget
`0.02 * 30 * 24 / 1 = 14.4` times faster than the sustainable rate.

---

# Your First Dashboard

If you are starting from nothing, build exactly this:

```text
Row 1 - Is the service healthy? (SYMPTOMS)
  [ Request rate by status ]  [ Error ratio ]  [ p95 latency ]

Row 2 - Where is it unhealthy?
  [ Rate by endpoint ]  [ Latency by endpoint ]  [ Errors by endpoint ]

Row 3 - Why? (CAUSES)
  [ CPU per pod ]  [ Memory per pod ]  [ Restarts ]  [ Replica count ]
```

Then one row per downstream dependency (database, cache, queue). That is the
dashboard in `dashboards/metrics-app.json`, and it answers the questions an
incident actually raises, in the order it raises them.

---

# Key Takeaways

```text
1. Four Golden Signals: latency, traffic, errors, saturation.
2. RED for services, USE for resources.
3. SLI = measurement, SLO = internal target, SLA = contract. SLA < SLO.
4. Error budget = 1 - SLO. It is a decision tool, not a punishment.
5. Burn-rate alerting beats static thresholds: fast pages for disasters,
   tickets for slow leaks, and far fewer false positives.
6. Symptoms above causes, on every dashboard.
```

---

# Interview Questions

**Q: What are the Golden Signals?**
Latency, traffic, errors and saturation - the four measurements that
characterise any request-serving system.

**Q: SLI vs SLO vs SLA?**
The SLI is the measured value, the SLO is the internal target for it, and the
SLA is a contractual commitment with consequences. The SLO is always stricter
than the SLA.

**Q: What is an error budget and how do you use it?**
`1 - SLO`, expressed as the allowed proportion of failures. While the budget
remains you ship features; when it is exhausted you freeze and spend the
effort on reliability.

**Q: Why is burn-rate alerting better than a fixed error-rate threshold?**
It ties the alert to how fast you are consuming the reliability you promised,
so a short harmless blip does not page, while a sustained low-level failure
does. The multi-window form also resolves quickly once the incident ends.

**Q: Why is 99.999% a bad default target?**
It allows 26 seconds of failure a month, costs enormously more to achieve, and
rules out routine operations like deploying during the day. Pick the SLO the
business needs.
