# 02 - CPU Throttling

---

# Learning Objectives

By the end of this lab you will understand:

* What CPU throttling is
* Why Kubernetes throttles CPU
* Difference between CPU and Memory enforcement
* How Linux cgroups enforce CPU limits
* How to observe throttling
* How CPU requests and limits work together
* Production CPU sizing strategies
* Common CPU-related troubleshooting scenarios
* Interview questions related to CPU limits

---

# Prerequisites

Complete:

```text
01-requests-vs-limits.md
```

You should already understand:

```text
Request
=
Scheduling

Limit
=
Runtime Enforcement
```

---

# What Is CPU Throttling?

Imagine:

```text
Node CPU Capacity

4 CPU Cores
```

Your application has:

```yaml
resources:
  limits:
    cpu: "250m"
```

Meaning:

```text
Maximum CPU Allowed

0.25 CPU Core
```

---

Now suppose your application suddenly wants:

```text
1 CPU
```

Can Kubernetes allow it?

No.

The container is only allowed:

```text
250m
```

Therefore Kubernetes:

```text
Slows It Down
```

This process is called:

```text
CPU Throttling
```

---

# Important Difference

CPU and Memory behave differently.

| Resource | Exceed Limit |
| -------- | ------------ |
| CPU      | Throttled    |
| Memory   | OOMKilled    |

---

CPU:

```text
Compressible Resource
```

Meaning:

```text
Can Give Less
```

Memory:

```text
Non-Compressible Resource
```

Meaning:

```text
Cannot Give Less
```

---

# Real World Analogy

Imagine a highway.

CPU request:

```text
Reserved Lane
```

CPU limit:

```text
Speed Limit
```

When you exceed:

```text
Speed Limit
```

Police slows you down.

You are not removed from the road.

This is CPU throttling.

---

# Current Project Configuration

Open:

```text
k8s/deployment.yaml
```

Current resources:

```yaml
resources:
  requests:
    cpu: "100m"

  limits:
    cpu: "250m"
```

Meaning:

```text
Guaranteed:
100m

Maximum:
250m
```

---

# Deploy Application

```bash
kubectl apply -f k8s/namespace.yaml

kubectl apply \
  -n resource-demo \
  -f k8s/deployment.yaml

kubectl apply \
  -n resource-demo \
  -f k8s/service.yaml
```

Wait:

```bash
kubectl get pods -n resource-demo
```

Expected:

```text
Running
```

---

# Enable Port Forwarding

Terminal 1:

```bash
kubectl port-forward \
svc/loadtest-service \
8080:80 \
-n resource-demo
```

---

# Observe CPU Usage

Terminal 2:

```bash
kubectl top pod \
-n resource-demo
```

Expected:

```text
NAME

loadtest-xxxxx

CPU
5m

MEMORY
20Mi
```

Application is idle.

---

# Generate CPU Load

Open another terminal.

Run:

```bash
curl \
"http://localhost:8080/burn-cpu?seconds=60"
```

The endpoint intentionally consumes CPU.

---

# Watch CPU During Load

While curl runs:

```bash
kubectl top pod \
-n resource-demo \
--containers
```

Expected:

```text
CPU

220m
230m
240m
250m
```

You should notice:

```text
Never Above 250m
```

Why?

Because:

```yaml
limits:
  cpu: "250m"
```

---

# What Kubernetes Is Doing

Internally:

```text
Linux Cgroups
```

control CPU allocation.

Kubernetes configures:

```text
CPU Quota
```

for the container.

---

Simplified:

```text
Container Allowed

250ms CPU

Every 1000ms
```

If container wants:

```text
500ms CPU
```

Linux denies extra CPU time.

---

Result:

```text
Container Waits
```

This waiting is:

```text
CPU Throttling
```

---

# Verify Container Is Still Healthy

Even under throttling:

```bash
kubectl get pods \
-n resource-demo
```

Expected:

```text
STATUS

Running
```

Not:

```text
CrashLoopBackOff
```

Not:

```text
OOMKilled
```

---

# Experiment 1

Increase CPU Limit

Edit deployment:

```yaml
limits:
  cpu: "1000m"
```

Apply:

```bash
kubectl apply \
-f k8s/deployment.yaml \
-n resource-demo
```

Wait:

```bash
kubectl rollout status deployment/loadtest \
-n resource-demo
```

Run CPU burn again:

```bash
curl \
"http://localhost:8080/burn-cpu?seconds=60"
```

Observe:

```bash
kubectl top pod \
-n resource-demo
```

Expected:

```text
700m
800m
900m
1000m
```

---

# Experiment 2

Remove CPU Limit

Use:

```yaml
resources:
  requests:
    cpu: "100m"
```

No limit.

Deploy.

Run CPU burn.

Observe:

```bash
kubectl top pod
```

Result:

```text
Container may consume entire CPU capacity.
```

---

# Why CPU Limits Matter

Without CPU limits:

```text
Pod A
Consumes All CPU
```

Other Pods:

```text
Become Slow
```

Node:

```text
Becomes Unstable
```

---

# Production Example

Microservice:

```text
Normal Usage

50m CPU
```

Occasional spikes:

```text
400m CPU
```

Good configuration:

```yaml
requests:
  cpu: "100m"

limits:
  cpu: "500m"
```

Why?

```text
Reserve 100m

Allow bursts to 500m
```

---

# Bad Production Example

```yaml
requests:
  cpu: "1000m"

limits:
  cpu: "1000m"
```

For a service using:

```text
20m CPU
```

Problem:

```text
Wastes cluster resources
```

Scheduler reserves:

```text
1 CPU
```

that is never used.

---

# Monitoring CPU

View node usage:

```bash
kubectl top node
```

View pod usage:

```bash
kubectl top pod
```

View all namespaces:

```bash
kubectl top pod -A
```

---

# Viewing Resource Configuration

```bash
kubectl describe pod POD_NAME
```

Look for:

```text
Requests

Limits
```

---

# Troubleshooting

---

## Problem

Application Slow

Check:

```bash
kubectl top pod
```

Question:

```text
Near CPU Limit?
```

If yes:

```text
CPU Throttling
```

Likely occurring.

---

## Problem

High Response Time

Check:

```bash
kubectl describe pod
```

Verify:

```text
CPU Limit Too Low?
```

---

## Problem

HPA Not Scaling

Check:

```bash
kubectl get hpa
```

Check:

```bash
kubectl top pod
```

Verify:

```text
Metrics Server Running
```

---

# Production Investigation Workflow

Step 1

```bash
kubectl top pod
```

---

Step 2

```bash
kubectl describe pod
```

---

Step 3

```bash
kubectl logs POD_NAME
```

---

Step 4

Check:

```text
CPU Request

CPU Limit

Actual CPU Usage
```

---

# Common Mistakes

---

## Limit Too Low

```yaml
limits:
  cpu: "50m"
```

Result:

```text
Severe throttling
```

---

## Request Too High

```yaml
requests:
  cpu: "4"
```

Result:

```text
Pods remain Pending
```

---

## No Limit

```yaml
requests:
  cpu: "100m"
```

Result:

```text
Can starve other workloads
```

---

## Request Equals Limit Everywhere

```yaml
requests:
  cpu: "1000m"

limits:
  cpu: "1000m"
```

Problem:

```text
No burst capability
```

---

# Interview Questions

---

## What Is CPU Throttling?

Answer:

```text
CPU usage exceeds configured limit.

Linux cgroups restrict execution.

Container is slowed down.
```

---

## Is CPU Limit A Hard Limit?

Answer:

```text
Yes
```

---

## What Happens When CPU Limit Is Exceeded?

Answer:

```text
Container is throttled.

Not killed.
```

---

## Why Is CPU Throttled Instead Of Killed?

Answer:

```text
CPU is compressible.
```

---

## Does Scheduler Use CPU Limits?

Answer:

```text
No.

Scheduler uses requests.
```

---

## Can A Pod Exceed Its CPU Request?

Answer:

```text
Yes

Up to CPU limit.
```

---

## Can A Pod Exceed CPU Limit?

Answer:

```text
No
```

---

# Cleanup

Delete resources:

```bash
kubectl delete \
-f k8s/deployment.yaml \
-n resource-demo
```

```bash
kubectl delete \
-f k8s/service.yaml \
-n resource-demo
```

```bash
kubectl delete namespace resource-demo
```

---

# Key Takeaways

```text
CPU Request
=
Scheduling

CPU Limit
=
Maximum CPU

CPU Exceeds Limit
=
Throttled

CPU Exceeds Request
=
Allowed

CPU Is Compressible
=
Slow Down

Memory Is Not Compressible
=
OOMKill

Scheduler Uses
=
Requests Only
```

You now understand how Kubernetes enforces CPU limits and why applications become slow instead of crashing when CPU usage exceeds configured limits.
