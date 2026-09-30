# 01 - Requests vs Limits

---

# Learning Objectives

By the end of this lab you will understand:

* What CPU requests are
* What memory requests are
* What CPU limits are
* What memory limits are
* How Kubernetes schedules Pods
* Why requests and limits exist
* The difference between scheduling and runtime enforcement
* How requests affect cluster capacity planning
* Common production mistakes
* Interview questions related to requests and limits

---

# Why Resource Management Exists

Imagine a Kubernetes node:

```text
Node-1

CPU:    4 cores
Memory: 8Gi
```

Now deploy three applications:

```text
Frontend
Backend
Database
```

If none of them have resource limits:

```text
Frontend consumes 6Gi RAM
Backend consumes 1Gi RAM
Database consumes 4Gi RAM
```

Total:

```text
11Gi RAM
```

Node only has:

```text
8Gi RAM
```

Result:

```text
Node becomes unstable
Pods crash
Applications become unavailable
```

Kubernetes needs a way to control resource usage.

This is where:

```text
Requests
Limits
```

come in.

---

# Requests vs Limits

Think of a hotel.

```text
Request
=
Room Reservation

Limit
=
Maximum Number Of Guests Allowed
```

A request tells Kubernetes:

```text
Reserve this much for me.
```

A limit tells Kubernetes:

```text
Never let me exceed this amount.
```

---

# Requests

Example:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
```

Meaning:

```text
Reserve:

0.1 CPU
128Mi Memory
```

for this Pod.

---

# Limits

Example:

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Meaning:

```text
Allow:

0.5 CPU
512Mi Memory

Maximum
```

---

# Visual Example

Node:

```text
CPU = 4
RAM = 8Gi
```

Pod:

```yaml
requests:
  cpu: 1
  memory: 1Gi

limits:
  cpu: 2
  memory: 2Gi
```

Scheduler sees:

```text
Needs:
1 CPU
1Gi Memory
```

Scheduler ignores:

```text
Limit CPU = 2
Limit Memory = 2Gi
```

Only requests matter during scheduling.

---

# Most Important Rule

The Kubernetes Scheduler Uses:

```text
Requests
```

NOT:

```text
Limits
```

Many engineers get this wrong.

---

# Resource Units

---

## CPU

CPU is measured in:

```text
Cores
```

Examples:

```text
1     = 1 CPU core

500m  = 0.5 CPU

250m  = 0.25 CPU

100m  = 0.1 CPU
```

---

## Memory

Memory is measured in:

```text
Mi
Gi
```

Examples:

```text
128Mi

256Mi

512Mi

1Gi
```

---

# Demo Application

Use the deployment already provided in this project.

File:

```text
k8s/deployment.yaml
```

Resources:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"

  limits:
    cpu: "250m"
    memory: "256Mi"
```

---

# Deploy The Application

```bash
kubectl apply -f k8s/namespace.yaml

kubectl apply -n resource-demo \
  -f k8s/deployment.yaml

kubectl apply -n resource-demo \
  -f k8s/service.yaml
```

Verify:

```bash
kubectl get pods -n resource-demo
```

Expected:

```text
NAME                        READY
loadtest-xxxxxxxxxx         1/1
```

---

# Inspect Pod Resources

Find Pod:

```bash
kubectl get pods -n resource-demo
```

Describe Pod:

```bash
kubectl describe pod POD_NAME \
  -n resource-demo
```

Look for:

```text
Requests:
  cpu:      100m
  memory:   128Mi

Limits:
  cpu:      250m
  memory:   256Mi
```

---

# Understanding Scheduling

Imagine:

```text
Node Capacity

CPU: 2
Memory: 4Gi
```

Current usage:

```text
CPU: 1.9
Memory: 3Gi
```

New Pod:

```yaml
requests:
  cpu: 500m
```

Scheduler calculates:

```text
Available CPU

2 - 1.9

0.1 CPU
```

Needed:

```text
0.5 CPU
```

Result:

```text
Cannot schedule
```

Pod remains:

```text
Pending
```

---

# Scheduling Failure Demo

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

Apply:

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

# Investigating Pending Pods

```bash
kubectl describe pod huge-request
```

Look for:

```text
Events:

0/1 nodes are available

Insufficient cpu

Insufficient memory
```

---

# CPU Behavior

CPU is compressible.

When a Pod exceeds:

```text
CPU Limit
```

Kubernetes throttles it.

Result:

```text
Application slows down
```

But:

```text
Pod remains running
```

---

# Memory Behavior

Memory is not compressible.

When a Pod exceeds:

```text
Memory Limit
```

Linux kills the process.

Result:

```text
OOMKilled
```

---

# Common Production Pattern

Most teams use:

```yaml
requests:
  cpu: 100m
  memory: 128Mi

limits:
  cpu: 500m
  memory: 512Mi
```

Why?

Because applications usually need:

```text
100m CPU normally
```

but occasionally burst to:

```text
500m CPU
```

---

# Overcommitment

Node:

```text
4 CPU
```

Pod:

```yaml
request:
  cpu: 100m

limit:
  cpu: 2
```

Deploy:

```text
20 Pods
```

Requests:

```text
2 CPU total
```

Limits:

```text
40 CPU total
```

Scheduler:

```text
Accepts deployment
```

because:

```text
Requests fit
```

This is called:

```text
Overcommitment
```

---

# Common Mistakes

---

## Mistake 1

No requests

```yaml
resources:
  limits:
    cpu: "1"
```

Problem:

```text
Scheduler cannot reserve capacity correctly.
```

---

## Mistake 2

No limits

```yaml
resources:
  requests:
    cpu: "100m"
```

Problem:

```text
Pod can consume entire node.
```

---

## Mistake 3

Requests Too High

```yaml
requests:
  cpu: "8"
```

Problem:

```text
Pods never schedule.
```

---

## Mistake 4

Limits Too Low

```yaml
limits:
  memory: "64Mi"
```

Problem:

```text
Frequent OOMKills.
```

---

# Useful Commands

View requests:

```bash
kubectl describe pod POD_NAME
```

View node capacity:

```bash
kubectl describe node NODE_NAME
```

View resource usage:

```bash
kubectl top pod
```

View node usage:

```bash
kubectl top node
```

---

# Interview Questions

---

## What is a request?

Answer:

```text
Amount reserved for a container.
Used by the scheduler.
```

---

## What is a limit?

Answer:

```text
Maximum amount a container may consume.
```

---

## Does Scheduler Use Requests Or Limits?

Answer:

```text
Requests only.
```

---

## What Happens When CPU Limit Is Exceeded?

Answer:

```text
CPU throttling.
```

---

## What Happens When Memory Limit Is Exceeded?

Answer:

```text
OOMKilled.
```

---

## Can Requests Be Greater Than Limits?

Answer:

```text
No.

API validation rejects it.
```

---

# Cleanup

Delete demo pod:

```bash
kubectl delete pod huge-request
```

Delete deployment:

```bash
kubectl delete -f k8s/deployment.yaml \
  -n resource-demo
```

Delete namespace:

```bash
kubectl delete namespace resource-demo
```

---

# Key Takeaways

```text
Request
=
Scheduling

Limit
=
Runtime Enforcement

CPU Exceed Limit
=
Throttle

Memory Exceed Limit
=
OOMKill

Scheduler Uses
=
Requests Only

Requests Fit
=
Pod Scheduled

Requests Do Not Fit
=
Pod Pending
```

This mental model will be used throughout every remaining resource-management lab.
