# 02 - Prometheus Architecture

---

# Learning Objectives

* The components inside a Prometheus server
* How a scrape actually works, step by step
* What the TSDB stores on disk
* What `up` is and where it comes from
* Why Prometheus is not highly available by default
* How to reload configuration without losing data

---

# The Components

```text
                  ┌───────────────────────────────────────────┐
                  │            Prometheus Server              │
                  │                                           │
 Kubernetes API ─►│  ┌───────────────────┐                    │
   (discovery)    │  │ Service Discovery │                    │
                  │  └─────────┬─────────┘                    │
                  │            │ target list                  │
                  │  ┌─────────▼─────────┐   HTTP GET         │
                  │  │   Scrape Manager  │──────────────────► /metrics
                  │  └─────────┬─────────┘                    │
                  │            │ samples                      │
                  │  ┌─────────▼─────────┐                    │
                  │  │   TSDB (local)    │                    │
                  │  │  WAL + blocks     │                    │
                  │  └─────────┬─────────┘                    │
                  │            │                              │
                  │  ┌─────────▼─────────┐  ┌──────────────┐  │
                  │  │   Rule Engine     │  │  PromQL /    │  │
                  │  │ record + alert    │  │  HTTP API    │◄─┼── Grafana
                  │  └─────────┬─────────┘  └──────────────┘  │
                  └────────────┼──────────────────────────────┘
                               │ firing alerts
                        ┌──────▼───────┐
                        │ Alertmanager │ ──► Slack / PagerDuty / email
                        └──────────────┘
```

Note what is **not** in that picture: no message queue, no external database,
no agent on every node that must be configured. One binary.

---

# A Scrape, Step by Step

```text
1. Service discovery produces a target:
      10.1.0.42:8000  with metadata labels (__meta_kubernetes_pod_name=...)

2. Relabel rules rewrite that target:
      keep it? change the port? change the path? add labels?

3. Scrape manager does:
      GET http://10.1.0.42:8000/metrics
      Accept: text/plain;version=0.0.4

4. The app responds with the text exposition format:
      # HELP http_requests_total Total HTTP requests processed.
      # TYPE http_requests_total counter
      http_requests_total{method="GET",path="/work",status="200"} 4821

5. Prometheus parses it, attaches the target's labels
   (job, instance, namespace, pod...), stamps it with the scrape time,
   and appends to the TSDB.

6. It also records two synthetic series about the scrape itself:
      up{job="kubernetes-pods", instance="10.1.0.42:8000"}  1
      scrape_duration_seconds{...}                          0.0041
```

Step 6 is why you can alert on a dead target without the target telling you
anything: a failed GET writes `up = 0`.

---

# What a Time Series Looks Like

A time series is identified by its **name plus its full label set**:

```text
http_requests_total{method="GET", path="/work", status="200", job="kubernetes-pods", pod="metrics-app-7c9f-4x2jk"}
```

Change any single label value and it is a **different series**:

```text
status="200"  -> series A
status="500"  -> series B      (different series, same metric name)
```

Internally the metric name is just a reserved label:

```text
{__name__="http_requests_total", method="GET", status="200", ...}
```

That is why `{__name__=~"http_.*"}` is a valid query.

Each series is a stream of samples:

```text
t=10:00:00  4821
t=10:00:15  4835
t=10:00:30  4849
t=10:00:45  4862
```

---

# The TSDB on Disk

```text
/prometheus/
├── wal/                    recent samples, not yet compacted
│   ├── 00000012
│   └── 00000013
├── chunks_head/
├── 01HQ8F.../              a 2-hour block
│   ├── chunks/             the compressed samples
│   ├── index               label -> series lookup
│   └── meta.json
└── 01HQ8G.../              the next block
```

How it works:

```text
1. Incoming samples go to an in-memory "head block"
   and are appended to the WAL (write-ahead log) for crash safety.
2. Every 2 hours the head is flushed to an immutable block on disk.
3. Older blocks are compacted together into bigger blocks.
4. Blocks older than --storage.tsdb.retention.time are deleted whole.
```

Consequences you must understand:

```text
* Retention is enforced per BLOCK, not per sample.
* You cannot delete one metric's history cheaply.
* The TSDB can only be opened by ONE process - hence
  `strategy: Recreate` in prometheus-deployment.yaml.
* Memory usage is driven by the number of ACTIVE series, not by
  how long you retain data.
```

That last line is the single most important operational fact about Prometheus.

---

# Why Not Just Run 3 Replicas?

```text
Replica A scrapes app at 10:00:03 -> value 4821
Replica B scrapes app at 10:00:11 -> value 4833
```

They are two independent databases with slightly different data. There is no
replication, no leader election, no shared storage.

So:

```text
replicas: 1            correct for a single Prometheus
strategy: Recreate     never two processes on one TSDB directory
```

Real HA options, in increasing order of effort:

| Approach | What you get |
|---|---|
| Two identical Prometheis scraping the same targets | redundancy; graphs differ slightly |
| Shard by scrape job across several servers | scale, not redundancy |
| **Thanos / Mimir / Cortex** | dedup, global query view, object-storage long-term retention |

Thanos works by running a sidecar next to each Prometheus that uploads 2-hour
blocks to S3, plus a Querier that deduplicates across replicas at query time.

---

# Reloading Configuration

You changed the ConfigMap. Prometheus does **not** notice on its own.

```bash
# 1. Apply the new ConfigMap
kubectl apply -f k8s/prometheus-config.yaml

# 2. Wait - the kubelet syncs ConfigMap volumes about once a minute
kubectl exec -n monitoring deploy/prometheus -- \
  cat /etc/prometheus/prometheus.yml | head

# 3. Hot reload: keeps the TSDB and all history
kubectl exec -n monitoring deploy/prometheus -- \
  wget -qO- --post-data='' http://localhost:9090/-/reload
```

The hot reload only works because the Deployment passes
`--web.enable-lifecycle`.

Never reload by deleting the Pod: with an `emptyDir` that throws away all
your metrics. In production, a **config-reloader sidecar** watches the mounted
files and calls `/-/reload` automatically - that is exactly what the
Prometheus Operator does for you.

Check a config file before applying it:

```bash
promtool check config prometheus.yml
promtool check rules app.rules.yml
```

`promtool` ships inside the `prom/prometheus` image:

```bash
kubectl exec -n monitoring deploy/prometheus -- \
  promtool check config /etc/prometheus/prometheus.yml
```

---

# Useful Endpoints

| Endpoint | What it gives you |
|---|---|
| `/targets` | every target, its labels, last scrape, and error |
| `/service-discovery` | targets BEFORE relabeling - the debugging goldmine |
| `/config` | the config as Prometheus actually parsed it |
| `/rules` | rule groups, evaluation time, alert state |
| `/alerts` | pending + firing alerts |
| `/graph` | the query UI |
| `/api/v1/query?query=up` | the HTTP API Grafana uses |
| `/-/healthy`, `/-/ready` | probes |
| `/metrics` | Prometheus monitoring itself |

---

# Key Takeaways

```text
1. One binary: discovery, scraping, storage, rules, API.
2. `up` is synthesised by Prometheus, not by your app.
3. The TSDB is local, single-writer, and retention deletes whole blocks.
4. Memory scales with ACTIVE SERIES, not with retention time.
5. Config changes need an explicit /-/reload.
6. HA means Thanos/Mimir, not `replicas: 3`.
```

---

# Interview Questions

**Q: How does Prometheus know a target is down?**
The scrape fails, so Prometheus writes `up{...} = 0` for that target. The
`TargetDown` alert is just `up == 0` with a `for:` clause.

**Q: Can you run Prometheus with 3 replicas for HA?**
Not meaningfully - each replica is an independent database. For real HA you
run redundant replicas plus Thanos/Mimir to deduplicate and provide a global
query view.

**Q: What drives Prometheus memory usage?**
The number of active time series (cardinality), the head block, and query
load - not how much history you keep on disk.

**Q: How do you apply a config change without downtime?**
Update the ConfigMap, wait for the kubelet to sync the volume, then
`POST /-/reload` (requires `--web.enable-lifecycle`).
