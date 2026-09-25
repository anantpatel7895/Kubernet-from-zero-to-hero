# 03 - Memory OOMKill

---

# Learning Objectives

By the end of this lab you will understand:

* What an OOMKill is
* Why Kubernetes kills containers that exceed memory limits
* Difference between CPU throttling and memory enforcement
* How Linux Out Of Memory (OOM) Killer works
* How to identify OOMKilled containers
* How CrashLoopBackOff relates to OOMKills
* How to troubleshoot memory issues in production
* Common memory sizing mistakes
* Interview questions related to memory management

---

# Prerequisites

Complete:

```text
01-requests-vs-limits.md

02-cpu-throttling.md
```

You should already know:

```text
Request
=
Scheduling

Limit
=
Runtime Enforcement
```

---

# What Is Memory?

Memory (RAM) stores:

```text
Application code

Variables

Caches

Objects

Buffers

Runtime state
```

Example:

```text
Node

CPU: 4

RAM: 8Gi
```

Applications share this memory.

---

# Why Memory Is Different

CPU:

```text
Can Be Shared
```

Memory:

```text
Cannot Be Shared Beyond Physical Capacity
```

Example:

Node:

```text
8Gi RAM
```

Applications consume:

```text
4Gi

3Gi

2Gi
```

Total:

```text
9Gi
```

Available:

```text
8Gi
```

Problem:

```text
System Cannot Allocate Memory
```

Something must be terminated.

---

# What Is OOM?

OOM means:

```text
Out Of Memory
```

The system attempted:

```text
Allocate Memory
```

but:

```text
No Memory Available
```

---

# What Is OOMKilled?

OOMKilled means:

```text
Linux Kernel
Killed A Process
```

because:

```text
Memory Limit Exceeded
```

or

```text
System Memory Exhausted
```

---

# CPU vs Memory

| Resource | Exceed Limit |
| -------- | ------------ |
| CPU      | Throttled    |
| Memory   | OOMKilled    |

---

CPU:

```text
Slow Down
```

Memory:

```text
Kill Process
```

---

# Why Not Throttle Memory?

Imagine:

Application currently uses:

```text
500Mi
```

Node only has:

```text
256Mi available
```

Linux cannot simply:

```text
Take Memory Away
```

because:

```text
Application Is Using It
```

Therefore:

```text
Kill Process
```

---

# Current Project Configuration

Open:

```text
k8s/deployment.yaml
```

Memory resources:

```yaml
resources:
  requests:
    memory: "128Mi"

  limits:
    memory: "256Mi"
```

Meaning:

```text
Guaranteed

128Mi
```

Maximum:

```text
256Mi
```

---

# Deploy Application

```bash
kubectl apply -f k8s/namespace.yaml

kubectl apply \
-f k8s/deployment.yaml \
-n resource-demo

kubectl apply \
-f k8s/service.yaml \
-n resource-demo
```

Verify:

```bash
kubectl get pods -n resource-demo
```

Expected:

```text
Running
```

---

# Port Forward

Terminal 1:

```bash
kubectl port-forward \
svc/loadtest-service \
8080:80 \
-n resource-demo
```

---

# Observe Memory Usage

Terminal 2:

```bash
kubectl top pod \
-n resource-demo
```

Expected:

```text
Memory

20Mi
30Mi
40Mi
```

Application idle.

---

# Trigger Memory Allocation

Application provides:

```text
/eat-memory
```

Endpoint.

Allocate memory:

```bash
curl \
"http://localhost:8080/eat-memory?mb=200"
```

Memory usage increases.

---

Check:

```bash
kubectl top pod \
-n resource-demo
```

Expected:

```text
Memory

220Mi
```

Still below limit.

---

# Trigger OOMKill

Allocate more:

```bash
curl \
"http://localhost:8080/eat-memory?mb=200"
```

Total:

```text
400Mi
```

Limit:

```text
256Mi
```

Result:

```text
OOMKilled
```

---

# Observe Pod Restart

Watch:

```bash
kubectl get pods \
-w \
-n resource-demo
```

Expected:

```text
Running

Restarting

Running
```

Restart count increases.

---

# Verify OOMKill

Find Pod:

```bash
kubectl get pods \
-n resource-demo
```

Describe:

```bash
kubectl describe pod POD_NAME \
-n resource-demo
```

Look for:

```text
Last State:

Terminated

Reason:

OOMKilled
```

This is the most important indicator.

---

# View Restart Count

```bash
kubectl get pod POD_NAME \
-o wide \
-n resource-demo
```

Look for:

```text
RESTARTS

1
2
3
```

Increasing count indicates repeated failures.

---

# Why Container Restarts

Deployment controller ensures:

```text
Desired Replicas = 1
```

Container dies:

```text
OOMKilled
```

Kubernetes:

```text
Starts New Container
```

Automatically.

---

# CrashLoopBackOff

Repeated OOMKills can lead to:

```text
CrashLoopBackOff
```

Meaning:

```text
Container Crashes

Container Restarts

Container Crashes Again

Repeat
```

Kubernetes introduces:

```text
Backoff Delay
```

between restart attempts.

---

# Observe CrashLoopBackOff

Example:

```text
STATUS

CrashLoopBackOff
```

This is not the root cause.

It is a symptom.

Root cause might be:

```text
OOMKilled
```

Always investigate.

---

# Investigation Workflow

Never stop at:

```text
CrashLoopBackOff
```

Check:

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
Reason:

OOMKilled
```

---

# Memory Leak Example

Application:

```text
Allocates Memory

Never Releases Memory
```

Usage:

```text
50Mi

100Mi

200Mi

400Mi

800Mi
```

Eventually:

```text
OOMKilled
```

This is a classic:

```text
Memory Leak
```

---

# Simulate Memory Leak

Run repeatedly:

```bash
curl \
"http://localhost:8080/eat-memory?mb=50"
```

Observe:

```bash
kubectl top pod
```

Memory keeps growing.

---

# Release Memory

Application provides:

```text
/release
```

Execute:

```bash
curl \
"http://localhost:8080/release"
```

Observe:

```bash
kubectl top pod
```

Memory drops.

---

# Production Example

Service average:

```text
150Mi
```

Peak:

```text
350Mi
```

Bad:

```yaml
limits:
  memory: "200Mi"
```

Result:

```text
Random OOMKills
```

Good:

```yaml
limits:
  memory: "512Mi"
```

Provides safety margin.

---

# Requests vs Limits For Memory

Example:

```yaml
requests:
  memory: "128Mi"

limits:
  memory: "512Mi"
```

Meaning:

```text
Reserve

128Mi
```

Allow:

```text
Up To 512Mi
```

---

# Monitoring Memory

Pod usage:

```bash
kubectl top pod
```

Node usage:

```bash
kubectl top node
```

All namespaces:

```bash
kubectl top pod -A
```

---

# Troubleshooting Guide

---

## Problem

Application Keeps Restarting

Check:

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
OOMKilled
```

---

## Problem

CrashLoopBackOff

Check:

```bash
kubectl describe pod POD_NAME
```

Check:

```bash
kubectl logs POD_NAME
```

Determine root cause.

---

## Problem

High Memory Usage

Check:

```bash
kubectl top pod
```

Observe trend.

Growing continuously?

Possible:

```text
Memory Leak
```

---

## Problem

Node Running Out Of Memory

Check:

```bash
kubectl top node
```

Identify:

```text
Top Consumers
```

using:

```bash
kubectl top pod -A
```

---

# Common Mistakes

---

## Memory Limit Too Small

```yaml
limits:
  memory: "64Mi"
```

Result:

```text
Frequent OOMKills
```

---

## No Memory Limit

```yaml
resources:
  requests:
    memory: "128Mi"
```

Problem:

```text
Container May Consume Entire Node Memory
```

---

## Request Equals Peak Usage

```yaml
requests:
  memory: "4Gi"
```

Problem:

```text
Difficult Scheduling
```

Pods remain pending.

---

## Ignoring Restarts

Engineers often monitor:

```text
STATUS = Running
```

and miss:

```text
RESTARTS = 100
```

Always check restart count.

---

# Production Investigation Checklist

Step 1

```bash
kubectl get pod
```

---

Step 2

```bash
kubectl describe pod POD_NAME
```

---

Step 3

```bash
kubectl logs POD_NAME
```

---

Step 4

```bash
kubectl top pod
```

---

Step 5

Verify:

```text
Request

Limit

Actual Usage
```

---

# Interview Questions

---

## What Does OOM Mean?

Answer:

```text
Out Of Memory
```

---

## What Does OOMKilled Mean?

Answer:

```text
Linux Kernel Terminated Process

Due To Memory Exhaustion
```

---

## What Happens When Memory Limit Is Exceeded?

Answer:

```text
Container Is Killed
```

---

## What Happens When CPU Limit Is Exceeded?

Answer:

```text
Container Is Throttled
```

---

## Why Is Memory Not Throttled?

Answer:

```text
Memory Is Not Compressible
```

---

## What Is CrashLoopBackOff?

Answer:

```text
Repeated Container Failures

With Restart Backoff
```

---

## Is CrashLoopBackOff A Root Cause?

Answer:

```text
No

It Is A Symptom
```

---

## How Do You Verify OOMKilled?

Answer:

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
Reason:
OOMKilled
```

---

## Can A Pod Recover After OOMKill?

Answer:

```text
Yes

Kubernetes Restarts It
```

---

# Cleanup

Delete deployment:

```bash
kubectl delete \
-f k8s/deployment.yaml \
-n resource-demo
```

Delete service:

```bash
kubectl delete \
-f k8s/service.yaml \
-n resource-demo
```

Delete namespace:

```bash
kubectl delete namespace resource-demo
```

---

# Key Takeaways

```text
CPU Exceeds Limit
=
Throttled

Memory Exceeds Limit
=
OOMKilled

OOM
=
Out Of Memory

OOMKilled
=
Kernel Terminated Process

CrashLoopBackOff
=
Repeated Failure Symptom

Investigate Using

kubectl describe pod

kubectl logs

kubectl top pod
```

Understanding OOMKills is one of the most important Kubernetes troubleshooting skills because memory-related incidents are among the most common causes of production outages.
