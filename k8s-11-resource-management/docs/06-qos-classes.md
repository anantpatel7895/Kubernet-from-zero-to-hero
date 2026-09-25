# 06 - QoS Classes (Quality of Service)

---

# Learning Objectives

By the end of this lab you will understand:

* What QoS Classes are
* Why Kubernetes created QoS
* BestEffort Pods
* Burstable Pods
* Guaranteed Pods
* How Kubernetes assigns QoS
* Eviction priority under node pressure
* QoS vs PriorityClass
* Multi-container QoS calculations
* Common QoS misconceptions
* Production QoS strategies

---

# What Is QoS?

QoS stands for:

```text
Quality Of Service
```

Kubernetes uses QoS to decide:

```text
Who Gets Evicted First

When Resources Become Scarce
```

---

Imagine a node:

```text
CPU: 4
Memory: 8Gi
```

Suddenly:

```text
Memory Usage = 100%
```

Node is in trouble.

Kubernetes must decide:

```text
Which Pods Stay

Which Pods Go
```

QoS helps make that decision.

---

# Why QoS Exists

Without QoS:

```text
Critical Database

Random Test Container

Temporary Batch Job
```

would all be treated equally.

That would be dangerous.

Instead Kubernetes ranks Pods.

---

# The Three QoS Classes

```text
Guaranteed

Burstable

BestEffort
```

Think of them as:

```text
First Class

Business Class

Economy Class
```

---

# Eviction Order

Under resource pressure:

```text
BestEffort
↓

Burstable
↓

Guaranteed
```

---

Most important rule:

```text
Guaranteed
≠
Never Evicted
```

It means:

```text
Evicted Last
```

Not:

```text
Immortal
```

---

# BestEffort

Lowest QoS class.

Pod:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: qos-besteffort

spec:
  containers:
  - name: app
    image: busybox

    command:
    - sh
    - -c
    - sleep 3600
```

Notice:

```text
No Requests

No Limits
```

---

# Rule For BestEffort

Every container must have:

```text
No Requests

No Limits
```

---

Deploy

```bash
kubectl apply \
-f k8s/qos-besteffort.yaml \
-n resource-demo
```

---

Verify

```bash
kubectl get pod qos-besteffort \
-o jsonpath='{.status.qosClass}'
```

Expected:

```text
BestEffort
```

---

# Why BestEffort Is Dangerous

Scheduler reserves:

```text
Nothing
```

Runtime limit:

```text
Nothing
```

Container may:

```text
Consume Huge Resources
```

until node pressure occurs.

---

# Production Use Cases

Acceptable:

```text
Temporary Testing

Debug Containers

Short Batch Jobs

Experiments
```

Avoid for:

```text
Production APIs

Databases

Critical Services
```

---

# Burstable

Most common QoS class.

Example:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"

  limits:
    cpu: "500m"
    memory: "512Mi"
```

---

Deploy

```bash
kubectl apply \
-f k8s/qos-burstable.yaml \
-n resource-demo
```

---

Verify

```bash
kubectl get pod qos-burstable \
-o jsonpath='{.status.qosClass}'
```

Expected:

```text
Burstable
```

---

# Rule For Burstable

At least one container defines:

```text
Request

OR

Limit
```

but:

```text
Requests != Limits
```

or

```text
Not Every Resource Matches
```

---

Example

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "500m"
```

Result:

```text
Burstable
```

---

# Why Burstable Exists

Most applications:

```text
Need Small Guaranteed Capacity

But Occasionally Burst
```

Example:

```text
Normal CPU

100m
```

Peak:

```text
500m
```

Burstable perfectly fits.

---

# Guaranteed

Highest QoS class.

Example:

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"

  limits:
    cpu: "250m"
    memory: "256Mi"
```

---

Deploy

```bash
kubectl apply \
-f k8s/qos-guaranteed.yaml \
-n resource-demo
```

---

Verify

```bash
kubectl get pod qos-guaranteed \
-o jsonpath='{.status.qosClass}'
```

Expected:

```text
Guaranteed
```

---

# Rule For Guaranteed

Every container must define:

```text
CPU Request
CPU Limit

Memory Request
Memory Limit
```

AND

```text
Request = Limit
```

for both resources.

---

Example

Valid:

```yaml
requests:
  cpu: "500m"
  memory: "512Mi"

limits:
  cpu: "500m"
  memory: "512Mi"
```

---

Invalid:

```yaml
requests:
  cpu: "500m"

limits:
  cpu: "1000m"
```

Result:

```text
Burstable
```

Not Guaranteed.

---

# Visual Comparison

BestEffort

```text
Request = None

Limit = None
```

---

Burstable

```text
Request = Some

Limit = Some
```

but:

```text
Request != Limit
```

---

Guaranteed

```text
Request = Limit
```

for:

```text
CPU

AND

Memory
```

---

# Verify All QoS Classes

Deploy:

```bash
kubectl apply \
-f k8s/qos-besteffort.yaml \
-f k8s/qos-burstable.yaml \
-f k8s/qos-guaranteed.yaml \
-n resource-demo
```

---

Check:

```bash
kubectl get pod \
-o custom-columns=\
NAME:.metadata.name,\
QOS:.status.qosClass \
-n resource-demo
```

Expected:

```text
NAME              QOS

qos-besteffort    BestEffort

qos-burstable     Burstable

qos-guaranteed    Guaranteed
```

---

# Node Pressure Example

Node Memory:

```text
8Gi
```

Usage:

```text
7.9Gi
```

New allocation:

```text
500Mi
```

Impossible.

Node enters:

```text
MemoryPressure
```

---

Kubernetes begins evictions.

Order:

```text
BestEffort

↓

Burstable

↓

Guaranteed
```

---

# Important Truth

Many engineers believe:

```text
Guaranteed Pods
Cannot Be Evicted
```

False.

They can be evicted.

They are simply:

```text
Last To Be Evicted
```

---

# QoS vs PriorityClass

These are different.

QoS:

```text
Automatically Assigned
```

based on:

```text
Requests

Limits
```

---

PriorityClass:

```text
Manually Assigned
```

using:

```yaml
priorityClassName:
```

---

Example:

```text
Guaranteed
Low Priority
```

can lose to:

```text
Burstable
High Priority
```

depending on scenario.

---

# Multi-Container Pod Example

Pod:

```yaml
containers:

- name: app

  requests:
    cpu: "100m"

  limits:
    cpu: "100m"

- name: sidecar

  requests:
    cpu: "50m"

  limits:
    cpu: "200m"
```

---

Question:

QoS?

Answer:

```text
Burstable
```

---

Why?

Because:

```text
One Container

Breaks Guaranteed Rule
```

---

# Common QoS Trap

Container A:

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "100m"
```

---

Container B:

```yaml
requests:
  cpu: "50m"

limits:
  cpu: "100m"
```

---

Whole Pod:

```text
Burstable
```

Not Guaranteed.

QoS is determined:

```text
For Entire Pod
```

---

# Init Container Edge Case

Init container:

```yaml
requests:
  cpu: "2"
```

Main container:

```yaml
requests:
  cpu: "100m"
```

QoS classification still follows:

```text
Requests

Limits

Equality Rules
```

for all containers.

---

# Production Recommendations

---

## BestEffort

Good For:

```text
Debug Pods

Experiments

Temporary Jobs
```

---

## Burstable

Good For:

```text
Most Microservices

Web APIs

Background Workers
```

---

## Guaranteed

Good For:

```text
Databases

Kafka

Redis

Critical Services

Latency Sensitive Workloads
```

---

# Troubleshooting

---

## Pod Evicted

Check:

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
Reason:
Evicted
```

---

Check QoS:

```bash
kubectl get pod POD_NAME \
-o jsonpath='{.status.qosClass}'
```

---

Question:

```text
Was It BestEffort?
```

Likely candidate.

---

## Unexpected Burstable

Check:

```bash
kubectl describe pod POD_NAME
```

Verify:

```text
Request = Limit

For CPU

AND

Memory
```

---

# Common Mistakes

---

## Assuming Guaranteed Means Safe Forever

False.

Guaranteed only means:

```text
Evict Last
```

---

## BestEffort In Production

Common beginner mistake.

Result:

```text
First Evicted
```

under pressure.

---

## Forgetting Memory Equality

Example:

```yaml
cpu:
  request = limit
```

but:

```yaml
memory:
  request != limit
```

Result:

```text
Burstable
```

---

## Looking Only At Requests

Guaranteed requires:

```text
CPU Equality

AND

Memory Equality
```

---

# Interview Questions

---

## What Are The Three QoS Classes?

Answer:

```text
BestEffort

Burstable

Guaranteed
```

---

## Which QoS Is Highest?

Answer:

```text
Guaranteed
```

---

## Which QoS Is Lowest?

Answer:

```text
BestEffort
```

---

## What Gets Evicted First?

Answer:

```text
BestEffort
```

---

## What Gets Evicted Last?

Answer:

```text
Guaranteed
```

---

## How Do You Create A Guaranteed Pod?

Answer:

```text
All Containers

Request = Limit

For CPU And Memory
```

---

## Can Guaranteed Pods Be Evicted?

Answer:

```text
Yes

Last To Be Evicted
```

---

## Is QoS Manually Assigned?

Answer:

```text
No

Automatically Calculated
```

---

## Does PriorityClass Change QoS?

Answer:

```text
No

Separate Concepts
```

---

# Cleanup

```bash
kubectl delete pod \
qos-besteffort \
qos-burstable \
qos-guaranteed \
-n resource-demo
```

---

# Key Takeaways

```text
BestEffort
=
No Requests
No Limits

Burstable
=
Some Requests/Limits

Guaranteed
=
Request = Limit

Eviction Order

BestEffort
↓

Burstable
↓

Guaranteed

QoS
≠
PriorityClass

Guaranteed
≠
Never Evicted
```

QoS is Kubernetes' way of deciding which workloads are most important when resources become scarce. Understanding QoS is critical before learning about node pressure, evictions, and production resource management.
