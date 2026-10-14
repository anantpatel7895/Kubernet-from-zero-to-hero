# 07 - Recording and Alerting Rules

---

# Learning Objectives

* What a recording rule is and when it pays for itself
* The `level:metric:operation` naming convention
* Alert rule anatomy: expr, for, labels, annotations
* Why `for:` is the most important field in the file
* The alert lifecycle: inactive -> pending -> firing
* Alerting on symptoms, not causes

---

# Recording Rules

A recording rule evaluates an expression on a schedule and **stores the result
as a new metric**.

```yaml
- record: job:http_error_ratio:rate5m
  expr: |
    job:http_errors:rate5m
      /
    clamp_min(job:http_requests:rate5m, 1e-10)
```

Why bother:

```text
1. Speed. A dashboard panel over 30 days re-computes the same expensive
   expression every refresh. A recording rule computes it once per
   evaluation_interval; the panel reads a single cheap series.

2. Consistency. The dashboard, the alert and the SLO report all read the
   SAME definition of "error ratio". No drift between three copies of a
   subtly different query.

3. Composability. Rules can build on other rules - as above, where the
   ratio is built from two previously recorded series.
```

### Naming convention

```text
level:metric:operations

job:http_requests:rate5m
 │        │         └── what was done to it
 │        └──────────── the underlying metric
 └───────────────────── the labels it is aggregated to
```

The colons are the signal: **a name with colons is a recording rule, a name
without them is raw**. Never use colons in metrics your app exports.

### Evaluation order

Rules inside one group run **sequentially, in file order**. Rules in different
groups run in parallel and may see stale inputs.

```text
If rule B depends on rule A, put them in the SAME group, A first.
```

### When not to use one

```text
Don't pre-record something you query twice a week. Each rule is another
series written every evaluation_interval, forever. Rules have a cost too.
```

---

# Alerting Rules

```yaml
- alert: HighErrorRate
  expr: job:http_error_ratio:rate5m > 0.05
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "High 5xx error rate on {{ $labels.job }}"
    description: "{{ $labels.job }} is serving {{ $value | humanizePercentage }} errors."
```

| Field | Role |
|---|---|
| `alert` | the name; becomes `alertname` |
| `expr` | fires for every series the expression returns |
| `for` | how long the condition must hold continuously |
| `labels` | attached to the alert; **used for routing** in Alertmanager |
| `annotations` | human text; **not** used for routing or identity |

```text
An alert fires ONCE PER RETURNED SERIES.

  expr: up == 0

With 40 targets down, that is 40 alerts. Grouping in Alertmanager is what
turns them into one notification.
```

---

# The Lifecycle

```text
      expr is false              expr true,        expr true,
                                 for: not elapsed  for: elapsed
   ┌─────────────┐             ┌──────────────┐  ┌──────────────┐
   │  INACTIVE   │────────────►│   PENDING    │─►│    FIRING    │──► Alertmanager
   └─────────────┘             └──────────────┘  └──────────────┘
          ▲                            │                 │
          └────────────────────────────┴─────────────────┘
                     expr becomes false at any point
```

Prometheus exposes this as a metric you can query:

```promql
ALERTS{alertname="HighErrorRate", alertstate="firing"}
ALERTS_FOR_STATE{alertname="HighErrorRate"}    # when it went pending
```

The smoke test uses exactly that query to prove the alert fired.

### Why `for:` matters so much

```yaml
expr: up == 0
# no for:
```

One slow scrape, one rolling restart, one 2-second network blip -> you get
paged at 03:00 for something that fixed itself.

```yaml
expr: up == 0
for: 3m
```

Now the condition must hold across ~12 consecutive evaluations.

```text
Rule of thumb:
  for: 2m-5m   for fast-moving symptoms (errors, latency)
  for: 10m-30m for slow burns (disk filling, memory creeping)
  for: 0       almost never - reserve it for "the building is on fire"
```

The cost is detection delay: `for: 5m` means you learn about an outage five
minutes late. That is the trade you are making, consciously.

---

# Templating

Annotations are Go templates evaluated per firing series:

```text
{{ $labels.pod }}              a label from the series
{{ $labels.namespace }}
{{ $value }}                   the numeric value that triggered it
{{ $value | humanize }}        1.2345e+06  -> 1.234M
{{ $value | humanizePercentage }}  0.0734  -> 7.34%
{{ $value | humanizeDuration }}    1.5     -> 1.5s
{{ $value | printf "%.2f" }}
```

Write annotations for the person woken up by them:

```yaml
annotations:
  summary: "{{ $labels.namespace }}/{{ $labels.pod }} near memory limit"
  description: >-
    Working set is {{ $value | humanizePercentage }} of the limit.
    OOMKill is likely. Check recent deploys, then either raise the limit
    or find the leak.
  runbook_url: "https://wiki.internal/runbooks/pod-memory"
  dashboard_url: "https://grafana.internal/d/metrics-app"
```

```text
A good alert tells you: what broke, how bad, and what to do next.
A bad alert says: "HighMemory firing".
```

---

# Symptoms, Not Causes

```text
BAD   CPU above 80%
      -> so what? a healthy batch job pegs the CPU by design.
      -> wakes you up for something no user noticed.

GOOD  Error rate above 5% for 2 minutes
      -> users are being served errors right now.

GOOD  p95 latency above 1s for 5 minutes
      -> users are waiting.

GOOD  Checkout queue has not drained in 15 minutes
      -> orders are not being processed.
```

The test: **"if this fires and I do nothing, will a user notice?"**
If the answer is no, it is a dashboard panel, not an alert.

Resource alerts still have a place - but as *warnings* that feed capacity
planning, not as pages.

---

# Alert Fatigue

```text
An on-call engineer who gets 40 alerts a night stops reading them.
Then the one real alert is missed.
```

Rules that keep a rulebook healthy:

```text
1. Every alert must be ACTIONABLE. If the runbook says "check if it
   recovers", delete the alert.
2. Every alert needs a runbook link.
3. severity: critical = wake a human. warning = look at it tomorrow.
   info = dashboard only, routed to /dev/null in Alertmanager.
4. Review firing history monthly. Delete what nobody acted on.
5. Alert on the user-visible symptom; let the cause alerts be warnings.
```

---

# This Project's Rules

`k8s/prometheus-rules.yaml` contains two files:

### app.rules.yml

```text
Recording:
  job:http_requests:rate5m       total throughput
  job:http_errors:rate5m         5xx throughput
  job:http_error_ratio:rate5m    the SLI
  job:http_latency_p95:5m        latency SLI

Alerting:
  HighErrorRate   ratio > 5%        for 2m    critical
  HighLatency     p95 > 1s          for 2m    warning
  NoTraffic       rate == 0         for 10m   info
```

### kubernetes.rules.yml

```text
TargetDown                up == 0                        for 3m   critical
PodCrashLooping           >2 restarts in 10m             for 5m   critical
PodNotReady               Pending/Unknown                for 10m  warning
ContainerMemoryNearLimit  working_set / limit > 0.9      for 5m   warning
NodeHighCPU               non-idle > 85%                 for 10m  warning
```

`NoTraffic` deserves a note: a metric going to **zero** is often a worse
signal than a metric going high. No requests at all usually means a broken
Ingress, a bad DNS change, or a Service with no endpoints - complete outages
look like silence.

---

# Verifying Rules

```bash
# Syntax-check before applying
kubectl exec -n monitoring deploy/prometheus -- \
  promtool check rules /etc/prometheus/rules/app.rules.yml

# What rules are loaded, and are they evaluating?
#   UI -> Status -> Rules
#   watch "Last Evaluation" and "Evaluation Time"

# Which alerts are pending/firing right now?
#   UI -> Alerts
#   or:
kubectl exec -n monitoring deploy/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=ALERTS'
```

### Unit-testing alerts

`promtool` can test rules against synthetic data - alerts you can test are
alerts you can trust:

```yaml
# tests.yml
rule_files:
- app.rules.yml

evaluation_interval: 1m

tests:
- interval: 1m
  input_series:
  - series: 'http_requests_total{job="kubernetes-pods",status="500"}'
    values: '0+10x10'            # 10 errors per minute
  - series: 'http_requests_total{job="kubernetes-pods",status="200"}'
    values: '0+10x10'            # 10 successes per minute -> 50% errors

  alert_rule_test:
  - eval_time: 5m
    alertname: HighErrorRate
    exp_alerts:
    - exp_labels:
        severity: critical
        job: kubernetes-pods
```

```bash
promtool test rules tests.yml
```

---

# Key Takeaways

```text
1. Recording rules pre-compute expensive queries and give you ONE
   definition shared by dashboards and alerts.
2. Name them level:metric:operation - the colons mark them as derived.
3. `for:` turns a noisy condition into a trustworthy alert.
4. One alert fires PER SERIES; Alertmanager groups them.
5. Alert on symptoms users feel, with an actionable annotation and a
   runbook link.
6. promtool checks syntax AND unit-tests alert behaviour.
```

---

# Interview Questions

**Q: Why use recording rules?**
To pre-compute expensive expressions for fast dashboards, and to define an
expression once so alerts and dashboards cannot drift apart.

**Q: What does `for:` do?**
The condition must stay true for that duration before the alert moves from
pending to firing. It suppresses transient spikes and is the main defence
against alert fatigue.

**Q: Alert fires for 50 pods. How do you avoid 50 pages?**
Alertmanager `group_by` bundles them into one notification; inhibit rules can
suppress derived warnings when a related critical alert is already firing.

**Q: Should you alert on high CPU?**
Usually not as a page. Alert on the user-visible symptom (errors, latency) and
keep resource saturation as a warning for capacity planning.

**Q: How do you test an alert rule without breaking production?**
`promtool test rules` with synthetic `input_series` and expected alert output.
