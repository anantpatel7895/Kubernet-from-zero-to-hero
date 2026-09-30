# 09 - LimitRange

---

# Learning Objectives

By the end of this lab you will understand:

* What a LimitRange is
* Why LimitRange exists
* Default Requests
* Default Limits
* Minimum Resource Constraints
* Maximum Resource Constraints
* maxLimitRequestRatio
* Namespace Governance
* How LimitRange interacts with QoS
* Common production policies
* Troubleshooting LimitRange failures
* Interview questions related to LimitRange

---

# What Problem Does LimitRange Solve?

Imagine a namespace:

```text
production
```

Developers deploy:

```yaml
apiVersion: v1
kind: Pod

spec:
  containers:
  - name: app
    image: nginx
```

Notice:

```text
No Requests

No Limits
```

---

Question:

What QoS Class?

Answer:

```text
BestEffort
```

---

What happens if:

```text
100 Developers
```

deploy workloads like this?

---

Result:

```text
No Resource Planning

No Capacity Control

No Guarantees

High Eviction Risk
```

---

Cluster administrators need:

```text
Guard Rails
```

to protect the cluster.

---

This is where:

```text
LimitRange
```

comes in.

---

# What Is LimitRange?

LimitRange is a:

```text
Namespace Policy
```

that can:

```text
Apply Default Requests

Apply Default Limits

Enforce Minimum Values

Enforce Maximum Values

Enforce Ratios
```

---

Think of it as:

```text
Resource Rules

For A Namespace
```

---

# Current Project LimitRange

File:

```text
k8s/limitrange.yaml
```

---

Review:

```yaml
default:
  cpu: "250m"
  memory: "256Mi"

defaultRequest:
  cpu: "100m"
  memory: "128Mi"

max:
  cpu: "1"
  memory: "1Gi"

min:
  cpu: "50m"
  memory: "64Mi"
```

---

This means:

```text
Default Request

CPU = 100m
Memory = 128Mi
```

---

Default Limit:

```text
CPU = 250m
Memory = 256Mi
```

---

Maximum:

```text
CPU = 1 Core
Memory = 1Gi
```

---

Minimum:

```text
CPU = 50m
Memory = 64Mi
```

---

# Deploy Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

---

Apply LimitRange

```bash
kubectl apply -f k8s/limitrange.yaml
```

---

Verify

```bash
kubectl get limitrange \
-n resource-demo
```

Expected:

```text
default-limits
```

---

Describe

```bash
kubectl describe limitrange default-limits \
-n resource-demo
```

---

Expected:

```text
Default Request

CPU:      100m
Memory:   128Mi

Default Limit

CPU:      250m
Memory:   256Mi
```

---

# How Defaults Work

Create:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: no-resources

spec:
  containers:
  - name: app
    image: busybox

    command:
    - sh
    - -c
    - sleep 3600
```

Save:

```text
no-resources.yaml
```

---

Deploy

```bash
kubectl apply \
-f no-resources.yaml \
-n resource-demo
```

---

Pod never defined:

```text
Requests

Limits
```

---

Yet:

```bash
kubectl describe pod no-resources \
-n resource-demo
```

shows:

```text
Requests

CPU:      100m
Memory:   128Mi

Limits

CPU:      250m
Memory:   256Mi
```

---

Why?

Because:

```text
LimitRange Injected Defaults
```

automatically.

---

# Why This Matters

Without LimitRange:

```text
BestEffort Everywhere
```

---

With LimitRange:

```text
Burstable By Default
```

---

This greatly improves:

```text
Scheduling

Resource Planning

Cluster Stability
```

---

# Minimum Values

LimitRange can enforce:

```text
Minimum CPU

Minimum Memory
```

---

Current configuration:

```yaml
min:
  cpu: "50m"
  memory: "64Mi"
```

---

Create:

```yaml
resources:
  requests:
    cpu: "10m"
    memory: "32Mi"
```

---

Deploy:

```bash
kubectl apply \
-f tiny-pod.yaml \
-n resource-demo
```

---

Expected:

```text
Forbidden
```

---

Error:

```text
Minimum cpu usage per Container is 50m
```

---

Kubernetes rejects the Pod.

---

# Maximum Values

Current:

```yaml
max:
  cpu: "1"
  memory: "1Gi"
```

---

Create:

```yaml
resources:
  limits:
    cpu: "4"
    memory: "8Gi"
```

---

Deploy:

```bash
kubectl apply \
-f giant-pod.yaml \
-n resource-demo
```

---

Expected:

```text
Forbidden
```

---

Reason:

```text
Maximum Limit Exceeded
```

---

# Why Maximums Matter

Without maximums:

Developer accidentally deploys:

```yaml
limits:
  memory: "128Gi"
```

---

Cluster:

```text
Cannot Schedule Workloads

Resources Wasted

Autoscaling Problems
```

---

Maximums prevent this.

---

# Understanding maxLimitRequestRatio

One of the least understood settings.

Current:

```yaml
maxLimitRequestRatio:
  cpu: "4"

  memory: "4"
```

---

Meaning:

```text
Limit

Cannot Exceed

4 × Request
```

---

Example

Request:

```yaml
requests:
  memory: "128Mi"
```

---

Maximum allowed limit:

```text
512Mi
```

Because:

```text
128 × 4

=
512
```

---

Allowed:

```yaml
limits:
  memory: "512Mi"
```

---

Rejected:

```yaml
limits:
  memory: "2Gi"
```

---

Reason:

```text
Ratio Too Large
```

---

# Why Ratio Exists

Without ratio:

```yaml
requests:
  cpu: "10m"

limits:
  cpu: "8"
```

---

Scheduler sees:

```text
10m
```

Reality:

```text
8 CPU
```

Potential.

---

This creates:

```text
Extreme Overcommitment
```

---

Ratio limits prevent abuse.

---

# Pod-Level LimitRange

Your configuration includes:

```yaml
type: Pod
```

---

Example:

```yaml
- type: Pod

  max:
    cpu: "2"
    memory: "2Gi"
```

---

Meaning:

```text
Sum Of All Containers

Cannot Exceed

2 CPU

2Gi Memory
```

---

# Multi-Container Example

Container A:

```yaml
cpu: 1
```

Container B:

```yaml
cpu: 1
```

Total:

```text
2 CPU
```

Allowed.

---

Container C:

```yaml
cpu: 500m
```

Total:

```text
2.5 CPU
```

Rejected.

---

# Verify Injected Resources

Create Pod without resources.

Check:

```bash
kubectl describe pod no-resources
```

---

Look for:

```text
Requests

Limits
```

injected automatically.

---

# QoS Impact

Without LimitRange:

```text
BestEffort
```

---

With defaults:

```text
Burstable
```

---

This changes:

```text
Eviction Priority

Scheduling Behavior

Resource Guarantees
```

---

# Production Use Cases

Development Namespace:

```yaml
defaultRequest:
  cpu: "50m"
```

---

Production Namespace:

```yaml
defaultRequest:
  cpu: "250m"
```

---

Critical Namespace:

```yaml
defaultRequest:
  cpu: "500m"
```

---

Different teams:

```text
Different Policies
```

---

# Troubleshooting

---

## Pod Rejected

Check:

```bash
kubectl describe limitrange \
-n resource-demo
```

---

Look for:

```text
min

max
```

violations.

---

## Unexpected Requests

Developer:

```text
Did Not Configure Requests
```

---

Check:

```bash
kubectl describe pod
```

---

LimitRange may have:

```text
Injected Defaults
```

---

## Unexpected QoS

Check:

```bash
kubectl get pod POD_NAME \
-o jsonpath='{.status.qosClass}'
```

---

LimitRange defaults may have changed:

```text
BestEffort

→

Burstable
```

---

# Common Mistakes

---

## Assuming LimitRange Is Cluster Wide

False.

LimitRange is:

```text
Namespace Scoped
```

---

## Forgetting Defaults Exist

Developer:

```text
Did Not Set Requests
```

---

But scheduler sees:

```text
Injected Requests
```

---

## Very Large Ratios

```yaml
maxLimitRequestRatio:
  cpu: "100"
```

Dangerous.

---

## No Minimum Values

Allows:

```text
Tiny Requests

Huge Limits
```

which often causes:

```text
Scheduling Problems
```

---

# Interview Questions

---

## What Is LimitRange?

Answer:

```text
Namespace Resource Policy
```

---

## What Can LimitRange Do?

Answer:

```text
Defaults

Minimums

Maximums

Ratios
```

---

## Is LimitRange Namespace Scoped?

Answer:

```text
Yes
```

---

## What Happens If Requests Are Missing?

Answer:

```text
Default Requests May Be Injected
```

---

## What Is maxLimitRequestRatio?

Answer:

```text
Maximum Allowed

Limit ÷ Request
```

---

## Why Use LimitRange?

Answer:

```text
Prevent Resource Abuse

Apply Standards

Improve Governance
```

---

## Can LimitRange Reject Pods?

Answer:

```text
Yes
```

---

# Cleanup

```bash
kubectl delete pod no-resources \
-n resource-demo
```

---

Optional:

```bash
kubectl delete limitrange default-limits \
-n resource-demo
```

---

# Key Takeaways

```text
LimitRange
=
Namespace Policy

Can Apply

Default Requests

Default Limits

Minimum Values

Maximum Values

Ratios

Defaults
=
Automatically Injected

LimitRange
=
Governance

ResourceQuota
=
Consumption Control
```

LimitRange is one of the most important cluster-governance tools because it ensures every workload follows resource standards, even when developers forget to configure them.
