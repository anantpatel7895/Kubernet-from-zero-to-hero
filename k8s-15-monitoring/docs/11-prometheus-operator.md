# 11 - The Prometheus Operator and kube-prometheus-stack

---

# Learning Objectives

* What an Operator is and why monitoring needed one
* The CRDs: Prometheus, ServiceMonitor, PodMonitor, PrometheusRule
* How the Operator turns a CR into the config you hand-wrote
* Installing kube-prometheus-stack
* The label-selector trap that bites everyone
* When to use the hand-rolled setup instead

---

# Why an Operator

Everything in this project so far has been manual:

```text
write scrape_configs with relabel rules   ->  ConfigMap
write alert rules                          ->  ConfigMap
deploy Prometheus                          ->  Deployment
reload after every change                  ->  POST /-/reload by hand
add a new service                          ->  edit the central ConfigMap
```

That last line is the real problem. In a cluster with 30 teams, one central
ConfigMap of scrape configs is a bottleneck and a merge-conflict factory.

An **Operator** is a controller plus CustomResourceDefinitions that encodes
operational knowledge:

```text
you declare:   "scrape every Service labelled app=payments, every 30s"
operator does: generates the scrape_config, writes the Secret,
               reloads Prometheus, every time anything changes
```

---

# The Custom Resources

```text
Prometheus          the server itself: replicas, retention, storage, which
                    ServiceMonitors to select
Alertmanager        the Alertmanager cluster
ServiceMonitor      scrape the endpoints behind a Service
PodMonitor          scrape Pods directly (no Service needed)
PrometheusRule      recording + alerting rules
Probe               blackbox-probe a set of targets
AlertmanagerConfig  namespaced routing/receivers - teams own their own
ThanosRuler         rule evaluation against Thanos
```

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-app
  namespace: monitoring
  labels:
    release: kps              # how the Prometheus CR finds this object
spec:
  selector:
    matchLabels:
      app: metrics-app        # which SERVICES to scrape
  namespaceSelector:
    matchNames:
    - monitoring
  endpoints:
  - port: http                # the service port NAME, not the number
    path: /metrics
    interval: 15s
```

Compare that to the 25 lines of relabel rules it replaces. The Operator
generates those rules for you - identical in spirit to what you wrote in
doc 05.

```text
The chain:
  ServiceMonitor -> selects Services by LABEL
                 -> Service selects Pods by LABEL
                 -> Prometheus scrapes those Pods' endpoints

Three label hops. Any one of them wrong = no target.
```

### PodMonitor

Same idea, but it skips the Service entirely. Use it for things that have no
Service - a DaemonSet exporter, a Job.

### PrometheusRule

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: metrics-app-rules
  labels:
    release: kps
spec:
  groups:
  - name: metrics-app.alerts
    rules:
    - alert: HighErrorRate
      expr: ...
      for: 2m
```

The body of `spec.groups` is **byte-for-byte the rule format from doc 07**.
Nothing new to learn - it is the same YAML in a different wrapper.

---

# kube-prometheus-stack

The Helm chart that bundles everything:

```text
Prometheus Operator
Prometheus (via a Prometheus CR)
Alertmanager (via an Alertmanager CR)
Grafana + a large set of pre-built dashboards
node-exporter (DaemonSet)
kube-state-metrics
~100 battle-tested alerting rules for Kubernetes itself
ServiceMonitors for every control-plane component
```

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f values.yaml
```

A starting `values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: 40GB

    # Scrape ServiceMonitors from ALL namespaces, not just the chart's own.
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        memory: 4Gi

grafana:
  adminPassword: ""        # leave empty; set via an existing Secret
  persistence:
    enabled: true
    size: 10Gi

alertmanager:
  config:
    route:
      group_by: ["alertname", "namespace"]
      receiver: slack
    receivers:
    - name: slack
      slack_configs:
      - api_url_file: /etc/alertmanager/secrets/slack/url
        channel: "#alerts"
```

```text
Those three *NilUsesHelmValues: false lines are the single most common
fix people search for. By default the chart only picks up objects carrying
its own release label; setting them to false makes Prometheus watch
everything in the cluster.
```

---

# The Label-Selector Trap

```text
Symptom: "I created a ServiceMonitor and nothing happened."
```

Debug in this order:

```bash
# 1. What does the Prometheus CR actually select?
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitorSelector

# 2. Does your ServiceMonitor carry that label?
kubectl get servicemonitor -n monitoring --show-labels

# 3. Does the ServiceMonitor's selector match a real Service?
kubectl get svc -n monitoring --show-labels

# 4. Does the Service have endpoints at all?
kubectl get endpoints -n monitoring metrics-app

# 5. Did the Operator generate the scrape config?
kubectl get secret -n monitoring prometheus-kps-kube-prometheus-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep -A5 metrics-app
```

Step 5 is the trick worth remembering: the Operator writes the generated
config into a gzipped Secret. Reading it tells you immediately whether the
problem is "the Operator never saw my CR" or "the scrape itself fails".

```text
Other frequent causes:

* `port:` must be the NAME of the Service port, not the number.
  ports: [{name: http, port: 8000}]  ->  endpoints: [{port: http}]

* namespaceSelector defaults to the ServiceMonitor's own namespace.
  Use `namespaceSelector: {any: true}` to go cluster-wide.

* The Service selects no Pods -> no endpoints -> nothing to scrape, and
  the ServiceMonitor looks "fine".
```

---

# Operator vs Hand-Rolled

| | Hand-rolled (this project) | Operator |
|---|---|---|
| Learning value | **high** - you see every mechanism | low until it breaks |
| Adding a service | edit a central ConfigMap | ship a ServiceMonitor with the app |
| Config reload | manual `/-/reload` | automatic |
| Multi-team ownership | painful | natural - each team owns its CRs |
| Upgrades | you own everything | chart handles it |
| Debugging | read the config | read the CR *and* the generated config |
| Extra moving parts | none | CRDs + controller |

```text
In production: use kube-prometheus-stack. Almost always.

But the Operator generates exactly the scrape_configs and relabel rules
you wrote by hand here. When a ServiceMonitor silently produces no target,
the only way out is understanding what it was supposed to generate.
That is why this project does it the hard way first.
```

---

# Trying It

`k8s/servicemonitor-example.yaml` is **not** applied by the smoke test - the
CRDs do not exist in this project's stack. To experiment:

```bash
# Install the operator stack in a separate namespace
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring-operator --create-namespace

# Confirm the CRDs landed
kubectl get crd | grep monitoring.coreos.com

# Now the ServiceMonitor is a valid object
kubectl apply -f k8s/servicemonitor-example.yaml

# Find it in the new Prometheus: Status -> Targets
kubectl port-forward -n monitoring-operator svc/kps-kube-prometheus-prometheus 9091:9090
```

Remember to match the `release:` label in the ServiceMonitor to your Helm
release name, or set the selector values to `false` as shown above.

---

# Key Takeaways

```text
1. An Operator = CRDs + a controller encoding operational knowledge.
2. ServiceMonitor/PodMonitor replace hand-written scrape_configs;
   PrometheusRule replaces the rules ConfigMap.
3. The Operator generates the same relabel rules you wrote in doc 05.
4. kube-prometheus-stack is the production default - one Helm install.
5. The #1 failure is a label-selector mismatch between the Prometheus CR,
   the ServiceMonitor, the Service and the Pods.
6. Read the generated config out of the gzipped Secret when debugging.
```

---

# Interview Questions

**Q: What is a ServiceMonitor?**
A custom resource that tells the Prometheus Operator to scrape the endpoints
behind Services matching a label selector. The Operator turns it into scrape
config with relabel rules and reloads Prometheus.

**Q: ServiceMonitor vs PodMonitor?**
ServiceMonitor goes through a Service's endpoints; PodMonitor targets Pods
directly and is used when there is no Service.

**Q: You created a ServiceMonitor and no target appeared. What now?**
Check the Prometheus CR's `serviceMonitorSelector` against the
ServiceMonitor's labels, check the ServiceMonitor's selector against the
Service's labels, confirm the Service has endpoints, confirm `port` is the
port *name*, then read the generated config from the Operator's Secret.

**Q: Why learn the manual setup if the Operator exists?**
Because the Operator only generates the manual configuration. Every
non-trivial debugging session ends in reading relabel rules.
