# 07 - Node Pressure and Evictions

---

# Learning Objectives

By the end of this lab you will understand:

* What node pressure is
* What evictions are
* Difference between OOMKilled and Evicted
* MemoryPressure
* DiskPressure
* PIDPressure
* Kubelet eviction manager
* Node conditions
* Eviction signals
* How Kubernetes protects nodes
* Production troubleshooting workflows
* Real-world outage scenarios

---

# The Most Important Concept In This Module

Many engineers confuse:

```text
OOMKilled
```

with:

```text
Evicted
```

They are completely different.

---

# OOMKilled

Who killed the process?

```text
Linux Kernel
```

Why?

```text
Container Exceeded Memory Limit
```

Effect:

```text
Container Dies

Pod Usually Survives

Container Restarts
```

---

# Evicted

Who evicted the Pod?

```text
Kubelet
```

Why?

```text
Node Under Pressure
```

Effect:

```text
Entire Pod Removed
```

---

# Comparison Table

| Feature       | OOMKilled               | Evicted                       |
| ------------- | ----------------------- | ----------------------------- |
| Trigger       | Container exceeds limit | Node pressure                 |
| Who acts      | Linux Kernel            | Kubelet                       |
| Scope         | Container               | Entire Pod                    |
| Restart       | Usually                 | No                            |
| Pod deleted   | No                      | Yes                           |
| Common reason | Memory limit exceeded   | Node running out of resources |

---

# What Is Node Pressure?

Node pressure means:

```text
Node Resources

Running Low
```

Examples:

```text
Low Memory

Low Disk

Too Many Processes
```

---

Node:

```text
CPU: 4

Memory: 8Gi

Disk: 100Gi
```

Current usage:

```text
Memory: 7.9Gi

Disk: 95Gi
```

Node enters:

```text
Pressure State
```

---

# Why Kubernetes Evicts Pods

Without evictions:

```text
Node Runs Out Of Resources

Node Becomes Unstable

Node Crashes
```

This would affect:

```text
ALL Pods
```

on the node.

---

Instead Kubernetes sacrifices:

```text
Some Pods
```

to save:

```text
The Node
```

---

# Kubelet Eviction Manager

Each node runs:

```text
kubelet
```

Kubelet continuously monitors:

```text
Memory

Disk

Processes
```

---

When thresholds are crossed:

```text
Eviction Manager
```

activates.

---

Workflow:

```text
Pressure Detected

↓

Choose Victims

↓

Evict Pods

↓

Recover Node
```

---

# MemoryPressure

Most common pressure type.

Node:

```text
Memory = 8Gi
```

Usage:

```text
7.8Gi

7.9Gi

7.95Gi

7.99Gi
```

Available:

```text
Very Low
```

---

Node Condition:

```text
MemoryPressure=True
```

---

Check:

```bash
kubectl describe node NODE_NAME
```

Look for:

```text
Conditions

MemoryPressure
```

Example:

```text
MemoryPressure

True
```

---

# DiskPressure

Node storage becomes full.

Example:

```text
Disk Size

100Gi
```

Usage:

```text
98Gi
```

Available:

```text
2Gi
```

---

Node Condition:

```text
DiskPressure=True
```

---

Check:

```bash
kubectl describe node NODE_NAME
```

---

Example:

```text
DiskPressure

True
```

---

# PIDPressure

Less common.

PID:

```text
Process ID
```

Every process requires:

```text
PID
```

---

Node limit:

```text
32768 Processes
```

Current:

```text
32500 Processes
```

---

Node Condition:

```text
PIDPressure=True
```

---

Often caused by:

```text
Fork Bomb

Thread Explosion

Runaway Processes
```

---

# Viewing Node Conditions

```bash
kubectl describe node NODE_NAME
```

Look for:

```text
Conditions
```

Example:

```text
MemoryPressure    False

DiskPressure      False

PIDPressure       False

Ready             True
```

Healthy node.

---

# Creating Memory Pressure

Imagine:

```text
Node

8Gi RAM
```

Deploy:

```text
Many Memory Hungry Pods
```

Usage reaches:

```text
95%
```

Then:

```text
98%
```

Then:

```text
99%
```

Kubelet begins evictions.

---

# Eviction Order

QoS matters.

Eviction preference:

```text
BestEffort

↓

Burstable

↓

Guaranteed
```

---

Example

Pods:

```text
Pod A

BestEffort
```

```text
Pod B

Burstable
```

```text
Pod C

Guaranteed
```

Pressure occurs.

Result:

```text
Pod A Evicted First
```

---

# Verify QoS

```bash
kubectl get pod POD_NAME \
-o jsonpath='{.status.qosClass}'
```

---

# Eviction Messages

Describe Pod:

```bash
kubectl describe pod POD_NAME
```

---

Look for:

```text
Status:

Failed
```

---

Events:

```text
Evicted
```

---

Example:

```text
The node was low on resource:

memory
```

---

# OOMKilled Example

Container:

```yaml
limits:
  memory: "256Mi"
```

Application consumes:

```text
400Mi
```

Result:

```text
OOMKilled
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

# Eviction Example

Container limit:

```text
Within Limits
```

Node:

```text
Out Of Memory
```

Result:

```text
Evicted
```

Even though container respected its limits.

This surprises many engineers.

---

# Important Production Lesson

A Pod can be:

```text
Well Behaved
```

and still be:

```text
Evicted
```

because:

```text
Node Problems
```

exist.

---

# Ephemeral Storage Pressure

Node:

```text
100Gi Disk
```

Logs:

```text
90Gi
```

Images:

```text
8Gi
```

Available:

```text
2Gi
```

---

Result:

```text
DiskPressure
```

---

Possible Eviction:

```text
Evicted
Reason:

DiskPressure
```

---

# Checking Events

Recent events:

```bash
kubectl get events \
--sort-by=.metadata.creationTimestamp
```

---

Useful for:

```text
Evictions

Scheduling Issues

Node Problems
```

---

# Production Scenario

Cluster:

```text
20 Nodes
```

Application deployment:

```text
100 Pods
```

Memory leak appears.

Pods consume:

```text
More Memory

Every Hour
```

---

Eventually:

```text
MemoryPressure=True
```

on multiple nodes.

---

Kubelet begins:

```text
Evictions
```

---

Symptoms:

```text
Random Pods Missing

Reduced Capacity

Service Degradation
```

---

Root Cause:

```text
Memory Leak
```

not Kubernetes.

---

# Troubleshooting Workflow

Pod disappeared?

Step 1

```bash
kubectl get events \
--sort-by=.metadata.creationTimestamp
```

Look for:

```text
Evicted
```

---

Step 2

```bash
kubectl describe pod POD_NAME
```

---

Step 3

Check node:

```bash
kubectl describe node NODE_NAME
```

---

Step 4

Look for:

```text
MemoryPressure

DiskPressure

PIDPressure
```

---

Step 5

Check resource usage:

```bash
kubectl top node
```

---

Step 6

Check top consumers:

```bash
kubectl top pod -A
```

---

# Common Mistakes

---

## Mistake 1

Assuming:

```text
OOMKilled

=

Evicted
```

Wrong.

---

## Mistake 2

Ignoring Node Conditions

Always check:

```bash
kubectl describe node
```

---

## Mistake 3

Looking Only At Pod

Sometimes:

```text
Pod Healthy

Node Unhealthy
```

---

## Mistake 4

BestEffort In Production

BestEffort Pods are:

```text
First Eviction Candidates
```

---

# Commands Cheat Sheet

Node status:

```bash
kubectl get nodes
```

---

Node details:

```bash
kubectl describe node NODE_NAME
```

---

Pod details:

```bash
kubectl describe pod POD_NAME
```

---

Resource usage:

```bash
kubectl top node
```

---

Pod usage:

```bash
kubectl top pod -A
```

---

Events:

```bash
kubectl get events \
--sort-by=.metadata.creationTimestamp
```

---

# Interview Questions

---

## What Is MemoryPressure?

Answer:

```text
Node Running Low On Memory
```

---

## What Is DiskPressure?

Answer:

```text
Node Running Low On Disk
```

---

## What Is PIDPressure?

Answer:

```text
Node Running Out Of Process IDs
```

---

## Who Performs Evictions?

Answer:

```text
Kubelet
```

---

## Who Performs OOMKills?

Answer:

```text
Linux Kernel
```

---

## Difference Between OOMKilled And Evicted?

Answer:

```text
OOMKilled

Container Limit Problem

Evicted

Node Resource Problem
```

---

## Can Guaranteed Pods Be Evicted?

Answer:

```text
Yes

Last To Be Evicted
```

---

## What Node Conditions Exist?

Answer:

```text
MemoryPressure

DiskPressure

PIDPressure

Ready
```

---

## How Do You Check Node Conditions?

Answer:

```bash
kubectl describe node NODE_NAME
```

---

# Cleanup

No cleanup required for theory labs.

If test Pods were created:

```bash
kubectl delete pod POD_NAME
```

---

# Key Takeaways

```text
OOMKilled
=
Container Problem

Evicted
=
Node Problem

OOMKilled
=
Linux Kernel

Evicted
=
Kubelet

MemoryPressure
=
Low Memory

DiskPressure
=
Low Disk

PIDPressure
=
Too Many Processes

Eviction Order

BestEffort
↓

Burstable
↓

Guaranteed
```

Understanding evictions is one of the most important Kubernetes troubleshooting skills because many production incidents are caused not by application bugs, but by node resource exhaustion and eviction behavior.
