# 11 - Multi-Container Resources

---

# Learning Objectives

By the end of this lab you will understand:

* How Kubernetes calculates resources for multi-container Pods
* Sidecar containers
* Service mesh overhead
* Logging sidecars
* Monitoring sidecars
* Effective Pod requests
* Effective Pod limits
* Scheduling calculations
* QoS calculation for multi-container Pods
* Resource planning for production workloads
* Common multi-container mistakes
* Interview questions related to multi-container resource management

---

# Why This Topic Matters

Many Kubernetes beginners think:

```text id="a1"
Pod
=
Container
```

This is wrong.

A Pod can contain:

```text id="a2"
1 Container

2 Containers

5 Containers

10 Containers
```

or more.

---

Real production Pods often include:

```text id="a3"
Application

Sidecar

Log Collector

Metrics Exporter

Service Mesh Proxy
```

inside the same Pod.

---

# Example Production Pod

```text id="a4"
Pod

├── Application
├── Envoy Sidecar
├── Fluent Bit
└── Metrics Exporter
```

---

Question:

How much CPU does this Pod need?

Answer:

```text id="a5"
Sum Of All Containers
```

---

# Most Important Rule

Scheduler does NOT schedule:

```text id="a6"
Containers
```

Scheduler schedules:

```text id="a7"
Pods
```

---

Therefore:

```text id="a8"
Pod Request

=

Sum Of Container Requests
```

---

# Simple Example

Container A

```yaml id="a9"
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
```

---

Container B

```yaml id="a10"
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
```

---

Effective Pod Request

```text id="a11"
CPU

100m + 200m

=
300m
```

---

Memory

```text id="a12"
128Mi + 256Mi

=
384Mi
```

---

Scheduler sees:

```text id="a13"
CPU

300m

Memory

384Mi
```

---

# Multi-Container Demo

Create:

```yaml id="a14"
apiVersion: v1
kind: Pod

metadata:
  name: multi-container-demo

spec:
  containers:

  - name: app

    image: nginx

    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"

      limits:
        cpu: "200m"
        memory: "256Mi"

  - name: logger

    image: busybox

    command:
    - sh
    - -c
    - sleep 3600

    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"

      limits:
        cpu: "100m"
        memory: "128Mi"
```

---

Deploy:

```bash id="a15"
kubectl apply -f multi-container-demo.yaml
```

---

Verify:

```bash id="a16"
kubectl describe pod multi-container-demo
```

---

Effective Request:

```text id="a17"
CPU

150m
```

---

Memory:

```text id="a18"
192Mi
```

---

Effective Limit:

```text id="a19"
CPU

300m
```

---

Memory:

```text id="a20"
384Mi
```

---

# Why Sidecars Matter

Many production Pods use sidecars.

Example:

```text id="a21"
Istio Envoy Proxy
```

---

Typical Envoy usage:

```text id="a22"
CPU

100m - 500m

Memory

128Mi - 512Mi
```

---

Application:

```yaml id="a23"
requests:
  cpu: "100m"
  memory: "128Mi"
```

---

Envoy:

```yaml id="a24"
requests:
  cpu: "200m"
  memory: "256Mi"
```

---

Effective Pod Request:

```text id="a25"
CPU

300m
```

Memory:

```text id="a26"
384Mi
```

---

Many engineers forget:

```text id="a27"
Sidecar Resources
```

and under-size nodes.

---

# Logging Sidecars

Example:

```text id="a28"
Application

+

Fluent Bit
```

---

Application:

```yaml id="a29"
cpu: 100m
memory: 128Mi
```

---

Fluent Bit:

```yaml id="a30"
cpu: 50m
memory: 64Mi
```

---

Real Pod:

```text id="a31"
150m CPU

192Mi Memory
```

---

Not:

```text id="a32"
100m CPU

128Mi Memory
```

---

# Monitoring Sidecars

Examples:

```text id="a33"
Prometheus Exporters

OpenTelemetry Collectors

Custom Agents
```

---

These consume:

```text id="a34"
CPU

Memory

Disk
```

and must be included in calculations.

---

# Scheduling Example

Node:

```text id="a35"
CPU

2
```

---

Pod:

```text id="a36"
App

100m
```

Sidecar:

```text id="a37"
200m
```

---

Total:

```text id="a38"
300m
```

---

Question:

Can scheduler ignore sidecar?

Answer:

```text id="a39"
No
```

---

Scheduler sees:

```text id="a40"
300m
```

---

# QoS Calculation

Important rule:

```text id="a41"
QoS Calculated

For Entire Pod
```

---

Container A

```yaml id="a42"
requests:
  cpu: 100m

limits:
  cpu: 100m
```

---

Container B

```yaml id="a43"
requests:
  cpu: 50m

limits:
  cpu: 100m
```

---

Question:

QoS?

---

Answer:

```text id="a44"
Burstable
```

---

Why?

Because:

```text id="a45"
One Container

Violates Guaranteed Rules
```

---

# Guaranteed Example

Container A

```yaml id="a46"
requests:
  cpu: 100m
  memory: 128Mi

limits:
  cpu: 100m
  memory: 128Mi
```

---

Container B

```yaml id="a47"
requests:
  cpu: 50m
  memory: 64Mi

limits:
  cpu: 50m
  memory: 64Mi
```

---

QoS:

```text id="a48"
Guaranteed
```

---

Because:

```text id="a49"
Every Container

Request = Limit

For CPU And Memory
```

---

# Common Production Pattern

Pod:

```text id="a50"
Application

+

Service Mesh

+

Logging

+

Monitoring
```

---

Resources:

```text id="a51"
Application

100m CPU
```

```text id="a52"
Envoy

200m CPU
```

```text id="a53"
Fluent Bit

50m CPU
```

```text id="a54"
Exporter

50m CPU
```

---

Actual Pod:

```text id="a55"
400m CPU
```

Not:

```text id="a56"
100m CPU
```

---

# Capacity Planning Example

Cluster:

```text id="a57"
10 Nodes

4 CPU Each
```

---

Application Team Says:

```text id="a58"
100m CPU Per Pod
```

---

Reality:

```text id="a59"
100m App

200m Envoy

50m Logging

50m Monitoring
```

---

Total:

```text id="a60"
400m CPU
```

---

Planning Error:

```text id="a61"
4x Underestimated
```

---

Common cause of:

```text id="a62"
Unexpected Scaling

Pending Pods

High Costs
```

---

# Viewing Container Resources

Pod:

```bash id="a63"
kubectl describe pod POD_NAME
```

---

Shows:

```text id="a64"
Resources

Per Container
```

---

Container metrics:

```bash id="a65"
kubectl top pod POD_NAME \
--containers
```

---

Example:

```text id="a66"
app

80m
```

```text id="a67"
logger

40m
```

---

Useful for:

```text id="a68"
Resource Tuning
```

---

# Troubleshooting

---

## Pod Uses More CPU Than Expected

Check:

```bash id="a69"
kubectl top pod POD_NAME \
--containers
```

---

Question:

```text id="a70"
Sidecar Consuming Resources?
```

---

## Scheduler Cannot Place Pod

Check:

```bash id="a71"
kubectl describe pod POD_NAME
```

---

Remember:

```text id="a72"
Scheduler Uses

Total Pod Request
```

---

## Unexpected Burstable QoS

Check:

```bash id="a73"
kubectl get pod POD_NAME \
-o jsonpath='{.status.qosClass}'
```

---

Verify:

```text id="a74"
All Containers

Request = Limit
```

---

# Common Mistakes

---

## Ignoring Sidecars

Most common mistake.

Developers calculate:

```text id="a75"
Application Only
```

---

Reality:

```text id="a76"
Entire Pod
```

must be considered.

---

## Incorrect Capacity Planning

Ignoring:

```text id="a77"
Service Mesh

Logging

Monitoring
```

overhead.

---

## Guaranteed Assumptions

One container violates:

```text id="a78"
Request = Limit
```

---

Entire Pod becomes:

```text id="a79"
Burstable
```

---

## Monitoring Only Pod Total

Use:

```bash id="a80"
kubectl top pod \
--containers
```

to identify:

```text id="a81"
Resource-Hungry Sidecars
```

---

# Real Production Example

Microservice:

```text id="a82"
100m CPU
```

---

Istio:

```text id="a83"
250m CPU
```

---

OpenTelemetry:

```text id="a84"
100m CPU
```

---

Fluent Bit:

```text id="a85"
50m CPU
```

---

Actual Pod:

```text id="a86"
500m CPU
```

---

Application team reports:

```text id="a87"
100m CPU
```

Operations sees:

```text id="a88"
500m CPU
```

Both are correct.

They are measuring:

```text id="a89"
Different Things
```

---

# Interview Questions

---

## How Does Scheduler Calculate Pod Requests?

Answer:

```text id="a90"
Sum Of All Container Requests
```

---

## Does Scheduler Schedule Containers?

Answer:

```text id="a91"
No

Scheduler Schedules Pods
```

---

## What Is A Sidecar?

Answer:

```text id="a92"
Additional Container

Running In Same Pod
```

---

## Do Sidecars Affect Scheduling?

Answer:

```text id="a93"
Yes
```

---

## How Is QoS Determined For Multi-Container Pods?

Answer:

```text id="a94"
Entire Pod Evaluated
```

---

## Can One Container Change Pod QoS?

Answer:

```text id="a95"
Yes
```

---

## How Do You View Per-Container Usage?

Answer:

```bash id="a96"
kubectl top pod POD_NAME \
--containers
```

---

# Cleanup

```bash id="a97"
kubectl delete pod multi-container-demo
```

---

# Key Takeaways

```text id="a98"
Scheduler
=
Schedules Pods

Pod Request
=
Sum Of Container Requests

Pod Limit
=
Sum Of Container Limits

Sidecars
=
Count Toward Resources

QoS
=
Calculated For Entire Pod

Service Mesh
=
Resource Overhead

Logging
=
Resource Overhead

Monitoring
=
Resource Overhead
```

Understanding multi-container resource accounting is essential because most production Kubernetes workloads include sidecars, and ignoring their resource consumption is one of the most common causes of inaccurate capacity planning.
