# 10 - ResourceQuota

---

# Learning Objectives

By the end of this lab you will understand:

* What ResourceQuota is
* Why ResourceQuota exists
* Namespace resource governance
* Requests quotas
* Limits quotas
* Object count quotas
* Storage quotas
* Quota exhaustion
* Multi-team cluster management
* How ResourceQuota interacts with LimitRange
* Production quota strategies
* Troubleshooting quota failures
* Interview questions related to ResourceQuota

---

# What Problem Does ResourceQuota Solve?

Imagine a shared Kubernetes cluster.

Teams:

```text id="tk8x2e"
Team A

Team B

Team C

Team D
```

All use:

```text id="a8g1pj"
Same Cluster
```

---

Team A deploys:

```text id="s7yj7v"
500 Pods
```

---

Team B deploys:

```text id="d3qp7k"
200 Services
```

---

Team C deploys:

```text id="w9j41v"
Massive Stateful Workloads
```

---

Result:

```text id="3a1gb5"
Cluster Capacity Exhausted
```

Other teams cannot deploy.

---

Need:

```text id="6m1rgs"
Fair Resource Allocation
```

This is where:

```text id="rf4g4s"
ResourceQuota
```

comes in.

---

# What Is ResourceQuota?

ResourceQuota is a:

```text id="k6k5n9"
Namespace-Level Limit
```

that controls:

```text id="4k4dfj"
How Much

A Namespace

Can Consume
```

---

Think of it like:

```text id="pkd39s"
Cloud Budget Limits
```

for a namespace.

---

# LimitRange vs ResourceQuota

Many beginners confuse them.

---

LimitRange:

```text id="d4i54m"
Rules Per Pod

Rules Per Container
```

---

ResourceQuota:

```text id="6lpk5v"
Rules For Entire Namespace
```

---

Example

LimitRange:

```text id="7vcnk0"
Each Container

Must Request

At Least

100m CPU
```

---

ResourceQuota:

```text id="ghlq7q"
Namespace

Can Use

At Most

4 CPU
```

---

# Current Project ResourceQuota

File:

```text id="hfj8sl"
k8s/resourcequota.yaml
```

---

Example:

```yaml id="i5v8lk"
apiVersion: v1
kind: ResourceQuota

metadata:
  name: resource-quota

spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi

    limits.cpu: "4"
    limits.memory: 4Gi

    pods: "10"
```

---

Meaning:

Namespace can consume:

```text id="bjzj74"
Requests CPU

Maximum 2
```

---

Memory Requests:

```text id="3m6h9v"
Maximum 2Gi
```

---

CPU Limits:

```text id="k2f4xa"
Maximum 4 CPU
```

---

Memory Limits:

```text id="8mjlwm"
Maximum 4Gi
```

---

Maximum Pods:

```text id="m3z0hv"
10
```

---

# Deploy ResourceQuota

Create namespace:

```bash id="u6lrm2"
kubectl apply -f k8s/namespace.yaml
```

---

Apply quota:

```bash id="rsh9o7"
kubectl apply \
-f k8s/resourcequota.yaml
```

---

Verify:

```bash id="92m2u3"
kubectl get resourcequota \
-n resource-demo
```

Expected:

```text id="c54p4v"
resource-quota
```

---

Describe quota:

```bash id="ymm1pt"
kubectl describe resourcequota \
resource-quota \
-n resource-demo
```

---

Example:

```text id="0o1hry"
Resource
Used
Hard

requests.cpu

500m

2
```

---

# Understanding Used vs Hard

Hard:

```text id="mkd6i0"
Maximum Allowed
```

---

Used:

```text id="tx4w0w"
Current Consumption
```

---

Example:

```text id="jsfcbw"
Used CPU

1.2
```

---

Hard:

```text id="pw6n1o"
2
```

---

Remaining:

```text id="0bzfj8"
800m
```

---

# Create Quota Consumption

Deployment:

```yaml id="e9w9w6"
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
```

---

Replicas:

```yaml id="l9c8cv"
replicas: 2
```

---

Total requests:

```text id="v4nqhj"
CPU

1 Core
```

---

Memory:

```text id="y2oqv0"
1Gi
```

---

Verify:

```bash id="a9zjlwm"
kubectl describe resourcequota \
resource-quota \
-n resource-demo
```

---

Used values increase.

---

# Quota Exhaustion Example

Current quota:

```text id="f7g3yk"
requests.cpu = 2
```

---

Already consumed:

```text id="h9r2ld"
1.8 CPU
```

---

Deploy:

```yaml id="v0oj6m"
requests:
  cpu: "500m"
```

---

Total would become:

```text id="qg5u3e"
2.3 CPU
```

---

Quota exceeded.

---

Deploy:

```bash id="a2y8pj"
kubectl apply \
-f deployment.yaml
```

---

Expected:

```text id="3x1sl8"
Forbidden
```

---

Error:

```text id="1bsk0h"
Exceeded quota
```

---

Example:

```text id="rfqkmi"
requested:

cpu=500m

used:

cpu=1800m

limited:

cpu=2
```

---

# Why Quotas Matter

Without quotas:

```text id="vgsu0t"
One Team

Consumes Everything
```

---

With quotas:

```text id="3gqkl3"
Fair Resource Sharing
```

---

# Pod Count Quotas

ResourceQuota can limit:

```yaml id="4e6o9k"
pods: "10"
```

---

Meaning:

```text id="e6e5r3"
Maximum

10 Pods
```

---

Current count:

```text id="4mjlwm"
10 Pods
```

---

Create one more:

```bash id="z2qwe9"
kubectl apply -f pod.yaml
```

---

Result:

```text id="v7xjlwm"
Forbidden
```

---

Quota exceeded.

---

# Service Quotas

Example:

```yaml id="j5f91g"
services: "20"
```

---

Namespace cannot create:

```text id="v4s3jk"
More Than 20 Services
```

---

# PVC Quotas

Example:

```yaml id="v8df7w"
persistentvolumeclaims: "5"
```

---

Maximum:

```text id="4jpw4x"
5 PVCs
```

---

# Storage Quotas

Example:

```yaml id="p6dk8r"
requests.storage: 100Gi
```

---

Namespace storage limit:

```text id="8hjlwm"
100Gi
```

---

PVC requests:

```text id="7k3d0e"
10Gi

20Gi

30Gi
```

---

Total:

```text id="6tjlwm"
60Gi
```

Allowed.

---

Request:

```text id="n9jlwm"
50Gi More
```

---

Total:

```text id="p7xjlwm"
110Gi
```

Rejected.

---

# Quota And LimitRange Together

Most production clusters use:

```text id="2a9jlwm"
ResourceQuota

+

LimitRange
```

---

LimitRange:

```text id="3mjlwm"
Per Workload Rules
```

---

ResourceQuota:

```text id="7zjlwm"
Namespace Budget
```

---

Example

LimitRange:

```yaml id="n1mjlwm"
defaultRequest:
  cpu: "100m"
```

---

ResourceQuota:

```yaml id="r8jlwm"
requests.cpu: "4"
```

---

Maximum workloads:

```text id="5yjlwm"
Approximately 40 Pods
```

---

# Object Count Quotas

ResourceQuota can control:

```text id="8xjlwm"
Pods

Services

PVCs

Secrets

ConfigMaps
```

---

Example:

```yaml id="f4jlwm"
configmaps: "50"
```

---

Maximum:

```text id="q6jlwm"
50 ConfigMaps
```

---

Useful for:

```text id="n2jlwm"
Preventing Resource Sprawl
```

---

# Production Team Model

Namespace:

```text id="b1jlwm"
team-a
```

Quota:

```yaml id="g8jlwm"
requests.cpu: "8"
requests.memory: 16Gi
```

---

Namespace:

```text id="y4jlwm"
team-b
```

Quota:

```yaml id="h5jlwm"
requests.cpu: "4"
requests.memory: 8Gi
```

---

Result:

```text id="u7jlwm"
Predictable Resource Allocation
```

---

# Monitoring Quotas

Check quota:

```bash id="w9jlwm"
kubectl describe resourcequota \
-n resource-demo
```

---

View all:

```bash id="s3jlwm"
kubectl get resourcequota \
-A
```

---

# Troubleshooting

---

## Deployment Fails

Check:

```bash id="d4jlwm"
kubectl describe resourcequota \
-n resource-demo
```

---

Look for:

```text id="f9jlwm"
Used

Hard
```

---

Question:

```text id="v1jlwm"
Quota Exhausted?
```

---

## Pods Not Creating

Check deployment:

```bash id="m6jlwm"
kubectl describe deployment \
DEPLOYMENT_NAME
```

---

Events may show:

```text id="k3jlwm"
Exceeded Quota
```

---

## Namespace Full

Check:

```bash id="j8jlwm"
kubectl get pods \
-n resource-demo
```

---

Question:

```text id="z4jlwm"
Pod Count Limit Reached?
```

---

# Common Mistakes

---

## No Quotas In Shared Cluster

Result:

```text id="p1jlwm"
Resource Starvation
```

---

## Extremely Small Quotas

Example:

```yaml id="e3jlwm"
requests.cpu: "500m"
```

---

Result:

```text id="a2jlwm"
Developers Cannot Deploy
```

---

## Ignoring Used Values

Engineers check:

```text id="n5jlwm"
Hard
```

but forget:

```text id="b8jlwm"
Used
```

---

## Quota Without LimitRange

Problem:

```text id="r2jlwm"
No Resource Standards
```

---

# Interview Questions

---

## What Is ResourceQuota?

Answer:

```text id="u5jlwm"
Namespace Resource Consumption Limit
```

---

## What Does ResourceQuota Control?

Answer:

```text id="k7jlwm"
CPU

Memory

Storage

Object Counts
```

---

## Is ResourceQuota Namespace Scoped?

Answer:

```text id="t4jlwm"
Yes
```

---

## Difference Between LimitRange And ResourceQuota?

Answer:

```text id="q3jlwm"
LimitRange

Per Pod Rules

ResourceQuota

Namespace Budget
```

---

## What Happens When Quota Is Exceeded?

Answer:

```text id="h2jlwm"
Resource Creation Rejected
```

---

## How Do You Check Quota Usage?

Answer:

```bash id="y6jlwm"
kubectl describe resourcequota
```

---

## Can ResourceQuota Limit Pod Count?

Answer:

```text id="m1jlwm"
Yes
```

---

## Why Use ResourceQuota?

Answer:

```text id="g4jlwm"
Fair Resource Allocation
```

---

# Cleanup

Delete quota:

```bash id="c8jlwm"
kubectl delete resourcequota \
resource-quota \
-n resource-demo
```

---

Delete namespace:

```bash id="v9jlwm"
kubectl delete namespace resource-demo
```

---

# Key Takeaways

```text id="r5jlwm"
LimitRange
=
Per Pod Governance

ResourceQuota
=
Namespace Governance

Quota Tracks

Used

Hard

Quota Exceeded
=
Resource Creation Rejected

Shared Clusters
=
Use ResourceQuota

Production
=
LimitRange + ResourceQuota
```

ResourceQuota is the foundation of multi-tenant Kubernetes clusters because it prevents one team, application, or namespace from consuming all available resources and impacting other workloads.
