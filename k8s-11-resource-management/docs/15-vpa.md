# 15 - Vertical Pod Autoscaler (VPA)

---

# Learning Objectives

By the end of this module you will understand:

* What Vertical Pod Autoscaler (VPA) is
* Why VPA exists
* How VPA works
* Recommendation Engine
* VPA Components
* Update Modes
* VPA vs HPA
* Resource Right-Sizing
* Cost Optimization
* Production VPA Strategies
* VPA Limitations
* Common Mistakes
* Interview Questions

---

# What Problem Does VPA Solve?

Imagine an application.

Developer configures:

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"

  limits:
    cpu: "4"
    memory: "8Gi"
```

---

Actual usage:

```text
CPU

100m
```

Memory:

```text
256Mi
```

---

Result:

```text
Massive Over-Provisioning

Wasted Capacity

Higher Cloud Costs
```

---

Another application:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
```

---

Actual usage:

```text
CPU

1500m
```

Memory:

```text
2Gi
```

---

Result:

```text
CPU Throttling

OOMKills

Poor Performance
```

---

Question:

How do we automatically find the correct size?

Answer:

```text
VPA
```

---

# What Is VPA?

VPA means:

```text
Vertical Pod Autoscaler
```

---

Instead of:

```text
More Pods
```

VPA provides:

```text
Bigger Pods
```

or

```text
Smaller Pods
```

---

Example:

Before:

```yaml
requests:
  cpu: "100m"
  memory: "128Mi"
```

---

After VPA:

```yaml
requests:
  cpu: "500m"
  memory: "1Gi"
```

---

# Horizontal vs Vertical

HPA:

```text
Scale Out

2 Pods

↓

10 Pods
```

---

VPA:

```text
Scale Up

100m CPU

↓

500m CPU
```

---

HPA changes:

```text
Replica Count
```

---

VPA changes:

```text
Requests

Limits
```

---

# VPA Architecture

```text
Application

↓

Metrics

↓

VPA Recommender

↓

Recommendations

↓

VPA Updater

↓

Pod Restart

↓

New Resources Applied
```

---

# VPA Components

VPA consists of:

```text
Recommender

Updater

Admission Controller
```

---

# Recommender

Analyzes:

```text
CPU Usage

Memory Usage

Historical Data
```

---

Produces:

```text
Recommended Requests

Recommended Limits
```

---

# Updater

Responsible for:

```text
Applying Changes
```

---

Often requires:

```text
Pod Recreation
```

---

# Admission Controller

Intercepts:

```text
New Pod Creation
```

and injects:

```text
Recommended Values
```

---

# Installing VPA

Verify installation:

```bash
kubectl get pods \
-n kube-system
```

---

Look for:

```text
vpa-recommender

vpa-updater

vpa-admission-controller
```

---

Managed Kubernetes services may include VPA support.

---

# Basic VPA Example

Create:

```yaml
apiVersion: autoscaling.k8s.io/v1

kind: VerticalPodAutoscaler

metadata:
  name: loadtest-vpa

spec:

  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: loadtest

  updatePolicy:
    updateMode: Auto
```

---

Apply:

```bash
kubectl apply -f vpa.yaml
```

---

Verify:

```bash
kubectl get vpa
```

---

Expected:

```text
loadtest-vpa
```

---

# View Recommendations

```bash
kubectl describe vpa loadtest-vpa
```

---

Example:

```text
Recommendations

CPU

Target: 400m

Memory

Target: 512Mi
```

---

This is one of the most useful VPA commands.

---

# Update Modes

VPA supports several modes.

---

## Off

```yaml
updateMode: Off
```

---

Behavior:

```text
Generate Recommendations Only

Do Not Change Pods
```

---

Most common starting point.

---

# Initial

```yaml
updateMode: Initial
```

---

Behavior:

```text
Apply Recommendations

Only During Pod Creation
```

---

Running Pods:

```text
Unaffected
```

---

# Auto

```yaml
updateMode: Auto
```

---

Behavior:

```text
Automatically Update Pods
```

---

May trigger:

```text
Pod Recreation
```

---

Use carefully.

---

# Recreate

```yaml
updateMode: Recreate
```

---

Behavior:

```text
Delete Pod

Create New Pod

With Recommended Resources
```

---

Explicit version of Auto behavior.

---

# Why VPA Restarts Pods

Important concept.

---

Changing:

```text
CPU Request

Memory Request
```

requires:

```text
New Pod Spec
```

---

Pod specs are:

```text
Immutable
```

for resource allocation purposes.

---

Result:

```text
Pod Restart Needed
```

---

# Example Recommendation

Current:

```yaml
requests:
  cpu: "100m"
  memory: "128Mi"
```

---

Observed:

```text
CPU

500m
```

Memory:

```text
1Gi
```

---

VPA recommendation:

```yaml
requests:
  cpu: "600m"
  memory: "1200Mi"
```

---

More realistic sizing.

---

# Cost Optimization Example

Cluster:

```text
100 Pods
```

---

Each requests:

```text
2 CPU
```

---

Actual usage:

```text
200m
```

---

VPA recommends:

```text
300m
```

---

Savings:

```text
Huge
```

---

This is one of the biggest VPA benefits.

---

# Resource Right-Sizing

Many teams use:

```text
VPA Recommendations
```

as:

```text
Sizing Guidance
```

even if:

```text
updateMode: Off
```

---

Example workflow:

```text
VPA Recommends

↓

Engineer Reviews

↓

Git Update

↓

Deployment
```

---

Common in regulated environments.

---

# VPA and HPA

Most important topic.

---

Can they work together?

Answer:

```text
Sometimes
```

---

Danger:

HPA uses:

```text
CPU Utilization

Usage ÷ Request
```

---

VPA changes:

```text
Requests
```

---

This changes:

```text
HPA Calculations
```

---

Potential conflict.

---

# Example Conflict

Current:

```yaml
request:
  cpu: 100m
```

Usage:

```text
80m
```

---

HPA sees:

```text
80%
```

---

VPA changes request:

```yaml
cpu: 500m
```

---

Now HPA sees:

```text
16%
```

---

Scaling behavior changes dramatically.

---

# Production Strategy

Common pattern:

```text
HPA

Uses CPU
```

---

VPA:

```text
Controls Memory Only
```

---

or:

```text
Recommendation Mode Only
```

---

This reduces conflicts.

---

# Resource Policy

Example:

```yaml
resourcePolicy:

  containerPolicies:

  - containerName: "*"

    minAllowed:
      cpu: 100m
      memory: 128Mi

    maxAllowed:
      cpu: 2
      memory: 4Gi
```

---

Purpose:

```text
Prevent Extreme Recommendations
```

---

# Production Example

API Service:

```text
Traffic Stable
```

---

Current request:

```text
100m CPU
```

---

Observed usage:

```text
400m CPU
```

---

VPA recommendation:

```text
500m CPU
```

---

Benefits:

```text
Less Throttling

Better Performance
```

---

# Stateful Workloads

VPA is often useful for:

```text
Databases

Caches

Message Brokers
```

because:

```text
Scaling Horizontally

May Be Difficult
```

---

Examples:

```text
Redis

PostgreSQL

Kafka Brokers
```

---

# Viewing Recommendations

Describe:

```bash
kubectl describe vpa VPA_NAME
```

---

Look for:

```text
Target

Lower Bound

Upper Bound
```

---

Example:

```text
CPU

Target: 500m

Lower: 300m

Upper: 800m
```

---

# Troubleshooting

---

## No Recommendations

Check:

```bash
kubectl describe vpa VPA_NAME
```

---

Question:

```text
Enough Metrics Collected?
```

---

VPA needs:

```text
Historical Usage Data
```

---

## Pods Restarting

Check:

```yaml
updateMode: Auto
```

---

Possible cause:

```text
VPA Updating Resources
```

---

## Unexpected Recommendations

Check:

```bash
kubectl top pod
```

---

Question:

```text
Workload Recently Changed?
```

---

# Common Mistakes

---

## Enabling Auto Everywhere

Can cause:

```text
Frequent Restarts
```

---

Start with:

```yaml
updateMode: Off
```

---

## Ignoring Recommendations

Missed opportunity for:

```text
Cost Savings
```

---

## No Resource Policy

Can allow:

```text
Extremely Large

Recommendations
```

---

## HPA + VPA CPU Conflict

Very common production issue.

---

# Useful Commands

List VPA:

```bash
kubectl get vpa
```

---

Describe:

```bash
kubectl describe vpa VPA_NAME
```

---

View usage:

```bash
kubectl top pod
```

---

View deployment:

```bash
kubectl get deployment
```

---

# Interview Questions

---

## What Is VPA?

Answer:

```text
Vertical Pod Autoscaler
```

---

## What Does VPA Change?

Answer:

```text
Requests

Limits
```

---

## What Does HPA Change?

Answer:

```text
Replica Count
```

---

## Main Components Of VPA?

Answer:

```text
Recommender

Updater

Admission Controller
```

---

## Does VPA Usually Restart Pods?

Answer:

```text
Yes
```

---

## Why?

Answer:

```text
Resource Changes

Require New Pod Spec
```

---

## Can HPA And VPA Conflict?

Answer:

```text
Yes

Especially CPU-Based HPA
```

---

## Safest VPA Mode?

Answer:

```text
Off

Recommendation Only
```

---

## Why Use VPA?

Answer:

```text
Right-Sizing

Cost Optimization

Performance Improvement
```

---

# Cleanup

Delete VPA:

```bash
kubectl delete vpa loadtest-vpa
```

---

# Key Takeaways

```text
VPA
=
Vertical Scaling

Changes
=
Requests And Limits

HPA
=
Horizontal Scaling

Changes
=
Replicas

VPA Components

Recommender

Updater

Admission Controller

Best Starting Mode

Off

VPA
=
Right Sizing

VPA
=
Cost Optimization

HPA + VPA
=
Requires Careful Design
```

Vertical Pod Autoscaler helps solve one of the hardest problems in Kubernetes: determining the correct amount of CPU and memory for workloads. Used properly, it can significantly reduce cloud costs while improving application stability and performance.
