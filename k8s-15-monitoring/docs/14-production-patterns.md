# 14 - Monitoring in Production

---

# Learning Objectives

* A production checklist you can actually run through
* Securing Prometheus and Grafana
* Meta-monitoring: who watches the watchman
* Debugging recipes for the failures you will actually hit
* Common mistakes, ranked by how often they happen

---

# The Checklist

```text
COLLECTION
[ ] Prometheus runs as a StatefulSet with a PVC on SSD
[ ] retention.time AND retention.size both set
[ ] resource requests and limits set (memory limit = OOM protection)
[ ] scrape_interval consistent (15s or 30s) across jobs
[ ] cardinality reviewed: topk(10, count by (__name__)({__name__=~".+"}))
[ ] metric_relabel_configs drop the metrics nobody queries

INSTRUMENTATION
[ ] every service exposes RED metrics
[ ] route templates used as labels, never raw URLs
[ ] base units everywhere (seconds, bytes)
[ ] a histogram bucket boundary sits exactly on each latency SLO
[ ] no user ids, request ids or emails in labels

ALERTING
[ ] every alert has `for:`, a severity label and a runbook_url
[ ] alerts fire on symptoms; resource alerts are warnings, not pages
[ ] Alertmanager grouping tuned - no 60-message storms
[ ] routing tested with amtool / the /api/v2/alerts endpoint
[ ] a DeadMansSwitch alert exists and is wired to an external checker
[ ] alert rules unit-tested with promtool test rules

DASHBOARDS
[ ] dashboard JSON in git, provisioned from files
[ ] datasource uid pinned
[ ] units and thresholds on every panel
[ ] symptoms above causes
[ ] one "service overview" dashboard per service, linked from the alert

OPERATIONS
[ ] Prometheus itself is monitored (by something else)
[ ] Alertmanager clustered with 3 replicas
[ ] Grafana has real auth (OIDC/SAML), not admin/admin
[ ] config changes go through git and CI (promtool check in CI)
[ ] an on-call runbook exists for each critical alert
```

---

# Security

Nothing in this project is secured - it is a lab. Production differs on every
line.

### Do not expose Prometheus

```text
Prometheus has NO authentication and NO authorisation. None.

Anyone who can reach :9090 can read every metric in your cluster, run
expensive queries that OOM it, and - with --web.enable-lifecycle -
POST /-/reload.
```

Options, best first:

```text
1. ClusterIP only + `kubectl port-forward` for humans.
2. Ingress with an auth proxy in front (oauth2-proxy, Pomerium) and TLS.
3. NetworkPolicy so only Grafana's pods can reach port 9090.
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-ingress
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: grafana
    ports:
    - port: 9090
```

Drop `--web.enable-lifecycle` in production and use a config-reloader sidecar
instead, so no HTTP caller can trigger a reload.

### Grafana

```text
[ ] admin password from a Secret, never a default
[ ] OIDC/SAML SSO; disable local signup (GF_USERS_ALLOW_SIGN_UP=false)
[ ] Viewer role by default; Editor only where needed
[ ] GF_SECURITY_COOKIE_SECURE=true behind TLS
[ ] datasource credentials in a Secret, referenced by file
```

### RBAC

The ClusterRole in this project is already minimal: `get/list/watch` on
discovery objects. Keep it that way. Prometheus never needs write access to
anything.

---

# Meta-Monitoring

```text
Who alerts you when the alerting is broken?
```

Prometheus failing silently is the worst failure mode in monitoring: the
dashboards are green because nothing is being measured.

### 1. Monitor Prometheus with Prometheus

```promql
# Rule evaluation falling behind
prometheus_rule_group_last_duration_seconds
  > prometheus_rule_group_interval_seconds

# Scrapes being dropped because the target is too slow
prometheus_target_scrapes_exceeded_sample_limit_total

# Could not reach Alertmanager
rate(prometheus_notifications_errors_total[5m]) > 0

# TSDB cannot compact
increase(prometheus_tsdb_compactions_failed_total[1h]) > 0

# Config reload failed - your last change is NOT live
prometheus_config_last_reload_successful == 0
```

That last one deserves its own critical alert. A failed reload means
Prometheus is quietly running yesterday's config.

### 2. The Dead Man's Switch

An alert that is **always firing**, deliberately:

```yaml
- alert: DeadMansSwitch
  expr: vector(1)
  labels:
    severity: none
  annotations:
    summary: "Alerting pipeline is alive"
```

Route it to an external service (Healthchecks.io, Dead Man's Snitch, Grafana
Cloud) that pages you when it **stops** arriving. That inverts the logic:
silence becomes the signal.

```text
This is the single highest-value alert in any monitoring stack, and the
one most teams forget.
```

### 3. Blackbox probing from outside

```yaml
- job_name: blackbox
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
  - targets:
    - https://api.example.com/health
  relabel_configs:
  - source_labels: [__address__]
    target_label: __param_target
  - source_labels: [__param_target]
    target_label: instance
  - target_label: __address__
    replacement: blackbox-exporter:9115
```

Internal metrics say "all my pods are healthy". A blackbox probe says "a user
on the internet can actually reach us" - which is the thing that matters when
DNS, the load balancer or a certificate breaks.

---

# Debugging Recipes

### "A target is missing"

```text
Status -> Service Discovery    is it discovered at all?
  no  -> RBAC: kubectl auth can-i list pods \
           --as=system:serviceaccount:monitoring:prometheus
  yes -> a keep rule dropped it. Check the annotation is on
         spec.template.metadata.annotations and quoted as a STRING.
```

### "A target is DOWN (red)"

```bash
# Read the exact error in Status -> Targets, then reproduce it:
kubectl run curl --rm -it --image=curlimages/curl --restart=Never -n monitoring \
  -- curl -sv http://10.1.0.42:8000/metrics
```

```text
connection refused  -> wrong port
404                 -> wrong path
context deadline    -> app too slow; raise scrape_timeout or fix the app
x509 / tls          -> scheme mismatch
```

### "Prometheus is OOMKilled"

```promql
prometheus_tsdb_head_series                                # how bad?
topk(10, count by (__name__)({__name__=~".+"}))            # what is big?
topk(10, scrape_samples_scraped)                           # who sends it?
```

Then drop with `metric_relabel_configs`, fix the label at the source, and
raise the memory limit as a stopgap - not a fix.

### "A query is slow or times out"

```text
* Shorten the time range first - confirm it is data volume, not the query.
* Replace the expression with a recording rule.
* Check for a regex over a high-cardinality label.
* Look at Status -> TSDB Status for the biggest label dimensions.
* Avoid subqueries in dashboard panels.
```

### "An alert did not fire"

```bash
# Is the rule even loaded?
#   UI -> Status -> Rules; look for an evaluation error.

# Does the expression return anything right now?
#   Paste the expr into the graph UI.

# Did it reach Alertmanager?
kubectl exec -n monitoring deploy/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts'

# Is it silenced or inhibited?
#   Alertmanager UI -> Silences.

# Did routing swallow it?
#   An unmatched route, or a route to a "null" receiver.
```

### "Grafana shows No Data"

```text
1. Run the same query in Prometheus directly. Empty there too?
   -> it is a data problem, not Grafana.
2. Datasource uid mismatch after an import.
3. The dashboard time range predates your retention.
4. A template variable resolved to nothing, so the selector matches nothing.
```

---

# Common Mistakes, Ranked

```text
1.  High-cardinality labels (user id, request id, raw URL)
    -> Prometheus OOMs. The #1 monitoring outage, by a wide margin.

2.  Alerting on causes instead of symptoms
    -> alert fatigue, then missed incidents.

3.  No `for:` clause
    -> paged at 3am by a 10-second blip.

4.  Averaging latency
    -> the tail your users feel is invisible.

5.  Graphing a raw counter
    -> a line that only goes up, telling you nothing.

6.  rate() window shorter than 4 scrape intervals
    -> gaps and NaN.

7.  emptyDir storage
    -> all history lost on every restart.

8.  Dashboards only in the Grafana UI
    -> gone with the Pod; no review, no history.

9.  No Dead Man's Switch
    -> monitoring dies silently and nobody knows.

10. Prometheus exposed without auth
    -> every internal metric readable, and trivially DoS-able.
```

---

# Where This Fits in the Roadmap

```text
Project 05  HPA              scales on metrics-server; prometheus-adapter
                             lets it scale on YOUR metrics instead
Project 11  Resources        requests/limits are what the saturation
                             panels in this project measure against
Project 12  Health probes    readiness drives `up`; probe failures show up
                             as targets flapping
Project 14  ArgoCD           dashboards, rules and alerts are YAML - they
                             belong in git and should deploy via GitOps
Project 16  Logging          metrics say THAT something broke; logs say WHY
Project 17  Platform         observability is a platform service, not a
                             per-team afterthought
```

---

# Key Takeaways

```text
1. Prometheus has no auth. Keep it ClusterIP, or put a proxy in front.
2. Monitor the monitoring - especially
   prometheus_config_last_reload_successful.
3. Ship a Dead Man's Switch to an external checker. Silence is the signal.
4. Blackbox-probe from outside; internal health is not user-visible health.
5. Most production monitoring failures are cardinality or alert fatigue.
6. Everything here is YAML. Put it in git and deploy it like code.
```

---

# Interview Questions

**Q: How do you secure Prometheus?**
It has no built-in auth, so keep it on a ClusterIP, restrict it with a
NetworkPolicy, and put an authenticating reverse proxy in front of any
external access. Drop `--web.enable-lifecycle` and use a reloader sidecar.

**Q: How do you know your monitoring itself is working?**
Meta-monitoring: scrape Prometheus' own metrics (failed reloads, notification
errors, rule evaluation delays), plus an always-firing Dead Man's Switch
routed to an external service that alerts on its absence.

**Q: Your Prometheus keeps getting OOMKilled. Walk me through it.**
Check `prometheus_tsdb_head_series`, find the biggest metrics with
`topk(10, count by (__name__)(...))` and the worst targets with
`scrape_samples_scraped`, drop them with `metric_relabel_configs`, then fix
the offending label at the source.

**Q: What is a Dead Man's Switch?**
An alert that always fires, routed to an external watchdog which pages you
when the notifications stop - catching the case where the whole alerting
pipeline is down.

**Q: Why not alert on CPU usage?**
Because high CPU is a cause, not a symptom. Alerting on it pages for harmless
load while missing outages that use little CPU. Alert on errors and latency;
keep CPU as a capacity warning.
