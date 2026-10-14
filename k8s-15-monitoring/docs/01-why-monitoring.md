# 01 - Why Monitoring Exists

---

# Learning Objectives

By the end of this lab you will understand:

* Why `kubectl get pods` is not monitoring
* The difference between metrics, logs and traces
* What observability actually means
* Push vs pull collection
* Why Prometheus became the Kubernetes standard
* The vocabulary used for the rest of this project

---

# The Problem

Your app is deployed. Three replicas. All `Running`.

```bash
kubectl get pods

NAME                           READY   STATUS    RESTARTS   AGE
metrics-app-7c9f8d5b4-4x2jk    1/1     Running   0          2d
metrics-app-7c9f8d5b4-8nqlm    1/1     Running   0          2d
metrics-app-7c9f8d5b4-pz7vw    1/1     Running   0          2d
```

A user messages you:

```text
"The site has been slow since this morning."
```

Now answer these questions using only the output above:

```text
How many requests per second are we serving?       unknown
What is the p95 latency?                           unknown
What percentage of requests are failing?           unknown
Was it slow at 09:00 too?                          unknown
Did it get worse after yesterday's deploy?         unknown
```

`Running` means "the process has not exited". Nothing more.

A Pod can be `Running` while:

* every request returns HTTP 500
* every request takes 30 seconds
* it is throttled to 5% of a CPU
* it stopped processing its queue an hour ago

**You cannot debug what you cannot measure, and you cannot measure the past
unless you were already recording it.**

---

# Monitoring vs Observability

```text
Monitoring     = watching things you already knew to watch
                 "is CPU above 80%?"

Observability  = being able to ask NEW questions about the past
                 "why were requests from EU slow between 09:10 and 09:25?"
```

Monitoring answers questions you wrote down in advance.
Observability lets you ask questions you had not thought of yet.

---

# The Three Pillars

| Pillar | Answers | Shape | Tool in this roadmap |
|---|---|---|---|
| **Metrics** | *Is something wrong, and how bad?* | numbers over time | Prometheus (Project 15) |
| **Logs** | *What exactly happened in this request?* | text events | ELK / Loki (Project 16) |
| **Traces** | *Where in the chain of 9 services did the time go?* | spans | Jaeger / Tempo |

They are used in that order during an incident:

```text
Metric alert fires     -> something is wrong, error rate is 12%
Dashboard narrows it   -> only the /checkout endpoint, only pod-3
Logs explain it        -> "connection refused: payments:8080"
Trace confirms it      -> 4.8s of the 5s was spent waiting on payments
```

Metrics are cheap and cover everything.
Logs are expensive and cover detail.
Start with metrics.

---

# Why Metrics Are Cheap

A log line is a string - maybe 200 bytes, and you keep every one.

A metric sample is:

```text
timestamp (8 bytes) + float64 value (8 bytes)
```

...and Prometheus compresses that to roughly **1-2 bytes per sample** on disk.

```text
1 app, 100 time series, scraped every 15s
= 100 * 4 samples/min * 60 * 24
= 576,000 samples/day
~ 1 MB/day
```

You can afford to keep that for every service in the cluster.

---

# Push vs Pull

Two ways metrics get collected:

```text
PUSH                              PULL
app -> sends -> collector         collector -> asks -> app

StatsD, Graphite, DataDog         Prometheus
```

Prometheus **pulls**. Every 15 seconds it does a plain HTTP GET:

```text
GET http://10.1.0.42:8000/metrics
```

The app does nothing but answer. It does not know Prometheus exists.

### Why pull wins in Kubernetes

| | Pull |
|---|---|
| Is the target alive? | Built in - a failed scrape sets `up = 0` |
| New Pod appears | Service discovery finds it automatically |
| Pod dies | It simply disappears from the target list |
| Debugging | `curl localhost:8000/metrics` shows exactly what Prometheus sees |
| Runaway app | Cannot flood the collector; the collector sets the pace |

In a world where Pod IPs change every deploy, "the collector asks Kubernetes
who exists right now" is far more robust than "every Pod must be configured
with the collector's address".

### Where push still applies

A batch job that runs for 20 seconds and exits can never be scraped.
For those, Prometheus offers the **Pushgateway** - a small service the job
pushes to, which Prometheus then scrapes. Use it only for that case.

---

# Why Prometheus

```text
2012  SoundCloud builds Prometheus
2016  Second project ever to join the CNCF (after Kubernetes itself)
2018  Graduates
```

It won because it was designed for the same world Kubernetes was:

* targets appear and disappear constantly -> **service discovery**
* no single machine identity -> **labels instead of hostnames**
* everything must be queryable -> **PromQL**
* it must work when everything else is broken -> **no external dependencies**

A Prometheus server is a single Go binary with a local database. No cluster,
no Kafka, no Zookeeper. When your cluster is on fire, Prometheus is still up.

---

# The Stack You Will Build

```text
                  ┌──────────────────────────────┐
                  │          Grafana             │  dashboards
                  └───────────────┬──────────────┘
                                  │ PromQL over HTTP
                  ┌───────────────▼──────────────┐
                  │         Prometheus           │  scrape + store + alert
                  │   ┌──────────────────────┐   │
                  │   │  local TSDB (24h)    │   │
                  │   └──────────────────────┘   │
                  └──┬───────┬────────┬──────┬───┘
         scrape /metrics     │        │      │  fires alerts
            ┌───────┘        │        │      └────────────┐
            │                │        │                   │
   ┌────────▼──────┐ ┌───────▼─────┐ ┌▼──────────────┐ ┌──▼──────────┐
   │  metrics-app  │ │node-exporter│ │kube-state-    │ │Alertmanager │
   │  (your code)  │ │  (machine)  │ │metrics (API)  │ │ route/group │
   └───────────────┘ └─────────────┘ └───────────────┘ └─────────────┘
```

Four sources of truth, and they do **not** overlap:

| Source | Answers |
|---|---|
| your app | what my business logic is doing |
| cAdvisor (in the kubelet) | what the containers are actually consuming |
| node-exporter | what the machine is doing |
| kube-state-metrics | what the Kubernetes API thinks should be true |

---

# Vocabulary

```text
target          something Prometheus scrapes (an IP:port + path)
scrape          one HTTP GET of /metrics
time series     a unique metric name + label set, tracked over time
sample          one (timestamp, value) pair in a series
exporter        a sidecar process that translates something else into metrics
instrumentation metrics your own code emits
cardinality     how many distinct time series a metric produces
```

Remember the last one. It is the thing that breaks Prometheus in production.

---

# Key Takeaways

```text
1. "Running" is not "healthy".
2. Metrics tell you THAT something is wrong; logs tell you WHY.
3. Prometheus pulls - the app is passive and that makes it robust.
4. Prometheus is self-contained: it keeps working when the cluster does not.
5. Four metric sources: your app, cAdvisor, node-exporter, kube-state-metrics.
```

---

# Interview Questions

**Q: Why does Prometheus pull instead of push?**
Because in Kubernetes the set of targets changes constantly. Pull plus service
discovery means Prometheus always knows the current target list, a failed
scrape is itself the health signal (`up == 0`), and a misbehaving app cannot
overwhelm the collector.

**Q: What is the difference between monitoring and observability?**
Monitoring checks conditions you defined in advance. Observability is the
property of having enough data to ask new questions after the fact.

**Q: When would you use the Pushgateway?**
Only for short-lived batch jobs that exit before any scrape could reach them.
Never as a general workaround for "my app can't be scraped".

**Q: Prometheus is down. Have you lost your alerting?**
Yes - which is why Prometheus has no dependencies, and why you monitor
Prometheus itself (meta-monitoring), often with a second Prometheus.
