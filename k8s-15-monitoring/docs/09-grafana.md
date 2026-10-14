# 09 - Grafana

---

# Learning Objectives

* What Grafana is - and what it is not
* Datasources and the `proxy` vs `direct` access modes
* Provisioning everything from files
* Panel types and when each is right
* Template variables
* Dashboard design that survives an incident

---

# Grafana Stores Nothing

```text
browser --> Grafana --> PromQL --> Prometheus --> TSDB
                                       │
                                  the only place
                                  data actually lives
```

Grafana holds dashboards, users and datasource configs in a small SQLite (or
Postgres) database. **No metrics.** Delete Grafana and you lose dashboards,
not data. That is why dashboards belong in git, not in a Pod's `emptyDir`.

---

# Datasources

`k8s/grafana-provisioning.yaml`:

```yaml
datasources:
- name: Prometheus
  type: prometheus
  uid: prometheus
  access: proxy
  url: http://prometheus.monitoring.svc.cluster.local:9090
  isDefault: true
  jsonData:
    timeInterval: 15s
```

### access: proxy vs direct

```text
proxy   -> the Grafana SERVER calls Prometheus.
           The browser never touches Prometheus.
           Works with in-cluster DNS. Credentials stay server-side.
           This is what you want, essentially always.

direct  -> the BROWSER calls Prometheus.
           Requires Prometheus to be publicly reachable and CORS-friendly.
           Deprecated in practice.
```

`url` uses in-cluster DNS:

```text
http://<service>.<namespace>.svc.cluster.local:<port>
http://prometheus.monitoring.svc.cluster.local:9090
```

`timeInterval` should match your `scrape_interval` so Grafana's `$__interval`
never produces a window smaller than your data.

### uid matters

The dashboard JSON refers to the datasource by `uid`, not by name. Pin it
(`uid: prometheus`) or an imported dashboard will point at a datasource that
does not exist and every panel will say "Datasource not found".

---

# Provisioning

Anything you click in the UI of a Pod with `emptyDir` storage dies with the
Pod. So configure from files:

```text
/etc/grafana/provisioning/datasources/*.yaml   where to read metrics from
/etc/grafana/provisioning/dashboards/*.yaml    where to load dashboards from
/var/lib/grafana/dashboards/*.json             the dashboards themselves
```

```yaml
providers:
- name: default
  folder: "Kubernetes"
  type: file
  updateIntervalSeconds: 30
  allowUiUpdates: true
  options:
    path: /var/lib/grafana/dashboards
```

The workflow this project uses:

```text
dashboards/metrics-app.json      the source of truth, in git
        │
        │  regenerate
        ▼
k8s/grafana-dashboards.yaml      a ConfigMap wrapping that JSON
        │
        │  mounted at /var/lib/grafana/dashboards
        ▼
Grafana picks it up within 30s
```

Regenerate after editing the JSON:

```bash
kubectl create configmap grafana-dashboard-metrics-app \
  --from-file=metrics-app.json=dashboards/metrics-app.json \
  -n monitoring --dry-run=client -o yaml > k8s/grafana-dashboards.yaml
```

```text
allowUiUpdates: true lets you edit in the browser while experimenting -
but the next ConfigMap sync overwrites your edits. The real workflow is:
edit in the UI -> "Share -> Export -> Save to file" -> commit the JSON.
```

### The sidecar pattern

`kube-prometheus-stack` runs a sidecar that watches for any ConfigMap labelled
`grafana_dashboard: "1"` in any namespace and drops its contents into
Grafana's dashboard directory. That is why this project's ConfigMap carries
that label - it is ready for that setup too.

---

# Panel Types

| Panel | Use it for |
|---|---|
| **Time series** | almost everything - rates, latency, usage over time |
| **Stat** | one big number: current error rate, uptime, total pods |
| **Gauge** | a value against a known maximum: % of memory limit used |
| **Bar gauge** | comparing a handful of series side by side |
| **Table** | a list: top 10 slowest endpoints, current alerts |
| **Heatmap** | a latency distribution over time, straight from histogram buckets |
| **State timeline** | up/down, deploy state - discrete states over time |
| **Logs** | Loki output next to the metric that made you look |

```text
A heatmap of http_request_duration_seconds_bucket shows the whole
distribution at once - you see a bimodal "some requests hit cache, some
don't" pattern that a p95 line completely hides.
```

### Thresholds

```json
"thresholds": {
  "steps": [
    { "color": "green",  "value": null },
    { "color": "orange", "value": 0.01 },
    { "color": "red",    "value": 0.05 }
  ]
}
```

Colour is information. A stat panel that is green at a glance saves the ten
seconds of reading a number during an incident.

### Units

Always set the unit (`reqps`, `s`, `bytes`, `percentunit`). Grafana then
formats `1536000` as `1.46 MiB` and `0.0734` as `7.34%` - and your base-unit
discipline from doc 03 pays off here.

---

# Template Variables

```json
{
  "name": "namespace",
  "type": "query",
  "query": "label_values(kube_pod_info, namespace)",
  "refresh": 1
}
```

Then use `$namespace` in every panel:

```promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m])
)
```

One dashboard, every namespace, via a dropdown.

```text
label_values(metric, label)       values of a label
label_values(label)               across all metrics (expensive)
query_result(<promql>)            when you need the value too

Multi-value variables render as a regex, so match with =~ :
  {pod=~"$pod"}

Built-ins:
  $__interval    a step size Grafana picks from the panel width
  $__rate_interval  safer for rate() - never smaller than 4x scrape interval
  $__range       the dashboard's current time range
```

Use `rate(x[$__rate_interval])` rather than a hard-coded `[5m]` in dashboards:
zooming out then widens the window automatically instead of producing gaps.

---

# The Dashboard in This Project

`dashboards/metrics-app.json` is laid out as the Golden Signals:

```text
┌─────────────────────────────────────────────────────────────┐
│ Row: Traffic and Errors                                     │
│ ┌──────────────────────┬──────────┬──────────┐              │
│ │ Request rate /status │ Error %  │ In-flight│              │
│ └──────────────────────┴──────────┴──────────┘              │
├─────────────────────────────────────────────────────────────┤
│ Row: Latency                                                │
│ ┌──────────────────────┬──────────────────────┐             │
│ │ p50 / p95 / p99      │ Rate by endpoint     │             │
│ └──────────────────────┴──────────────────────┘             │
├─────────────────────────────────────────────────────────────┤
│ Row: Container resources                                    │
│ ┌───────────┬───────────┬───────────┐                       │
│ │ CPU/pod   │ Memory/pod│ Restarts  │                       │
│ └───────────┴───────────┴───────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

The ordering is deliberate: **symptoms at the top, causes below.** During an
incident you read top-to-bottom and the dashboard narrows the problem for you.

---

# Design Rules

```text
1. Most important panel top-left. That is where eyes land.
2. Symptoms above causes: errors and latency, then CPU and memory.
3. One question per panel. "Request rate by status" - not "everything".
4. 6-12 panels. A 40-panel dashboard gets read by nobody.
5. Set units and thresholds on every panel.
6. Name panels as questions: "Are we serving errors?" beats "http_requests".
7. Dashboards live in git. The UI is a drafting tool, not storage.
```

### Importing community dashboards

grafana.com/dashboards has thousands. Useful starting points:

```text
315    / 6417   Kubernetes cluster monitoring
1860            Node Exporter Full
13332           kube-state-metrics
3662            Prometheus 2.0 internals
```

Import with Dashboards -> Import -> paste the ID. Treat them as a source of
PromQL to learn from, not as something to keep unedited - most are far busier
than anything your team needs.

---

# Hands On

```bash
open http://localhost:30030       # admin / admin

# 1. Dashboards -> Kubernetes -> "metrics-app - Golden Signals"
# 2. Explore -> run ad-hoc PromQL against the datasource
# 3. Make the p95 panel move:
kubectl exec -n monitoring deploy/load-generator -- sh -c \
  'i=0; while [ $i -lt 40 ]; do curl -s -o /dev/null http://metrics-app:8000/slow & i=$((i+1)); done; wait'

# 4. Make the error panel go red:
kubectl exec -n monitoring deploy/load-generator -- sh -c \
  'i=0; while [ $i -lt 300 ]; do curl -s -o /dev/null http://metrics-app:8000/error; i=$((i+1)); done'

# 5. Add a panel: Memory as % of limit
#    container_memory_working_set_bytes{namespace="$namespace", container="metrics-app"}
#      / on(pod) group_left
#    kube_pod_container_resource_limits{resource="memory", container="metrics-app"}
#    unit: percentunit, thresholds at 0.8 and 0.9
```

---

# Key Takeaways

```text
1. Grafana queries and renders; Prometheus stores. Grafana holds no metrics.
2. access: proxy - the server calls the datasource, not the browser.
3. Provision datasources and dashboards from files; keep JSON in git.
4. Pin the datasource uid, or imported dashboards break.
5. Template variables make one dashboard work for every namespace.
6. Symptoms at the top, causes below, units and thresholds everywhere.
```

---

# Interview Questions

**Q: Does Grafana store metrics?**
No. It queries datasources at render time and stores only dashboards, users
and datasource definitions.

**Q: How do you keep dashboards across Pod restarts?**
Provision them from ConfigMaps or a sidecar, with the JSON kept in git. Never
rely on Grafana's own database when it sits on an `emptyDir`.

**Q: What is `$__rate_interval` for?**
A Grafana-computed range that is guaranteed to be at least four scrape
intervals wide, so `rate()` stays correct when you zoom the dashboard.

**Q: proxy vs direct access?**
Proxy routes queries through the Grafana server, keeping credentials
server-side and working with internal DNS. Direct makes the browser call the
datasource and is rarely usable in Kubernetes.
