# 05 - Overcommitment

---

# Learning Objectives

By the end of this lab you will understand:

* What overcommitment is
* Why Kubernetes allows overcommitment
* Why overcommitment is necessary in production
* CPU overcommitment
* Memory overcommitment
* Risks of excessive overcommitment
* How cloud providers use overcommitment
* Capacity planning fundamentals
* Production sizing strategies
* Interview questions related to overcommitment

---

# What Is Overcommitment?

Overcommitment means:

```text
Promising More Resources

Than Physically Exist
```

This sounds dangerous.

But Kubernetes intentionally allows it.

---

# Why?

Because applications rarely use:

```text
Maximum Resources

All The Time
```

Example:

Microservice:

```text
Request = 100m CPU

Limit = 1000m CPU
```

Normal usage:

```text
20m CPU
```

Peak usage:

```text
700m CPU
```

Actual average:

```text
50m CPU
```

Without overcommitment:

```text
950m CPU

Wasted
```

---

# Example Cluster

Node:

```text
4 CPU
8Gi RAM
```

---

Pod A

```yaml
requests:
  cpu: 100m

limits:
  cpu: 1
```

---

Pod B

```yaml
requests:
  cpu: 100m

limits:
  cpu: 1
```

---

Pod C

```yaml
requests:
  cpu: 100m

limits:
  cpu: 1
```

---

Total Requests

```text
300m CPU
```

Total Limits

```text
3 CPU
```

Scheduler sees:

```text
300m
```

Result:

```text
Schedule
```

---

# Larger Example

Node:

```text
4 CPU
```

Deploy:

```text
20 Pods
```

Each:

```yaml
requests:
  cpu: 100m

limits:
  cpu: 2
```

---

Requests:

```text
20 × 100m

2 CPU
```

---

Limits:

```text
20 × 2

40 CPU
```

---

Node Capacity:

```text
4 CPU
```

---

Question:

Can Scheduler Place Them?

Answer:

```text
Yes
```

Because Scheduler Uses:

```text
Requests
```

Not:

```text
Limits
```

---

# Why This Works

Reality:

```text
Pod 1 Uses 20m

Pod 2 Uses 15m

Pod 3 Uses 50m

Pod 4 Uses 30m
```

Most Pods are idle.

---

Actual usage:

```text
500m CPU
```

Reserved:

```text
2 CPU
```

Node Capacity:

```text
4 CPU
```

Everything works.

---

# Visualizing Overcommitment

Node:

```text
CPU Capacity

4 CPU
```

Requests:

```text
2 CPU
```

Actual Usage:

```text
800m
```

Limits:

```text
40 CPU
```

---

Observation:

```text
Limits Can Exceed Capacity

Massively
```

and Kubernetes is okay with it.

---

# Why Requests Matter

Requests represent:

```text
Guaranteed Capacity
```

Scheduler assumes:

```text
Every Pod

May Need Its Request
```

at any moment.

---

Limits represent:

```text
Maximum Allowed
```

but:

```text
Not Guaranteed
```

---

# CPU Overcommitment

CPU is:

```text
Compressible
```

When demand exceeds capacity:

```text
Containers Throttle
```

Example:

Node:

```text
4 CPU
```

Pods collectively want:

```text
10 CPU
```

Node only has:

```text
4 CPU
```

Result:

```text
CPU Throttling
```

Applications slow down.

---

# Memory Overcommitment

Memory is:

```text
Not Compressible
```

When demand exceeds capacity:

```text
OOMKill

Evictions
```

occur.

---

This makes memory overcommitment:

```text
Much Riskier
```

than CPU overcommitment.

---

# Production Rule

CPU:

```text
Aggressive Overcommitment

Usually Safe
```

Memory:

```text
Conservative Overcommitment

Recommended
```

---

# Why Cloud Providers Love Overcommitment

Without overcommitment:

```text
Every Node

Mostly Idle
```

Example:

Node:

```text
4 CPU
```

Applications use:

```text
400m
```

Average.

Utilization:

```text
10%
```

Very expensive.

---

With overcommitment:

```text
70%
80%
90%
```

utilization becomes possible.

---

Result:

```text
Lower Costs

Higher Efficiency
```

---

# Demonstration

Create:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: overcommit-demo

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
        cpu: "100m"
        memory: "128Mi"

      limits:
        cpu: "2"
        memory: "1Gi"
```

---

Deploy:

```bash
kubectl apply -f overcommit-demo.yaml
```

---

Inspect:

```bash
kubectl describe pod overcommit-demo
```

Observe:

```text
Request

100m
```

Limit:

```text
2 CPU
```

---

# Verify Scheduler Behavior

Describe node:

```bash
kubectl describe node NODE_NAME
```

Look for:

```text
Allocated Resources
```

Example:

```text
CPU Requests

500m
```

Even though limits may total:

```text
10 CPU
```

---

# Node Utilization

Check:

```bash
kubectl top node
```

Example:

```text
CPU

350m
```

while limits total:

```text
20 CPU
```

This is normal.

---

# The Danger Of Overcommitment

Imagine:

Node:

```text
4 CPU
```

Twenty Pods:

```text
Request

100m
```

Limit:

```text
2 CPU
```

---

Suddenly:

```text
All Pods Need 2 CPU
```

Total Demand:

```text
40 CPU
```

Capacity:

```text
4 CPU
```

Result:

```text
Severe CPU Throttling
```

Applications become slow.

---

# Memory Disaster Scenario

Node:

```text
8Gi
```

Pods:

```text
Request

256Mi
```

Limit:

```text
2Gi
```

Ten Pods deployed.

---

If every Pod consumes:

```text
2Gi
```

Total:

```text
20Gi
```

Node:

```text
8Gi
```

Result:

```text
OOMKills

Evictions

Node Pressure
```

---

# Production Sizing Strategy

Bad:

```yaml
requests:
  cpu: "4"

limits:
  cpu: "4"
```

for application using:

```text
50m CPU
```

---

Good:

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "500m"
```

---

Reason:

```text
Better Utilization

Better Scheduling

Lower Cost
```

---

# How Teams Determine Requests

Monitor:

```bash
kubectl top pod
```

or:

```text
Prometheus

Grafana
```

Collect:

```text
Average Usage

Peak Usage

95th Percentile
```

---

Set:

```text
Request

Near Average
```

---

Set:

```text
Limit

Near Peak
```

---

Example

Average:

```text
80m CPU
```

Peak:

```text
350m CPU
```

Configuration:

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "500m"
```

---

# Capacity Planning

Node:

```text
8 CPU
```

Applications:

```text
Average

2 CPU
```

Peak:

```text
6 CPU
```

Safe.

---

Applications:

```text
Average

7 CPU
```

Peak:

```text
12 CPU
```

Danger.

---

Need:

```text
More Nodes

Autoscaling
```

---

# Troubleshooting

---

## High Latency

Check:

```bash
kubectl top pod
```

Question:

```text
Near CPU Limit?
```

Possible:

```text
Overcommitment Pressure
```

---

## Frequent OOMKills

Check:

```bash
kubectl describe pod
```

Question:

```text
Memory Overcommitment?
```

---

## Pending Pods

Check:

```bash
kubectl describe pod
```

Look for:

```text
Insufficient CPU

Insufficient Memory
```

Requests may be too high.

---

# Common Mistakes

---

## No Limits

```yaml
requests:
  cpu: "100m"
```

Problem:

```text
Runaway Containers
```

---

## Requests Too High

```yaml
requests:
  cpu: "8"
```

Problem:

```text
Scheduling Failures
```

---

## Aggressive Memory Overcommitment

Problem:

```text
OOMKills

Evictions
```

---

## Using Limits As Requests

Example:

```yaml
requests:
  cpu: "2"

limits:
  cpu: "2"
```

for tiny workload.

Result:

```text
Cluster Waste
```

---

# Interview Questions

---

## What Is Overcommitment?

Answer:

```text
Allocating More Total Limits

Than Physical Capacity
```

---

## Why Does Kubernetes Allow Overcommitment?

Answer:

```text
Applications Rarely Use Peak Resources Continuously
```

---

## Does Scheduler Consider Limits?

Answer:

```text
No

Requests Only
```

---

## Which Is Safer To Overcommit?

Answer:

```text
CPU
```

---

## Why Is Memory Overcommitment Risky?

Answer:

```text
Memory Is Not Compressible
```

---

## What Happens During CPU Overcommitment?

Answer:

```text
CPU Throttling
```

---

## What Happens During Memory Overcommitment?

Answer:

```text
OOMKills

Evictions
```

---

# Cleanup

Delete demo:

```bash
kubectl delete pod overcommit-demo
```

---

# Key Takeaways

```text
Requests
=
Guaranteed

Limits
=
Maximum

Scheduler
=
Requests Only

CPU
=
Safe To Overcommit

Memory
=
Risky To Overcommit

Overcommitment
=
Better Utilization

Bad Overcommitment
=
Throttling
OOMKills
Evictions
```

Understanding overcommitment is critical because it explains why Kubernetes clusters can run hundreds of workloads efficiently while using only a fraction of their theoretical maximum resources.
