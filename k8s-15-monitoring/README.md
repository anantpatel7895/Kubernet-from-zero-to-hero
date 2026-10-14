# Project 15 - Monitoring Stack

## Project Name

```text
k8s-15-monitoring
```

---

# 🎯 Goal

Build a complete **Prometheus + Grafana** monitoring stack from scratch -
no Helm chart, no Operator - so that every moving part is visible:

- **Prometheus** — scrapes, stores and evaluates rules
- **Grafana** — queries and draws
- **Alertmanager** — groups, routes and silences alerts
- **node-exporter** — the machines
- **kube-state-metrics** — the Kubernetes API objects
- **metrics-app** — a FastAPI service instrumented by hand

You will instrument an app, watch Prometheus discover it on its own, write
PromQL against real data, and make a real alert fire.

---

# 📚 What You'll Learn

- Why Prometheus **pulls** instead of being pushed to
- The four metric types: **Counter, Gauge, Histogram, Summary**
- How to instrument an app, and the **cardinality** mistake that OOMs servers
- **Service discovery** and **relabeling** - the real engine of Prometheus
- **PromQL**: `rate`, `histogram_quantile`, aggregation, vector matching
- **Recording rules** and **alerting rules**, and why `for:` matters most
- **Alertmanager**: grouping, routing, inhibition, silences
- **Grafana**: provisioning, template variables, dashboards that survive a Pod restart
- The difference between **cAdvisor**, **node-exporter**, **kube-state-metrics** and **metrics-server**
- **Golden Signals**, **SLOs**, **error budgets** and **burn-rate alerting**
- Storage, retention, cardinality control, and how to scale past one server

---

# 🚨 The Problem

```bash
kubectl get pods

NAME                           READY   STATUS    RESTARTS   AGE
metrics-app-7c9f8d5b4-4x2jk    1/1     Running   0          2d
metrics-app-7c9f8d5b4-8nqlm    1/1     Running   0          2d
```

A user says the site is slow. Now answer, using only that output:

```text
Requests per second?        unknown
p95 latency?                unknown
Error rate?                 unknown
Was it slow at 09:00?       unknown
Worse since the deploy?     unknown
```

`Running` means "the process has not exited". A Pod can be `Running` while
every request returns 500, or takes 30 seconds.

```text
You cannot debug what you cannot measure,
and you cannot measure the past unless you were already recording it.
```

---

# 💡 How Prometheus Works

```text
Every 15 seconds:

    Prometheus ──GET /metrics──► your Pod
               ◄──text/plain─────

    # TYPE http_requests_total counter
    http_requests_total{path="/work",status="200"} 4821
```

The app does nothing but answer an HTTP GET. It does not know Prometheus
exists, holds no connection, and pushes nothing.

```text
PULL wins in Kubernetes because:

  a failed scrape IS the health signal      ->  up == 0
  new Pods are found automatically          ->  service discovery
  dead Pods just disappear                  ->  no stale config
  you can debug with curl                   ->  see exactly what it sees
  a runaway app cannot flood the collector  ->  the collector sets the pace
```

---

# 🏗 Architecture

```text
                  ┌──────────────────────────────┐
                  │          Grafana             │  :30030
                  │   dashboards, no storage     │
                  └───────────────┬──────────────┘
                                  │ PromQL over HTTP
                  ┌───────────────▼──────────────┐
                  │         Prometheus           │  :30090
                  │  discover → scrape → store   │
                  │      → evaluate rules        │
                  └──┬───────┬────────┬──────┬───┘
         scrape /metrics     │        │      │  fires alerts
            ┌───────┘        │        │      └────────────┐
            │                │        │                   │
   ┌────────▼──────┐ ┌───────▼─────┐ ┌▼──────────────┐ ┌──▼──────────┐
   │  metrics-app  │ │node-exporter│ │kube-state-    │ │Alertmanager │ :30093
   │  (your code)  │ │ (DaemonSet) │ │metrics        │ │ group/route │
   └───────────────┘ └─────────────┘ └───────────────┘ └─────────────┘
         ▲
         │ traffic
   ┌─────┴──────────┐
   │ load-generator │
   └────────────────┘
```

Four metric sources, each answering a different question:

| Source | Answers |
|---|---|
| metrics-app | what my business logic is doing |
| cAdvisor (in the kubelet) | what the containers actually consume |
| node-exporter | what the machine is doing |
| kube-state-metrics | what the Kubernetes API says *should* be true |

---

# 📁 Project Structure

```text
k8s-15-monitoring/
├── app/
│   └── metrics-app/
│       ├── Dockerfile
│       ├── main.py                     instrumented FastAPI service
│       └── requirements.txt
│
├── k8s/
│   ├── namespace.yaml
│   ├── app-deployment.yaml             + prometheus.io/* annotations
│   ├── app-service.yaml
│   ├── load-generator.yaml             keeps the dashboards alive
│   ├── prometheus-rbac.yaml            SA + ClusterRole + binding
│   ├── prometheus-config.yaml          scrape jobs + relabel rules
│   ├── prometheus-rules.yaml           recording + alerting rules
│   ├── prometheus-deployment.yaml
│   ├── prometheus-service.yaml
│   ├── alertmanager.yaml               config + deployment + services
│   ├── node-exporter.yaml              DaemonSet
│   ├── kube-state-metrics.yaml         RBAC + Deployment + Service
│   ├── grafana-provisioning.yaml       datasource + dashboard provider
│   ├── grafana-dashboards.yaml         generated from dashboards/
│   ├── grafana-deployment.yaml
│   └── servicemonitor-example.yaml     Operator comparison (not applied)
│
├── dashboards/
│   └── metrics-app.json                source of truth for the dashboard
│
├── docs/                               01 → 14, read in order
└── test/
    └── smoke-test.sh
```

---

# 📦 Step 1 - Build the App Image

```bash
cd k8s-15-monitoring
docker build -t metrics-app:v1 app/metrics-app
```

### Docker Desktop

Nothing else to do - the cluster shares the daemon's images.

### Minikube

```bash
eval $(minikube docker-env)
docker build -t metrics-app:v1 app/metrics-app
```

### kind

```bash
kind load docker-image metrics-app:v1
```

The Deployment sets `imagePullPolicy: IfNotPresent` so the local image is used
instead of being pulled from a registry.

---

# 🚀 Step 2 - Deploy the Stack

Order matters: RBAC and config must exist before Prometheus starts.

```bash
kubectl apply -f k8s/namespace.yaml

# the app
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml

# prometheus
kubectl apply -f k8s/prometheus-rbac.yaml
kubectl apply -f k8s/prometheus-config.yaml
kubectl apply -f k8s/prometheus-rules.yaml
kubectl apply -f k8s/alertmanager.yaml
kubectl apply -f k8s/prometheus-deployment.yaml
kubectl apply -f k8s/prometheus-service.yaml

# exporters
kubectl apply -f k8s/node-exporter.yaml
kubectl apply -f k8s/kube-state-metrics.yaml

# grafana
kubectl apply -f k8s/grafana-provisioning.yaml
kubectl apply -f k8s/grafana-dashboards.yaml
kubectl apply -f k8s/grafana-deployment.yaml

# traffic
kubectl apply -f k8s/load-generator.yaml

kubectl get pods -n monitoring -w
```

Or run everything, with verification:

```bash
./test/smoke-test.sh
```

---

# 🌐 Step 3 - Open the UIs

| | URL | Notes |
|---|---|---|
| Prometheus | http://localhost:30090 | Status → Targets first |
| Grafana | http://localhost:30030 | admin / admin |
| Alertmanager | http://localhost:30093 | |
| The app | http://localhost:30080/work | |

If NodePort does not reach your cluster (common on some setups), port-forward:

```bash
kubectl port-forward -n monitoring svc/prometheus   9090:9090
kubectl port-forward -n monitoring svc/grafana      3000:3000
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

---

# 🔍 Step 4 - See the Pipeline Working

### 1. The raw metrics your app exposes

```bash
kubectl exec -n monitoring deploy/metrics-app -- \
  python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/metrics').read().decode())" \
  | head -30
```

```text
# HELP http_requests_total Total HTTP requests processed.
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/work",status="200"} 482.0
```

### 2. Prometheus found it by itself

```text
http://localhost:30090  →  Status → Targets

job "kubernetes-pods"
  10.1.0.42:8000   UP   last scrape 3.1s ago
  10.1.0.43:8000   UP   last scrape 8.7s ago
```

Nothing in `prometheus.yml` names those IPs. They came from the Kubernetes
API, filtered by three annotations on the Pod template:

```yaml
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
prometheus.io/port: "8000"
```

How that works is [docs/05](docs/05-service-discovery-and-relabeling.md).

### 3. Query it

Paste into the Prometheus graph UI:

```promql
# requests per second, by status
sum by (status) (rate(http_requests_total[5m]))

# p95 latency
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))

# error ratio, from a recording rule
job:http_error_ratio:rate5m

# CPU per pod, in cores (from cAdvisor)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="monitoring", container!=""}[5m]))

# restarts (from kube-state-metrics)
increase(kube_pod_container_status_restarts_total{namespace="monitoring"}[1h])
```

### 4. The dashboard

```text
http://localhost:30030  →  Dashboards → Kubernetes → metrics-app - Golden Signals
```

### 5. Break it on purpose

```bash
# Latency: push p95 up
kubectl exec -n monitoring deploy/load-generator -- sh -c \
  'i=0; while [ $i -lt 40 ]; do curl -s -o /dev/null http://metrics-app:8000/slow & i=$((i+1)); done; wait'

# Errors: drive the error ratio past 5%
kubectl exec -n monitoring deploy/load-generator -- sh -c \
  'i=0; while [ $i -lt 600 ]; do curl -s -o /dev/null http://metrics-app:8000/error; i=$((i+1)); done'
```

Then watch the state machine in Prometheus → Alerts:

```text
inactive  →  pending (the `for: 2m` timer)  →  firing  →  Alertmanager
```

### 6. Kill a pod and watch a target vanish

```bash
kubectl delete pod -n monitoring -l app=metrics-app
```

Within seconds the old target disappears from Status → Targets and a new IP
appears. Nobody edited any config - that is service discovery.

---

# 🧪 What the Smoke Test Verifies

```bash
./test/smoke-test.sh         # run
./test/smoke-test.sh clean   # remove everything, including ClusterRoles
```

```text
 1. namespace created
 2. metrics-app rolled out
 3. /metrics returns the Prometheus text format
 4. Prometheus + Alertmanager running
 5. node-exporter + kube-state-metrics running
 6. Grafana running
 7. load generator producing traffic
 8. annotated targets discovered and UP
 9. http_requests_total present in the TSDB
10. cAdvisor + kube-state-metrics series present
11. recording rules producing series
12. HighErrorRate actually transitions to FIRING
13. Grafana API healthy
```

---

# 📖 Documentation

Read in order - each builds on the last.

| # | Doc | Covers |
|---|---|---|
| 01 | [Why Monitoring Exists](docs/01-why-monitoring.md) | pillars, push vs pull, vocabulary |
| 02 | [Prometheus Architecture](docs/02-prometheus-architecture.md) | components, scrape flow, TSDB, reloads |
| 03 | [Metric Types](docs/03-metric-types.md) | counter, gauge, histogram, summary, cardinality |
| 04 | [Instrumenting an App](docs/04-instrumenting-an-app.md) | client libraries, RED, multiprocess, exporters |
| 05 | [Service Discovery & Relabeling](docs/05-service-discovery-and-relabeling.md) | roles, `__meta_*`, relabel actions, debugging |
| 06 | [PromQL](docs/06-promql-basics.md) | rate, aggregation, quantiles, vector matching |
| 07 | [Recording & Alerting Rules](docs/07-recording-and-alerting-rules.md) | rule anatomy, `for:`, symptoms vs causes |
| 08 | [Alertmanager](docs/08-alertmanager.md) | grouping, routing, inhibition, silences, HA |
| 09 | [Grafana](docs/09-grafana.md) | provisioning, panels, variables, design |
| 10 | [Exporters & Cluster Metrics](docs/10-exporters-and-cluster-metrics.md) | cAdvisor, node-exporter, KSM, metrics-server |
| 11 | [Prometheus Operator](docs/11-prometheus-operator.md) | CRDs, ServiceMonitor, kube-prometheus-stack |
| 12 | [Golden Signals & SLOs](docs/12-golden-signals-and-slos.md) | RED/USE, SLI/SLO/SLA, error budgets, burn rate |
| 13 | [Storage & Scaling](docs/13-storage-and-scaling.md) | sizing, retention, sharding, Thanos/Mimir |
| 14 | [Production Patterns](docs/14-production-patterns.md) | checklist, security, meta-monitoring, debugging |

---

# ⚠️ The Five Mistakes That Matter

```text
1. HIGH-CARDINALITY LABELS
   REQUESTS.labels(user_id=...)  or  path=request.url.path
   -> millions of series -> Prometheus OOMs. The #1 monitoring outage.
   -> use the ROUTE TEMPLATE: "/items/{id}", never "/items/42".

2. GRAPHING A RAW COUNTER
   http_requests_total           a line that only goes up. useless.
   rate(http_requests_total[5m]) requests per second. correct.

3. NO `for:` ON AN ALERT
   One slow scrape pages you at 3am. `for: 2m` is the fix.

4. AVERAGING LATENCY
   99 requests at 10ms + 1 at 5s -> average 59ms "fine", p99 5s "awful".
   Always percentiles.

5. ALERTING ON CAUSES
   "CPU > 80%" wakes you for a healthy batch job.
   "Error rate > 5% for 2m" wakes you when users are suffering.
```

---

# 🧹 Cleanup

```bash
./test/smoke-test.sh clean

# or by hand - note the cluster-scoped objects survive the namespace
kubectl delete namespace monitoring
kubectl delete clusterrole prometheus kube-state-metrics
kubectl delete clusterrolebinding prometheus kube-state-metrics
```

---

# ✅ What You Should Be Able to Do Now

```text
[ ] Explain why Prometheus pulls instead of being pushed to
[ ] Pick the right metric type for a new measurement
[ ] Instrument a service without blowing up cardinality
[ ] Explain how a Pod becomes a Prometheus target, end to end
[ ] Write rate(), histogram_quantile() and aggregation queries from memory
[ ] Write an alert that fires on a symptom, with a useful annotation
[ ] Explain grouping, inhibition and silences in Alertmanager
[ ] Say which of the four metric sources answers a given question
[ ] Define an SLO and compute its error budget
[ ] Debug a missing target, a NaN query and an OOMKilled Prometheus
```

---

# ➡️ Next

**Project 16 - Logging Stack.** Metrics tell you *that* something broke and
how bad it is. The next question is always *why* - and that answer is in the
logs.
