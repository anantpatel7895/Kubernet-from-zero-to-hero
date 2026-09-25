# 04 - Scheduler and Requests

---

# Learning Objectives

By the end of this lab you will understand:

* What the Kubernetes Scheduler does
* How scheduling decisions are made
* Why requests are critical
* Why limits are ignored during scheduling
* Why Pods become Pending
* What resource fragmentation is
* What bin packing means
* How overcommitment works
* How to troubleshoot scheduling failures
* How production clusters schedule workloads

---

# What Is The Scheduler?

The Kubernetes Scheduler is responsible for:

```text
Finding A Node

For Every New Pod
```

When you create:

```bash
kubectl apply -f deployment.yaml
```

The scheduler decides:

```text
Which Node
Will Run The Pod
```

---

# Life Of A Pod

Step 1

You create a Pod:

```yaml
apiVersion: v1
kind: Pod
```

---

Step 2

Pod enters:

```text
Pending
```

---

Step 3

Scheduler evaluates:

```text
Node 1
Node 2
Node 3
```

---

Step 4

Scheduler selects:

```text
Best Node
```

---

Step 5

Pod becomes:

```text
Running
```

---

# Important Rule

The Scheduler Uses:

```text
Requests
```

The Scheduler Does NOT Use:

```text
Limits
```

This is one of the most important Kubernetes concepts.

---

# Example

Node:

```text
CPU = 4

Memory = 8Gi
```

Pod:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"

  limits:
    cpu: "4"
    memory: "8Gi"
```

Scheduler checks:

```text
500m CPU

512Mi Memory
```

Scheduler ignores:

```text
Limit CPU

Limit Memory
```

---

# Why?

Because limits are:

```text
Runtime Constraints
```

Requests are:

```text
Scheduling Requirements
```

---

# Visual Example

Node:

```text
CPU Capacity

4 CPU
```

Existing Pods:

```text
Pod A
Request = 1 CPU

Pod B
Request = 1 CPU

Pod C
Request = 1 CPU
```

Reserved:

```text
3 CPU
```

Available:

```text
1 CPU
```

---

New Pod:

```yaml
requests:
  cpu: "500m"
```

Scheduler:

```text
Can Fit
```

Result:

```text
Scheduled
```

---

New Pod:

```yaml
requests:
  cpu: "2"
```

Scheduler:

```text
Cannot Fit
```

Result:

```text
Pending
```

---

# Creating A Scheduling Failure

Create:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: huge-request

spec:
  containers:
  - name: app

    image: busybox

    command:
    - sh
    - -c
    - sleep 3600

    resources:
      requests:
        cpu: "8"
        memory: "16Gi"

      limits:
        cpu: "8"
        memory: "16Gi"
```

Save as:

```text
huge-request.yaml
```

---

# Deploy

```bash
kubectl apply -f huge-request.yaml
```

Check:

```bash
kubectl get pod huge-request
```

Expected:

```text
STATUS

Pending
```

---

# Why Is It Pending?

Describe Pod:

```bash
kubectl describe pod huge-request
```

Look for:

```text
Events:

0/1 nodes available

Insufficient cpu

Insufficient memory
```

This is the most common scheduling failure.

---

# Understanding Pending

Pending means:

```text
Pod Exists

Node Not Assigned
```

It does NOT mean:

```text
Application Failure
```

It does NOT mean:

```text
Container Crash
```

It means:

```text
Scheduler Cannot Find A Suitable Node
```

---

# Scheduler Workflow

Simplified:

```text
Pod Created

↓

Evaluate Nodes

↓

Filter Unsuitable Nodes

↓

Score Remaining Nodes

↓

Select Best Node

↓

Assign Pod
```

---

# Filtering Stage

Scheduler first removes nodes that cannot satisfy:

```text
CPU Request

Memory Request

Node Affinity

Taints

Selectors
```

---

Example:

Node:

```text
2 CPU
```

Pod:

```yaml
requests:
  cpu: "4"
```

Node removed.

---

# Scoring Stage

Multiple nodes fit.

Example:

```text
Node A

2 CPU Free
```

```text
Node B

10 CPU Free
```

Scheduler scores nodes.

Depending on strategy:

```text
Spread Workloads
```

or

```text
Pack Workloads
```

---

# Resource Fragmentation

A very important production concept.

---

Example

Cluster:

```text
Node A

1 CPU Free
```

```text
Node B

1 CPU Free
```

Total:

```text
2 CPU Free
```

---

New Pod:

```yaml
requests:
  cpu: "2"
```

Can it schedule?

Answer:

```text
No
```

---

Why?

Because:

```text
Requests Must Fit

On A Single Node
```

Not across multiple nodes.

---

This is called:

```text
Resource Fragmentation
```

---

# Bin Packing

Scheduler often tries to:

```text
Pack Workloads
```

onto nodes efficiently.

---

Example

Node:

```text
8 CPU
```

Pods:

```text
500m

500m

500m

500m
```

Scheduler may place all on one node.

Result:

```text
Other Nodes Stay Empty
```

Benefits:

```text
Better Utilization
```

---

# Overcommitment

Node:

```text
4 CPU
```

Pod:

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "2"
```

Deploy:

```text
20 Pods
```

Requests:

```text
2 CPU
```

Limits:

```text
40 CPU
```

Scheduler sees:

```text
2 CPU
```

Result:

```text
Scheduling Succeeds
```

---

This is:

```text
Overcommitment
```

Very common in production.

---

# Verify Requests On Running Pods

View:

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
Requests

Limits
```

---

# Check Node Capacity

List nodes:

```bash
kubectl get nodes
```

Describe:

```bash
kubectl describe node NODE_NAME
```

Look for:

```text
Capacity

Allocatable
```

---

Example:

```text
Capacity

CPU: 4
Memory: 8Gi
```

Allocatable:

```text
CPU: 3900m

Memory: 7500Mi
```

Because Kubernetes reserves resources for itself.

---

# View Resource Allocation

Node details:

```bash
kubectl describe node NODE_NAME
```

Look for:

```text
Allocated resources
```

Example:

```text
CPU Requests

1200m
```

```text
Memory Requests

2Gi
```

---

# Real Production Scenario

Developer deploys:

```yaml
requests:
  cpu: "16"
```

Cluster:

```text
8 CPU Nodes
```

Result:

```text
Pod Pending
```

---

Operations team investigates:

```bash
kubectl describe pod
```

Finds:

```text
Insufficient cpu
```

---

Fix:

```yaml
requests:
  cpu: "2"
```

Pod schedules successfully.

---

# Troubleshooting Workflow

Pod Pending?

Step 1:

```bash
kubectl get pod
```

---

Step 2:

```bash
kubectl describe pod POD_NAME
```

---

Step 3:

Look for:

```text
Insufficient cpu

Insufficient memory

Node affinity mismatch

Taint issues
```

---

Step 4:

Check nodes:

```bash
kubectl get nodes
```

---

Step 5:

Inspect node resources:

```bash
kubectl describe node NODE_NAME
```

---

# Common Scheduling Errors

---

## Insufficient CPU

```text
Insufficient cpu
```

Meaning:

```text
Request Too Large
```

---

## Insufficient Memory

```text
Insufficient memory
```

Meaning:

```text
Memory Request Too Large
```

---

## Node Selector Mismatch

```text
No Nodes Match Selector
```

---

## Taints

```text
Untolerated Taint
```

---

# Common Mistakes

---

## Request Too High

```yaml
requests:
  cpu: "32"
```

Result:

```text
Never Schedules
```

---

## Request Equals Peak Usage

```yaml
requests:
  memory: "8Gi"
```

Problem:

```text
Wastes Capacity
```

---

## Ignoring Pending Pods

Engineers see:

```text
Pending
```

and assume:

```text
Cluster Broken
```

Usually:

```text
Scheduling Constraint
```

is the real issue.

---

# Interview Questions

---

## What Does The Scheduler Use?

Answer:

```text
Requests
```

---

## Does Scheduler Use Limits?

Answer:

```text
No
```

---

## Why Does A Pod Remain Pending?

Answer:

```text
No Suitable Node Found
```

---

## What Does Pending Mean?

Answer:

```text
Pod Created

Not Scheduled
```

---

## Can Kubernetes Split A Pod Across Nodes?

Answer:

```text
No
```

A Pod must run on:

```text
One Node
```

---

## What Is Resource Fragmentation?

Answer:

```text
Enough Resources Exist

But Not On One Node
```

---

## What Is Bin Packing?

Answer:

```text
Efficient Workload Placement

To Maximize Utilization
```

---

## Why Are Requests Important?

Answer:

```text
They Drive Scheduling Decisions
```

---

# Cleanup

Delete demo pod:

```bash
kubectl delete pod huge-request
```

---

# Key Takeaways

```text
Scheduler Uses
=
Requests

Scheduler Ignores
=
Limits

Pending
=
No Suitable Node

Requests
=
Scheduling

Limits
=
Runtime Enforcement

Resource Fragmentation
=
Resources Exist
But Not On One Node

Overcommitment
=
Limits > Capacity
Requests Fit
```

Understanding scheduling is critical because almost every advanced Kubernetes feature—autoscaling, quotas, priorities, affinity, and cluster autoscaler—depends on how requests influence scheduler decisions.
