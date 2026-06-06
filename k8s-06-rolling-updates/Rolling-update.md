# Kubernetes Rolling Update - Deep Dive

## Question:
How does Kubernetes know a Deployment already exists and needs to be updated instead of creating a new one

### Answer
The answer is: by resource Kind + Name + Namespace.

## What is a Rolling Update?

A Rolling Update is Kubernetes' default deployment strategy that updates an application gradually without causing downtime.

Instead of terminating all old Pods and creating new Pods simultaneously, Kubernetes replaces old Pods with new ones in a controlled manner.

This ensures:

* High availability
* Zero or minimal downtime
* Easy rollback
* Controlled resource consumption

---

# The Components Involved

Before understanding the update process, it's important to understand the Kubernetes objects involved.

```text
Deployment
    |
    +---- ReplicaSet (v1)
               |
               +---- Pod
               +---- Pod
               +---- Pod
```

### Deployment

A Deployment is the desired state definition.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 4
```

The Deployment itself does not create Pods directly.

---

### ReplicaSet

A ReplicaSet ensures the required number of Pods are running.

Example:

```text
Desired replicas = 4

ReplicaSet ensures:
4 Pods are always running
```

---

### Pods

Pods run the actual containers.

```text
Pod
 └── nginx:1.26
```

---

# Initial Deployment

Suppose we deploy:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app

spec:
  replicas: 4

  selector:
    matchLabels:
      app: my-app

  template:
    metadata:
      labels:
        app: my-app

    spec:
      containers:
      - name: app
        image: nginx:1.26
```

Apply:

```bash
kubectl apply -f deployment.yaml
```

Kubernetes creates:

```text
Deployment
    |
    +---- ReplicaSet-v1
             |
             +---- Pod-1 (nginx:1.26)
             +---- Pod-2 (nginx:1.26)
             +---- Pod-3 (nginx:1.26)
             +---- Pod-4 (nginx:1.26)
```

---

# What Triggers a Rolling Update?

Any modification to the Pod Template triggers a new rollout.

Examples:

### Image Change

```yaml
image: nginx:1.27
```

### Environment Variable Change

```yaml
env:
- name: ENV
  value: prod
```

### Resource Change

```yaml
resources:
  requests:
    cpu: 100m
```

### Command Change

```yaml
command: ["python","app.py"]
```

---

# What Does NOT Trigger a Rolling Update?

Changes outside the Pod template.

Examples:

```yaml
replicas: 10
```

Scaling does not create a new ReplicaSet.

---

```yaml
metadata:
  labels:
    project: demo
```

Deployment metadata changes do not trigger updates.

---

# Behind the Scenes

Suppose current state:

```text
Deployment
    |
    +---- ReplicaSet-v1
             |
             +---- 4 Pods
```

Current image:

```text
nginx:1.26
```

We update:

```text
nginx:1.27
```

Apply:

```bash
kubectl apply -f deployment.yaml
```

Kubernetes detects:

```text
Pod template changed
```

A new ReplicaSet is created.

```text
Deployment
    |
    +---- ReplicaSet-v1
    |
    +---- ReplicaSet-v2
```

ReplicaSet-v2 uses:

```text
nginx:1.27
```

ReplicaSet-v1 still contains:

```text
nginx:1.26
```

---

# The Rolling Update Process

Assume:

```yaml
replicas: 4

strategy:
  type: RollingUpdate

  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```

---

## Initial State

```text
ReplicaSet-v1

Pod-1
Pod-2
Pod-3
Pod-4
```

Total Pods:

```text
4
```

---

## Step 1

Kubernetes creates one new Pod.

```text
ReplicaSet-v1 = 4 Pods
ReplicaSet-v2 = 1 Pod
```

Total:

```text
5 Pods
```

Because:

```yaml
maxSurge: 1
```

allows one extra Pod.

---

## Step 2

New Pod becomes Ready.

```text
v1 = 4
v2 = 1
```

Kubernetes removes one old Pod.

```text
v1 = 3
v2 = 1
```

Total:

```text
4 Pods
```

---

## Step 3

Kubernetes creates another new Pod.

```text
v1 = 3
v2 = 2
```

Total:

```text
5 Pods
```

---

## Step 4

New Pod becomes Ready.

Old Pod removed.

```text
v1 = 2
v2 = 2
```

---

## Step 5

Continue repeating.

```text
v1 = 1
v2 = 3
```

---

## Final State

```text
v1 = 0
v2 = 4
```

Result:

```text
ReplicaSet-v1 scaled to zero
ReplicaSet-v2 running all Pods
```

---

# Visualization

```text
Time T0

v1 v1 v1 v1


Time T1

v1 v1 v1 v1 v2


Time T2

v1 v1 v1 v2


Time T3

v1 v1 v1 v2 v2


Time T4

v1 v1 v2 v2


Time T5

v1 v2 v2 v2


Time T6

v2 v2 v2 v2
```

---

# Understanding maxSurge

Controls extra Pods during deployment.

```yaml
maxSurge: 1
```

Desired replicas:

```text
4
```

Maximum Pods allowed:

```text
4 + 1 = 5
```

---

Percentage example:

```yaml
maxSurge: 25%
```

For 8 replicas:

```text
25% of 8 = 2

Maximum Pods = 10
```

---

# Understanding maxUnavailable

Controls how many Pods can be unavailable.

```yaml
maxUnavailable: 1
```

Means:

```text
At least 3 Pods remain available
```

For:

```yaml
replicas: 10
maxUnavailable: 20%
```

Kubernetes allows:

```text
2 Pods unavailable
```

during rollout.

---

# Readiness Probe Impact

Rolling updates rely heavily on readiness probes.

Example:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
```

A Pod is considered ready only when:

```text
Readiness Probe = Success
```

Until then:

```text
Traffic is NOT routed
```

through the Service.

---

# Service During Rolling Update

Service continuously updates endpoints.

Before update:

```text
Service
  |
  +---- Pod-1
  +---- Pod-2
  +---- Pod-3
  +---- Pod-4
```

During update:

```text
Service
  |
  +---- Pod-2
  +---- Pod-3
  +---- Pod-4
  +---- Pod-new
```

Kube-proxy automatically updates routing.

No manual action needed.

---

# What Happens if New Pods Fail?

Suppose:

```text
nginx:1.27
```

contains a bug.

New Pod:

```text
CrashLoopBackOff
```

or

```text
Readiness Probe Failed
```

Kubernetes pauses rollout.

Example:

```text
ReplicaSet-v1 = 4 Pods

ReplicaSet-v2 = 1 Failed Pod
```

Old Pods continue serving traffic.

Application remains available.

---

# Rollout Status

Check progress:

```bash
kubectl rollout status deployment/my-app
```

Output:

```text
Waiting for deployment rollout to finish...
```

or

```text
deployment "my-app" successfully rolled out
```

---

# Rollout History

View revisions:

```bash
kubectl rollout history deployment/my-app
```

Example:

```text
REVISION  CHANGE-CAUSE

1         Initial release
2         Updated image
3         Added environment variables
```

---

# Rollback

Rollback to previous version:

```bash
kubectl rollout undo deployment/my-app
```

Kubernetes simply scales:

```text
ReplicaSet-v2 ↓
ReplicaSet-v1 ↑
```

No image rebuilding required.

---

# Deployment Lifecycle Internals

When you update a Deployment:

```text
Deployment Controller
        |
        | Detects Pod Template Change
        v
Creates New ReplicaSet
        |
        v
Scales Up New ReplicaSet
        |
        v
Waits For Readiness
        |
        v
Scales Down Old ReplicaSet
        |
        v
Repeats Until Complete
```

---

# Useful Commands

### Watch Deployment

```bash
kubectl get deployment -w
```

### Watch Pods

```bash
kubectl get pods -w
```

### View ReplicaSets

```bash
kubectl get rs
```

### Deployment Details

```bash
kubectl describe deployment my-app
```

### Rollout Status

```bash
kubectl rollout status deployment/my-app
```

### Rollout History

```bash
kubectl rollout history deployment/my-app
```

### Rollback

```bash
kubectl rollout undo deployment/my-app
```

---

# Interview Summary

Rolling Update is Kubernetes' default deployment strategy. A Deployment never updates Pods directly. Instead, Kubernetes creates a new ReplicaSet for the updated Pod template, gradually scales it up, and scales the old ReplicaSet down while respecting `maxSurge`, `maxUnavailable`, readiness probes, and Service endpoint updates. This enables zero-downtime deployments and easy rollbacks.
