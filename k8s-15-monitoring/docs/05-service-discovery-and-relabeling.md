# 05 - Service Discovery and Relabeling

---

# Learning Objectives

* Why static target lists cannot work in Kubernetes
* The five `kubernetes_sd_configs` roles
* What `__meta_*` labels are and where they come from
* Reading a relabel rule field by field
* The relabel actions: keep, drop, replace, labelmap, labeldrop
* `relabel_configs` vs `metric_relabel_configs`
* Debugging "my target is not showing up"

---

# The Problem

In a VM world you write this and go home:

```yaml
static_configs:
- targets: ["10.0.1.5:8000", "10.0.1.6:8000"]
```

In Kubernetes those IPs are gone after the next deploy. Pods are cattle:
scaled, rescheduled, re-IP'd, constantly.

So Prometheus asks the Kubernetes API *who exists right now*, continuously.

```text
Prometheus --watch--> Kubernetes API --> "here are all pods, with metadata"
                                     --> Prometheus rebuilds its target list
```

---

# The Five Roles

```yaml
kubernetes_sd_configs:
- role: pod
```

| Role | Produces one target per | Typical use |
|---|---|---|
| `node` | cluster node | kubelet, cAdvisor, node-exporter |
| `pod` | pod (every container port) | annotation-based scraping |
| `service` | service port | blackbox probing a Service |
| `endpoints` | backing endpoint of a Service | the standard for "scrape what this Service fronts" |
| `endpointslice` | endpoint slice entry | same, scales better |
| `ingress` | ingress path | blackbox probing public URLs |

This project uses `node` (kubelet + cAdvisor) and `pod` (everything else).

---

# `__meta_*` Labels

Discovery does not just return an IP. It returns the object's full metadata as
labels prefixed with `__meta_`:

```text
__meta_kubernetes_namespace="monitoring"
__meta_kubernetes_pod_name="metrics-app-7c9f8d5b4-4x2jk"
__meta_kubernetes_pod_ip="10.1.0.42"
__meta_kubernetes_pod_node_name="docker-desktop"
__meta_kubernetes_pod_phase="Running"
__meta_kubernetes_pod_label_app="metrics-app"
__meta_kubernetes_pod_annotation_prometheus_io_scrape="true"
__meta_kubernetes_pod_annotation_prometheus_io_port="8000"
__meta_kubernetes_pod_container_port_number="8000"
```

Plus three special ones:

```text
__address__        where to scrape      "10.1.0.42:8000"
__scheme__         http | https
__metrics_path__   the URL path         "/metrics"
```

### The underscore rule

```text
Labels starting with __ are TEMPORARY.
They are dropped after relabeling and never stored in the TSDB.
```

So relabeling is the step where you turn throwaway discovery metadata into
permanent, queryable labels - or into a decision to skip the target entirely.

Note the name mangling: annotation `prometheus.io/port` becomes
`__meta_kubernetes_pod_annotation_prometheus_io_port`. Dots and slashes become
underscores, because label names may only contain `[a-zA-Z0-9_]`.

---

# Anatomy of a Relabel Rule

```yaml
- source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
  action: keep
  regex: true
```

| Field | Meaning |
|---|---|
| `source_labels` | which labels to read; joined with `separator` (default `;`) |
| `regex` | pattern matched against that joined string (anchored, full match) |
| `action` | what to do on a match |
| `target_label` | which label to write (for `replace`) |
| `replacement` | the value to write; `$1`, `$2` are regex capture groups |

Rules run **top to bottom**, and each one sees the output of the previous one.

---

# The Actions

### keep / drop - filtering targets

```yaml
# Keep only pods that opted in
- source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
  action: keep
  regex: true

# Never scrape a pod that is not running
- source_labels: [__meta_kubernetes_pod_phase]
  action: drop
  regex: (Pending|Succeeded|Failed|Unknown)
```

```text
keep -> if the regex does NOT match, discard the target
drop -> if the regex DOES match, discard the target
```

### replace - writing a label

```yaml
- source_labels: [__meta_kubernetes_namespace]
  action: replace
  target_label: namespace
```

Promotes throwaway metadata to a permanent label on every sample from that
target. `replace` is the default action, so it is often omitted.

### The address rewrite - the clever one

```yaml
- source_labels:
  - __address__
  - __meta_kubernetes_pod_annotation_prometheus_io_port
  action: replace
  regex: ([^:]+)(?::\d+)?;(\d+)
  replacement: $1:$2
  target_label: __address__
```

Step by step:

```text
__address__ = "10.1.0.42:8000"
annotation  = "9100"

joined with ";"  ->  "10.1.0.42:8000;9100"

regex ([^:]+)(?::\d+)?;(\d+)
         $1 = 10.1.0.42
              (?::\d+)? discards the existing :8000
                     $2 = 9100

replacement "$1:$2" -> "10.1.0.42:9100"
written back to __address__
```

That is how one annotation changes the port Prometheus scrapes.

### labelmap - bulk copy

```yaml
- action: labelmap
  regex: __meta_kubernetes_pod_label_(.+)
```

Every pod label becomes a Prometheus label:

```text
__meta_kubernetes_pod_label_app="metrics-app"   ->  app="metrics-app"
__meta_kubernetes_pod_label_tier="backend"      ->  tier="backend"
```

Convenient, and a cardinality risk: pod-template-hash changes on every deploy,
and some tooling writes long labels onto every pod. Prefer explicit `replace`
rules in a large cluster.

### labeldrop / labelkeep - pruning labels

```yaml
- action: labeldrop
  regex: pod_template_hash
```

### hashmod - sharding

```yaml
- source_labels: [__address__]
  action: hashmod
  modulus: 4
  target_label: __tmp_shard
- source_labels: [__tmp_shard]
  action: keep
  regex: 0
```

Four Prometheus servers with `regex: 0..3` split the targets evenly between
them. This is how you scale scraping beyond one machine.

---

# relabel_configs vs metric_relabel_configs

This distinction is an interview favourite.

```text
relabel_configs
    runs BEFORE the scrape
    operates on TARGETS
    "should I scrape this, and with what labels?"

metric_relabel_configs
    runs AFTER the scrape, before storage
    operates on SAMPLES
    "should I keep this metric?"
```

Dropping an expensive metric you cannot turn off at the source:

```yaml
metric_relabel_configs:
# Drop a notoriously high-cardinality cAdvisor metric
- source_labels: [__name__]
  action: drop
  regex: container_network_tcp_usage_total

# Keep only the kube-state-metrics series you actually use
- source_labels: [__name__]
  action: keep
  regex: kube_(pod|deployment|node)_.*
```

```text
relabel_configs saves network and CPU (you never scrape it).
metric_relabel_configs saves memory and disk (you scrape it, then discard).
```

---

# Annotation-Based vs ServiceMonitor

What this project does by hand:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/metrics"
  prometheus.io/port: "8000"
```

| | Annotations | ServiceMonitor (Operator) |
|---|---|---|
| Needs a CRD | no | yes |
| Config lives in | one big ConfigMap of relabel rules | one small CR per service |
| Per-service auth/TLS/interval | awkward | native fields |
| Team ownership | central | each team ships its own CR |
| Learning value | you see how it really works | magic until you read doc 11 |

The Operator generates exactly the same relabel rules under the hood - which
is why learning them by hand is worth the hour.

---

# Debugging: "My Target Is Not There"

Work through this in order.

```text
1. Prometheus UI -> Status -> Service Discovery
   Is the pod listed under "Discovered labels" at all?

   NO  -> RBAC. Prometheus cannot list pods.
          kubectl auth can-i list pods \
            --as=system:serviceaccount:monitoring:prometheus
   YES -> continue.

2. Look at "Target labels" next to it. Empty / dropped?
   -> A `keep` rule rejected it. 99% of the time the annotation is
      missing, misspelled, or on the Deployment instead of the Pod TEMPLATE.

      WRONG: spec.template.spec.annotations
      WRONG: metadata.annotations on the Deployment
      RIGHT: spec.template.metadata.annotations

   Also: annotation values MUST be strings.
      prometheus.io/port: 8000     -> rejected by the API server
      prometheus.io/port: "8000"   -> correct

3. Target shows up but is RED (down)?
   Read the error text:
      "connection refused"  -> wrong port
      "404 Not Found"       -> wrong path
      "context deadline"    -> scrape_timeout too low, or app too slow
      "x509: certificate"   -> scheme/TLS mismatch

4. Target is UP but a metric is missing?
   -> metric_relabel_configs dropped it, or the app does not emit it.
      curl the endpoint from inside the cluster and grep.
```

Useful commands:

```bash
# What did discovery find, before relabeling?
kubectl port-forward -n monitoring svc/prometheus 9090:9090
open http://localhost:9090/service-discovery

# Is RBAC right?
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus -A

# What does the target actually serve?
kubectl run curl --rm -it --image=curlimages/curl --restart=Never -n monitoring \
  -- curl -s http://metrics-app:8000/metrics | head -20
```

---

# Key Takeaways

```text
1. Static targets are impossible in Kubernetes; discovery queries the API.
2. Discovery returns __meta_* labels - temporary, dropped after relabeling.
3. Relabel rules run in order; each sees the previous one's output.
4. keep/drop filter targets; replace/labelmap write labels.
5. relabel_configs = before the scrape. metric_relabel_configs = after.
6. Target missing? Check /service-discovery first, then RBAC, then the
   annotation's location and quoting.
```

---

# Interview Questions

**Q: How does Prometheus find Pods in Kubernetes?**
Through `kubernetes_sd_configs`, which watches the API server for the chosen
role and produces a target per object with `__meta_*` metadata labels.
Relabel rules then filter and rewrite that list.

**Q: Difference between relabel_configs and metric_relabel_configs?**
The first decides which targets to scrape and with what labels, before the
HTTP request. The second filters individual samples after the scrape, before
they are written to the TSDB.

**Q: How do you stop Prometheus scraping a noisy namespace?**
Add a `drop` relabel rule on `__meta_kubernetes_namespace`.

**Q: Your new service never appears as a target. Where do you look?**
Status -> Service Discovery in the Prometheus UI. If the pod is not there at
all it is an RBAC problem; if it is dropped, a `keep` rule rejected it -
usually a missing or misplaced `prometheus.io/scrape` annotation.
