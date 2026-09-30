# 17 - Resource Management Production Patterns

---

# Learning Objectives

By the end of this module you will understand:

* How all resource-management concepts fit together
* Production resource sizing methodology
* Capacity planning
* Cost optimization
* Multi-team governance
* Requests and limits best practices
* Overcommitment strategies
* HPA + VPA + Cluster Autoscaler architecture
* Service mesh overhead planning
* Namespace governance
* Production troubleshooting workflows
* Real-world architecture patterns
* Senior-level interview questions

---

# The Big Picture

Most engineers learn:

```text id="pp1"
Requests

Limits

QoS

HPA

VPA
```

individually.

---

Production engineers understand:

```text id="pp2"
How Everything Works Together
```

---

Real resource management:

```text id="pp3"
Application

↓

Container

↓

Pod

↓

Node

↓

Cluster

↓

Cloud Cost
```

---

# The Resource Stack

Layer 1:

```text id="pp4"
Application Usage
```

---

Layer 2:

```text id="pp5"
Requests

Limits
```

---

Layer 3:

```text id="pp6"
QoS Classes
```

---

Layer 4:

```text id="pp7"
Scheduler Decisions
```

---

Layer 5:

```text id="pp8"
Autoscaling
```

---

Layer 6:

```text id="pp9"
Cluster Capacity
```

---

Layer 7:

```text id="pp10"
Cloud Spend
```

---

Every layer affects the next.

---

# Production Sizing Process

Most common beginner mistake:

```yaml id="pp11"
requests:
  cpu: "4"

limits:
  cpu: "4"
```

for every workload.

---

Result:

```text id="pp12"
Massive Waste
```

---

Professional approach:

```text id="pp13"
Measure

↓

Observe

↓

Size

↓

Monitor

↓

Adjust
```

---

# Step 1: Collect Metrics

Observe:

```bash id="pp14"
kubectl top pod
```

---

Prefer:

```text id="pp15"
Prometheus

Grafana
```

---

Collect:

```text id="pp16"
Average

Peak

95th Percentile

99th Percentile
```

---

for:

```text id="pp17"
CPU

Memory

Storage
```

---

# Example Data

CPU:

```text id="pp18"
Average

80m
```

---

Peak:

```text id="pp19"
300m
```

---

95th:

```text id="pp20"
220m
```

---

Memory:

```text id="pp21"
Average

200Mi
```

---

Peak:

```text id="pp22"
350Mi
```

---

# Production Sizing Formula

CPU Request:

```text id="pp23"
Near Average
```

---

CPU Limit:

```text id="pp24"
Near Peak
```

---

Example:

```yaml id="pp25"
requests:
  cpu: "100m"

limits:
  cpu: "500m"
```

---

Memory Request:

```text id="pp26"
Near Normal Usage
```

---

Memory Limit:

```text id="pp27"
Near Safe Maximum
```

---

Example:

```yaml id="pp28"
requests:
  memory: "256Mi"

limits:
  memory: "512Mi"
```

---

# Why This Works

Scheduler reserves:

```text id="pp29"
Requests
```

---

Application may use:

```text id="pp30"
Limits
```

temporarily.

---

Result:

```text id="pp31"
Efficient Utilization
```

---

# Resource Management Layers

Every workload should define:

```yaml id="pp32"
resources:
```

---

Every namespace should have:

```yaml id="pp33"
LimitRange
```

---

Every team namespace should have:

```yaml id="pp34"
ResourceQuota
```

---

Every cluster should have:

```text id="pp35"
Monitoring
```

---

Most production clusters also have:

```text id="pp36"
HPA

Cluster Autoscaler
```

---

# Golden Production Pattern

```text id="pp37"
Application

↓

Requests/Limits

↓

HPA

↓

Cluster Autoscaler

↓

Cloud Provider
```

---

This pattern scales:

```text id="pp38"
Pods

AND

Nodes
```

automatically.

---

# Example Architecture

Traffic:

```text id="pp39"
100 RPS
```

---

Deployment:

```text id="pp40"
2 Pods
```

---

Traffic spike:

```text id="pp41"
10,000 RPS
```

---

HPA:

```text id="pp42"
2

↓

20 Pods
```

---

Cluster full.

---

Cluster Autoscaler:

```text id="pp43"
3 Nodes

↓

10 Nodes
```

---

Traffic served successfully.

---

# Overcommitment Strategy

One of the most important production topics.

---

CPU:

```text id="pp44"
Aggressive Overcommitment

Usually Safe
```

---

Memory:

```text id="pp45"
Conservative Overcommitment
```

---

Reason:

```text id="pp46"
CPU

Can Throttle
```

---

Memory:

```text id="pp47"
Causes OOMKills
```

---

# Typical Production Ratios

CPU:

```text id="pp48"
2x

3x

5x
```

overcommitment common.

---

Memory:

```text id="pp49"
1.1x

1.2x

1.5x
```

more typical.

---

Depends on workload behavior.

---

# Service Mesh Reality

Application:

```text id="pp50"
100m CPU
```

---

Engineers report:

```text id="pp51"
100m CPU
```

---

Reality:

```text id="pp52"
Envoy

200m CPU
```

---

Logging:

```text id="pp53"
50m CPU
```

---

Monitoring:

```text id="pp54"
50m CPU
```

---

Actual Pod:

```text id="pp55"
400m CPU
```

---

Always include:

```text id="pp56"
Sidecar Costs
```

---

# Capacity Planning Formula

Cluster Capacity:

```text id="pp57"
Nodes × CPU Per Node
```

---

Example:

```text id="pp58"
10 Nodes

×

8 CPU
```

---

Capacity:

```text id="pp59"
80 CPU
```

---

Planned Allocation:

```text id="pp60"
70 CPU
```

---

Reserved:

```text id="pp61"
10 CPU
```

for:

```text id="pp62"
Spikes

Failures

Maintenance
```

---

# N+1 Planning

Professional clusters plan for:

```text id="pp63"
Node Failure
```

---

Example:

```text id="pp64"
5 Nodes
```

---

If one fails:

```text id="pp65"
4 Nodes
```

must still support workloads.

---

Called:

```text id="pp66"
N+1 Capacity
```

---

# Namespace Governance Pattern

Development:

```yaml id="pp67"
ResourceQuota

Small
```

---

Staging:

```yaml id="pp68"
ResourceQuota

Medium
```

---

Production:

```yaml id="pp69"
ResourceQuota

Large
```

---

Every namespace:

```yaml id="pp70"
LimitRange
```

---

Result:

```text id="pp71"
Controlled Growth
```

---

# QoS Production Strategy

Critical workloads:

```text id="pp72"
Guaranteed
```

Examples:

```text id="pp73"
Databases

Kafka

Redis
```

---

Most APIs:

```text id="pp74"
Burstable
```

---

Temporary jobs:

```text id="pp75"
BestEffort
```

only if acceptable.

---

# PriorityClass Strategy

Critical:

```text id="pp76"
Authentication

Payments

Checkout
```

Priority:

```text id="pp77"
High
```

---

Batch:

```text id="pp78"
Analytics

ETL
```

Priority:

```text id="pp79"
Low
```

---

Resource shortage:

```text id="pp80"
Batch Sacrificed

Critical Services Protected
```

---

# HPA Production Pattern

Target:

```text id="pp81"
60%-70%
```

CPU utilization common.

---

Avoid:

```text id="pp82"
95%-100%
```

targets.

---

Reason:

```text id="pp83"
Scaling Happens Too Late
```

---

Example:

```yaml id="pp84"
averageUtilization: 70
```

---

# VPA Production Pattern

Start with:

```yaml id="pp85"
updateMode: Off
```

---

Collect:

```text id="pp86"
Recommendations
```

---

Review:

```text id="pp87"
Weekly

Monthly
```

---

Then:

```text id="pp88"
Adjust Requests
```

manually.

---

Safest strategy.

---

# Cluster Autoscaler Pattern

Configure:

```text id="pp89"
Min Nodes

Max Nodes
```

---

Example:

```text id="pp90"
Min

3
```

---

```text id="pp91"
Max

50
```

---

Provides:

```text id="pp92"
Elastic Capacity
```

---

# Production Resource Checklist

Every Deployment:

```text id="pp93"
Requests
```

✔

---

```text id="pp94"
Limits
```

✔

---

```text id="pp95"
HPA
```

✔

---

```text id="pp96"
Monitoring
```

✔

---

```text id="pp97"
Alerts
```

✔

---

Namespace:

```text id="pp98"
LimitRange
```

✔

---

```text id="pp99"
ResourceQuota
```

✔

---

Cluster:

```text id="pp100"
Cluster Autoscaler
```

✔

---

# Troubleshooting Workflow

Application slow?

---

Check:

```bash id="pp101"
kubectl top pod
```

---

Question:

```text id="pp102"
CPU Throttling?
```

---

Question:

```text id="pp103"
Memory Pressure?
```

---

Question:

```text id="pp104"
Node Pressure?
```

---

Check:

```bash id="pp105"
kubectl describe pod
```

---

Check:

```bash id="pp106"
kubectl describe node
```

---

Check:

```bash id="pp107"
kubectl get events
```

---

This workflow solves most issues.

---

# Common Anti-Patterns

---

## No Requests

```yaml id="pp108"
resources: {}
```

---

Result:

```text id="pp109"
BestEffort

Unpredictable Scheduling
```

---

## Requests Equal Limits Everywhere

```yaml id="pp110"
requests:
  cpu: "2"

limits:
  cpu: "2"
```

---

Result:

```text id="pp111"
Low Utilization

High Cost
```

---

## Huge Limits

```yaml id="pp112"
requests:
  cpu: "10m"

limits:
  cpu: "8"
```

---

Result:

```text id="pp113"
Extreme Overcommitment
```

---

## No ResourceQuota

Result:

```text id="pp114"
One Team

Consumes Everything
```

---

## HPA Without Requests

Result:

```text id="pp115"
Broken Scaling
```

---

# Complete Production Example

Namespace:

```text id="pp116"
payments
```

---

LimitRange:

```text id="pp117"
Default Requests

Default Limits
```

---

ResourceQuota:

```text id="pp118"
20 CPU

40Gi Memory
```

---

Deployment:

```yaml id="pp119"
requests:
  cpu: "250m"

limits:
  cpu: "500m"
```

---

HPA:

```yaml id="pp120"
minReplicas: 3

maxReplicas: 50
```

---

PriorityClass:

```text id="pp121"
High
```

---

Cluster Autoscaler:

```text id="pp122"
Enabled
```

---

Result:

```text id="pp123"
Production Ready
```

---

# Senior Engineer Mindset

Junior engineer asks:

```text id="pp124"
How Much CPU

Does Pod Need?
```

---

Senior engineer asks:

```text id="pp125"
How Does This Affect

Scheduling

QoS

Autoscaling

Node Capacity

Cloud Cost
```

---

Understanding those relationships is the difference between:

```text id="pp126"
Using Kubernetes
```

and:

```text id="pp127"
Operating Kubernetes
```

---

# Interview Questions

---

## Most Important Resource Setting?

Answer:

```text id="pp128"
Requests
```

---

## Why?

Answer:

```text id="pp129"
Scheduling

QoS

Autoscaling

Capacity Planning
```

all depend on them.

---

## Production Autoscaling Stack?

Answer:

```text id="pp130"
HPA

+

Cluster Autoscaler
```

---

## Why Use LimitRange?

Answer:

```text id="pp131"
Resource Standards
```

---

## Why Use ResourceQuota?

Answer:

```text id="pp132"
Namespace Resource Governance
```

---

## Most Common Cause Of High Cloud Cost?

Answer:

```text id="pp133"
Over-Provisioned Requests
```

---

## Most Common Cause Of Scheduling Problems?

Answer:

```text id="pp134"
Incorrect Requests
```

---

## Most Common Cause Of HPA Problems?

Answer:

```text id="pp135"
Incorrect Requests
```

---

Notice the pattern.

---

# Final Resource Management Model

```text id="pp136"
Requests

↓

Scheduler

↓

QoS

↓

Autoscaling

↓

Node Utilization

↓

Cluster Capacity

↓

Cloud Cost
```

Everything begins with:

```text id="pp137"
Accurate Resource Requests
```

---

# Key Takeaways

```text id="pp138"
Requests
=
Foundation

Limits
=
Protection

QoS
=
Eviction Priority

LimitRange
=
Standards

ResourceQuota
=
Governance

HPA
=
More Pods

VPA
=
Better Sizing

Cluster Autoscaler
=
More Nodes

Monitoring
=
Required

Accurate Requests
=
Everything
```

This module brings together all previous lessons into a complete production resource-management strategy. Mastering these concepts is what separates someone who can deploy Kubernetes workloads from someone who can reliably operate large-scale Kubernetes platforms in production.
