# 10 - Exporters and Cluster Metrics

---

# Learning Objectives

* The four distinct sources of Kubernetes metrics and what each knows
* cAdvisor: real container usage
* node-exporter: the machine
* kube-state-metrics: the API server's view
* metrics-server vs Prometheus - why both exist
* Joining metrics from different sources in one query

---

# Four Sources, Four Different Truths

```text
┌────────────────────┬───────────────────────────────────────────────┐
│ Source             │ Answers                                       │
├────────────────────┼───────────────────────────────────────────────┤
│ your app           │ what my business logic is doing               │
│ cAdvisor (kubelet) │ what containers are ACTUALLY consuming        │
│ node-exporter      │ what the MACHINE is doing                     │
│ kube-state-metrics │ what the Kubernetes API SAYS should be true   │
└────────────────────┴───────────────────────────────────────────────┘
```

The classic confusion:

```text
container_memory_working_set_bytes          <- cAdvisor: real usage NOW
kube_pod_container_resource_limits          <- KSM: the configured limit
node_memory_MemAvailable_bytes              <- node-exporter: the host

They come from three different processes and mean three different things.
Divide the first by the second and you get "how close to OOMKill am I".
```

---

# cAdvisor

cAdvisor is **built into the kubelet**. There is nothing to deploy - you just
have to scrape it:

```text
https://<node>:10250/metrics/cadvisor
```

This project scrapes it through the API server proxy so it works on clusters
where the kubelet port is not directly reachable:

```yaml
- target_label: __address__
  replacement: kubernetes.default.svc:443
- source_labels: [__meta_kubernetes_node_name]
  target_label: __metrics_path__
  replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
```

### What it gives you

```text
container_cpu_usage_seconds_total           counter of CPU-seconds
container_cpu_cfs_throttled_periods_total   throttling (see Project 11)
container_cpu_cfs_periods_total
container_memory_working_set_bytes          what the OOM killer watches
container_memory_usage_bytes                includes reclaimable cache
container_memory_rss
container_network_receive_bytes_total
container_network_transmit_bytes_total
container_fs_usage_bytes
```

### The two gotchas

```text
1. Always filter container!="" and container!="POD".

   Empty container  -> the pod-level rollup (sums all containers)
   container="POD"  -> the pause/sandbox container
   Forget this and every number is roughly doubled.

2. working_set, not usage.

   container_memory_usage_bytes includes page cache that the kernel can
   reclaim under pressure. It looks like a memory leak and isn't.
   container_memory_working_set_bytes is what triggers OOMKill.
```

```promql
# CPU in cores, per pod
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="monitoring", container!=""}[5m])
)

# Memory, per pod
sum by (pod) (
  container_memory_working_set_bytes{namespace="monitoring", container!=""}
)
```

---

# node-exporter

A DaemonSet - one Pod per node - reading `/proc` and `/sys` from the host.

```yaml
hostNetwork: true
hostPID: true
volumeMounts:
- name: proc
  mountPath: /host/proc
  readOnly: true
```

It needs the host's namespaces and filesystems because a container's own
`/proc` shows the container, not the machine.

```text
node_cpu_seconds_total{mode="idle|user|system|iowait|steal"}
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
node_disk_io_time_seconds_total
node_network_receive_bytes_total
node_load1 / node_load5 / node_load15
node_time_seconds
```

### Node CPU: there is no "used" metric

```promql
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))
```

You measure idle and subtract it. `avg by (instance)` averages across the
per-core series.

```promql
# Memory used %
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Disk will be full within 4 hours?
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 4*3600) < 0

# Noisy-neighbour hypervisor (cloud VMs)
rate(node_cpu_seconds_total{mode="steal"}[5m]) > 0.1
```

`MemAvailable` is the right metric - `MemFree` excludes cache the kernel would
happily reclaim and will make a healthy node look full.

### Why a DaemonSet, and why tolerations

```yaml
tolerations:
- operator: Exists
```

Without a blanket toleration, node-exporter will not schedule onto tainted
control-plane nodes - and those are exactly the nodes whose disk filling up
takes down the cluster.

---

# kube-state-metrics

A Deployment that watches the API server and exports **object state**. It
knows nothing about usage.

```text
kube_pod_info{pod, namespace, node, created_by_kind}
kube_pod_status_phase{phase="Pending|Running|Succeeded|Failed|Unknown"}
kube_pod_container_status_restarts_total
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}
kube_pod_container_resource_requests{resource="cpu|memory"}
kube_pod_container_resource_limits{resource="cpu|memory"}
kube_deployment_spec_replicas
kube_deployment_status_replicas_available
kube_node_status_condition{condition="Ready", status="true"}
kube_node_status_allocatable{resource="cpu|memory"}
kube_hpa_status_current_replicas
kube_job_status_failed
kube_persistentvolumeclaim_status_phase
```

Queries you will reuse constantly:

```promql
# Deployments not at full strength
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# Anything crash-looping
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} > 0

# Nodes not Ready
kube_node_status_condition{condition="Ready", status="true"} == 0

# How much of the cluster is REQUESTED (not used)
sum(kube_pod_container_resource_requests{resource="cpu"})
  /
sum(kube_node_status_allocatable{resource="cpu"})

# Failed jobs in the last day
increase(kube_job_status_failed[1d]) > 0
```

That "requested vs allocatable" query is the one that tells you whether you
can schedule anything new - which has nothing to do with actual usage.

### kube-state-metrics is not an exporter of itself

```text
Port 8080 -> the Kubernetes object metrics (what you want)
Port 8081 -> kube-state-metrics' OWN health/process metrics
```

Annotating the wrong port gives you a healthy target with none of the metrics
you were looking for.

---

# metrics-server vs Prometheus

These are constantly confused.

| | metrics-server | Prometheus |
|---|---|---|
| Purpose | feed HPA and `kubectl top` | observability |
| Storage | in-memory, ~1 minute | TSDB, weeks |
| History | none | full |
| Query language | none | PromQL |
| API | Kubernetes Metrics API | own HTTP API |

```text
kubectl top pod       -> metrics-server
Grafana dashboard     -> Prometheus

You run BOTH. HPA cannot read Prometheus without an adapter.
```

To scale on your *own* metrics (requests/second, queue depth) you install the
**prometheus-adapter**, which exposes Prometheus queries through the
Kubernetes custom metrics API so an HPA can target them:

```yaml
metrics:
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "100"
```

That is the bridge between Project 05 (HPA) and this one.

---

# Joining Across Sources

The real power is combining them.

### Memory usage as a fraction of the configured limit

```promql
container_memory_working_set_bytes{container!=""}
  / on(namespace, pod, container) group_left
kube_pod_container_resource_limits{resource="memory"}
```

```text
left  = cAdvisor     (actual usage)
right = kube-state-metrics (configured limit)
```

They only join because both carry `namespace`, `pod` and `container` labels -
which is exactly what the `labelmap` and `replace` relabel rules in doc 05
were for.

### Are my CPU requests honest?

```promql
sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
  /
sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})
```

```text
<< 1   you are reserving capacity you never use - money wasted
>> 1   you are relying on overcommit - the first busy neighbour hurts you
```

### Pods on a node vs the node's own numbers

```promql
sum by (node) (container_memory_working_set_bytes{container!=""})
  /
on(node) group_left
sum by (node) (kube_node_status_allocatable{resource="memory"})
```

---

# Key Takeaways

```text
1. Four sources: app, cAdvisor, node-exporter, kube-state-metrics.
   They do not overlap - learn which answers which question.
2. cAdvisor is in the kubelet; filter container!="" and use working_set.
3. node-exporter is a DaemonSet with host /proc and /sys mounted.
4. kube-state-metrics reports DESIRED state, never usage.
5. metrics-server powers HPA and kubectl top; Prometheus powers everything
   else. Run both.
6. Cross-source joins need matching labels - that is what relabeling buys you.
```

---

# Interview Questions

**Q: Difference between metrics-server and Prometheus?**
metrics-server keeps about a minute of data in memory purely to serve the
Kubernetes Metrics API for HPA and `kubectl top`. Prometheus is a full TSDB
with history and PromQL. They solve different problems; clusters run both.

**Q: Where does `container_cpu_usage_seconds_total` come from?**
cAdvisor, which is embedded in the kubelet and exposed at
`/metrics/cadvisor`.

**Q: Why is kube-state-metrics needed when cAdvisor exists?**
cAdvisor reports runtime resource usage. kube-state-metrics reports the state
of API objects - replica counts, phases, restart counts, configured limits -
which usage metrics cannot tell you.

**Q: Why use working_set instead of usage for memory?**
`container_memory_usage_bytes` includes reclaimable page cache, so it
overstates pressure. `working_set` is what the kernel's OOM killer uses.

**Q: How do you autoscale on a custom application metric?**
Install prometheus-adapter to expose a PromQL query through the custom metrics
API, then reference that metric in the HPA.
