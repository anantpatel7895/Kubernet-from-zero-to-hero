# 13 - Storage, Retention and Scaling Prometheus

---

# Learning Objectives

* Sizing the TSDB and the memory it needs
* Why `emptyDir` is wrong outside a lab, and what a PVC changes
* Retention by time and by size
* Cardinality: diagnosing it before it kills you
* Federation, sharding, remote_write
* Thanos and Mimir in one page

---

# Sizing

The rule of thumb from the Prometheus docs:

```text
disk = retention_seconds x samples_per_second x bytes_per_sample

bytes_per_sample ~ 1.5-2 bytes (after compression)
```

Worked example:

```text
100,000 active series
scrape_interval 15s  ->  6,666 samples/sec
retention 15 days    ->  1,296,000 seconds

1,296,000 x 6,666 x 2 bytes = ~17 GB
```

Then add 30-40% headroom for compaction, which needs space to write the new
block before deleting the old ones.

### Memory

```text
RAM is driven by ACTIVE SERIES, not by retention.

Rough: 100,000 active series ~ 2-3 GB RAM.

The head block holds every active series in memory, plus query working
memory, plus the WAL.
```

```text
Doubling retention    -> more disk, barely any more RAM.
Doubling cardinality  -> more disk AND double the RAM.

That asymmetry is why cardinality is the thing to police.
```

Query it:

```promql
prometheus_tsdb_head_series                    # active series right now
rate(prometheus_tsdb_head_samples_appended_total[5m])   # ingestion rate
prometheus_tsdb_storage_blocks_bytes           # on-disk size
go_memstats_alloc_bytes{job="prometheus"}      # memory in use
```

---

# Retention

```yaml
args:
- --storage.tsdb.retention.time=15d
- --storage.tsdb.retention.size=40GB     # whichever hits first
```

```text
Retention deletes whole 2-hour (then compacted) BLOCKS.
You cannot retain "this metric for a year and that one for a day" in a
single Prometheus. That requires downsampling - Thanos or Mimir.
```

Always set `retention.size` when the volume is fixed. Time-only retention plus
a traffic spike equals a full disk, and a Prometheus that cannot write is a
Prometheus you have lost.

---

# Storage in Kubernetes

This project uses:

```yaml
volumes:
- name: storage
  emptyDir: {}
```

```text
emptyDir lives in the Pod. Delete the Pod -> the TSDB is gone.
Fine for a lab. Never for anything you would miss.
```

Production:

```yaml
apiVersion: apps/v1
kind: StatefulSet            # not Deployment - stable identity + volume
metadata:
  name: prometheus
spec:
  serviceName: prometheus
  replicas: 1
  volumeClaimTemplates:
  - metadata:
      name: storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

```text
Why StatefulSet:
  * stable pod name and a volume that follows it across restarts
  * ordered, controlled rollouts
  * the volumeClaimTemplate gives each replica its own PVC

Why ReadWriteOnce is fine:
  the TSDB is single-writer anyway - sharing it would corrupt it.

Why SSD:
  compaction is IO-heavy. On slow disks compaction falls behind, the head
  block grows, and memory climbs until the OOM killer arrives.
```

With a Deployment + PVC (not a StatefulSet), always set
`strategy: Recreate` - a rolling update would start a second Pod that tries to
open the same TSDB directory and fails.

---

# Cardinality in Practice

### Diagnosing

```promql
# Which metrics have the most series?
topk(10, count by (__name__)({__name__=~".+"}))

# Which jobs produce the most samples per scrape?
topk(10, scrape_samples_scraped)

# Total active series
prometheus_tsdb_head_series

# Which label is the culprit? (count distinct values)
count(count by (pod) (container_memory_working_set_bytes))
```

Also: **Status -> TSDB Status** in the UI gives you the top label names by
cardinality without writing any query at all.

### Fixing

```text
1. At the source - the real fix. Remove the label from the code.

2. metric_relabel_configs - drop series at ingest:

   metric_relabel_configs:
   - source_labels: [__name__]
     action: drop
     regex: container_network_tcp_usage_total

3. Keep only what you query:

   - source_labels: [__name__]
     action: keep
     regex: (up|kube_pod_.*|container_(cpu|memory)_.*)

4. Drop a noisy label:

   - action: labeldrop
     regex: (id|uid|pod_template_hash)

5. Raise scrape_interval. Halving the samples halves the disk - though
   it does nothing for the series count, which is what drives memory.
```

---

# Scaling Beyond One Server

### 1. Vertical first

Prometheus is extremely efficient. A single server with 32GB of RAM handles
millions of series. Exhaust this option before adding architecture.

### 2. Functional sharding

```text
prometheus-apps       scrapes application workloads
prometheus-infra      scrapes nodes and the control plane
prometheus-team-a     scrapes team A's namespaces
```

Simple, and each one is independently debuggable. The cost is that no single
server can answer a cross-shard query - you need Grafana with multiple
datasources, or a global query layer.

### 3. Hash sharding

```yaml
relabel_configs:
- source_labels: [__address__]
  action: hashmod
  modulus: 4
  target_label: __tmp_shard
- source_labels: [__tmp_shard]
  action: keep
  regex: 0            # 1, 2, 3 on the other three servers
```

Automatic and even, but a target can move between shards when the modulus
changes, splitting its history.

### 4. Federation

One Prometheus scrapes **aggregated** series from others:

```yaml
- job_name: federate
  honor_labels: true
  metrics_path: /federate
  params:
    'match[]':
    - '{__name__=~"job:.*"}'      # ONLY recording rules
  static_configs:
  - targets:
    - prometheus-shard-0:9090
    - prometheus-shard-1:9090
```

```text
Federate ONLY pre-aggregated recording rules.

Trying to federate raw series copies the entire cardinality problem into
the parent, which then falls over. Federation is for a global summary view,
not for centralising all your data. For that you want remote_write.
```

### 5. remote_write

```yaml
remote_write:
- url: https://mimir.example.com/api/v1/push
  queue_config:
    max_samples_per_send: 2000
    capacity: 10000
    max_shards: 50
  write_relabel_configs:
  - source_labels: [__name__]
    action: keep
    regex: (job:.*|up|kube_pod_.*)     # don't ship everything
```

Prometheus stays the scraper and keeps a short local retention; the long-term
store owns history, downsampling and the global query view.

---

# Thanos and Mimir

```text
          ┌─────────────┐  ┌─────────────┐
          │ Prometheus  │  │ Prometheus  │   each with a Thanos SIDECAR
          │  + sidecar  │  │  + sidecar  │   uploading 2h blocks
          └──────┬──────┘  └──────┬──────┘
                 │  upload        │
                 ▼                ▼
             ┌──────────────────────────┐
             │   Object storage (S3)    │   cheap, infinite, durable
             └────────────┬─────────────┘
                          │
      ┌───────────────────┼───────────────────┐
      ▼                   ▼                   ▼
┌───────────┐      ┌─────────────┐     ┌────────────┐
│  Store    │      │  Compactor  │     │   Ruler    │
│  Gateway  │      │ downsamples │     │ global     │
└─────┬─────┘      └─────────────┘     │ rules      │
      │                                └────────────┘
      ▼
┌───────────┐
│  Querier  │  <- Grafana points here; dedups across replicas,
└───────────┘     merges live sidecar data with historical blocks
```

What it buys you:

```text
* Unlimited retention at object-storage prices
* A global view across clusters and shards from one datasource
* Deduplication of HA Prometheus pairs (finally, real HA)
* Downsampling: 5m and 1h resolutions, so a 1-year graph is fast
```

```text
Thanos  - bolt onto existing Prometheus servers, incremental adoption.
Mimir   - (Grafana Labs, from Cortex) a horizontally scalable TSDB you
          remote_write into. More operationally involved, higher ceiling.

Both are real distributed systems. Do not adopt either until a single
Prometheus genuinely cannot cope - that threshold is higher than you think.
```

---

# Key Takeaways

```text
1. Disk ~ retention x samples/sec x 2 bytes. RAM ~ active series.
2. Retention deletes whole blocks; set retention.size on a fixed volume.
3. emptyDir is a lab choice. Production = StatefulSet + PVC on SSD.
4. Cardinality drives memory. Find it with topk(count by (__name__)).
5. Scale vertically, then shard, then remote_write. Federate only
   recording rules.
6. Thanos/Mimir give long retention, HA dedup and a global view - at the
   cost of running a distributed system.
```

---

# Interview Questions

**Q: How do you size a Prometheus server?**
Disk from retention x ingestion rate x ~2 bytes per sample plus headroom;
memory from the number of active series (roughly 2-3GB per 100k series).

**Q: Why does Prometheus use so much memory?**
The head block keeps every active series in memory. Memory tracks
cardinality, not retention - so new labels hurt far more than longer history.

**Q: How do you give Prometheus long-term storage?**
`remote_write` to Thanos, Mimir or Cortex, which store blocks in object
storage with downsampling, while Prometheus keeps only recent data locally.

**Q: What is federation and when is it wrong?**
A Prometheus scraping selected series from other Prometheis. It is wrong when
used to centralise raw series - it copies the cardinality and overwhelms the
parent. Federate only aggregated recording rules.

**Q: Deployment or StatefulSet for Prometheus?**
StatefulSet, for stable identity and a PVC that follows the Pod. With a
Deployment you must at least set `strategy: Recreate`, because two Pods
cannot open the same TSDB.
