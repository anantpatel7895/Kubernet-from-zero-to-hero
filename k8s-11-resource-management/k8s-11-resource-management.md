# k8s-11-resource-management

## Directory structure

```text
k8s-11-resource-management/
├── app/
│   └── loadtest/
│       ├── Dockerfile
│       ├── main.py
│       └── requirements.txt
├── k8s/
│   ├── deployment.yaml
│   ├── limitrange.yaml
│   ├── multi-container.yaml
│   ├── namespace.yaml
│   ├── priorityclass.yaml
│   ├── qos-besteffort.yaml
│   ├── qos-burstable.yaml
│   ├── qos-guaranteed.yaml
│   ├── resourcequota.yaml
│   └── service.yaml
├── test/
│   └── smoke-test.sh
└── README.md
```

## Files

### `k8s-11-resource-management/app/loadtest/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -r requirements.txt

COPY . .

CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```

### `k8s-11-resource-management/app/loadtest/main.py`

```python
from fastapi import FastAPI
import time

app = FastAPI()

# Keeps allocated memory blocks alive so we can watch memory grow.
_memory_hog = []


@app.get("/")
def home():
    return {
        "service": "loadtest",
        "message": "Resource Management Demo",
        "endpoints": [
            "/burn-cpu?seconds=10   -> burns CPU (watch throttling)",
            "/eat-memory?mb=100     -> allocates memory (watch OOMKill)",
            "/release               -> frees allocated memory",
        ],
    }


@app.get("/burn-cpu")
def burn_cpu(seconds: int = 10):
    """Busy-loop to consume CPU. With a low CPU limit you'll see throttling."""
    start = time.time()
    count = 0
    while time.time() - start < seconds:
        count += 1
    return {
        "action": "burn-cpu",
        "seconds_requested": seconds,
        "iterations": count,
    }


@app.get("/eat-memory")
def eat_memory(mb: int = 100):
    """Allocate `mb` megabytes. Exceed the memory limit and the Pod is OOMKilled."""
    block = bytearray(mb * 1024 * 1024)
    _memory_hog.append(block)
    total_mb = sum(len(b) for b in _memory_hog) // (1024 * 1024)
    return {
        "action": "eat-memory",
        "added_mb": mb,
        "total_held_mb": total_mb,
    }


@app.get("/release")
def release():
    """Drop all held memory."""
    _memory_hog.clear()
    return {"action": "release", "total_held_mb": 0}


@app.get("/health")
def health():
    return {"status": "ok"}
```

### `k8s-11-resource-management/app/loadtest/requirements.txt`

```text
fastapi
uvicorn
```

### `k8s-11-resource-management/k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: loadtest

spec:
  replicas: 1

  selector:
    matchLabels:
      app: loadtest

  template:
    metadata:
      labels:
        app: loadtest

    spec:
      containers:
      - name: loadtest

        image: loadtest:v1

        ports:
        - containerPort: 8000

        # Requests  = what the scheduler reserves for this container.
        # Limits    = the hard ceiling. Exceed memory -> OOMKilled.
        #             Exceed CPU -> throttled (never killed).
        #
        # CPU units:  1 = 1 core = 1000m.  100m = 0.1 core.
        # Overcommit: requests < limits, so the sum of limits on a node may
        #             exceed node capacity. Pods "burst" into spare capacity
        #             until the node is full.
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
            ephemeral-storage: "256Mi"   # disk for logs / scratch / emptyDir
          limits:
            cpu: "250m"
            memory: "256Mi"
            ephemeral-storage: "512Mi"   # exceed -> Pod evicted (not OOMKilled)
```

### `k8s-11-resource-management/k8s/limitrange.yaml`

```yaml
# LimitRange applies DEFAULT requests/limits to any container that does not
# specify its own, and enforces min/max bounds. This is how a cluster admin
# stops "BestEffort everywhere" from happening.
#
# `type` can be Container, Pod, or PersistentVolumeClaim:
#   - Container : bounds apply to each container individually
#   - Pod       : bounds apply to the SUM of all containers in a Pod
#   - PersistentVolumeClaim : bounds the requested storage size
apiVersion: v1
kind: LimitRange

metadata:
  name: default-limits
  namespace: resource-demo

spec:
  limits:
  - type: Container

    # used when a container omits limits
    default:
      cpu: "250m"
      memory: "256Mi"

    # used when a container omits requests
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"

    # hard ceiling no container may exceed
    max:
      cpu: "1"
      memory: "1Gi"

    # floor every container must request
    min:
      cpu: "50m"
      memory: "64Mi"

    # limit / request may not exceed this ratio per resource.
    # e.g. with memory request 128Mi, the limit may be at most 512Mi (4x).
    # This caps how aggressively a Burstable Pod can overcommit.
    maxLimitRequestRatio:
      cpu: "4"
      memory: "4"

  # Example of a Pod-scoped rule: the SUM of all containers in one Pod
  # may not exceed these limits.
  - type: Pod
    max:
      cpu: "2"
      memory: "2Gi"
```

### `k8s-11-resource-management/k8s/multi-container.yaml`

```yaml
# Multi-container + initContainer resource accounting.
#
# How Kubernetes computes a Pod's effective request/limit:
#   - Sum the requests (and limits) of all REGULAR containers.
#   - Compare against the LARGEST single initContainer value.
#   - The Pod's effective amount = max(sum of regular, largest init).
#
# For this Pod:
#   regular containers sum:  cpu 100m+50m = 150m,  mem 128Mi+64Mi = 192Mi
#   largest init container:  cpu 200m,             mem 64Mi
#   effective request:       cpu max(150m,200m)=200m,  mem max(192Mi,64Mi)=192Mi
#
# QoS here is Burstable (requests set, but requests != limits).
apiVersion: v1
kind: Pod

metadata:
  name: multi-container
  labels:
    qos: burstable

spec:
  initContainers:
  - name: init-setup
    image: busybox:1.36
    command: ["sh", "-c", "echo warming up; sleep 2"]
    resources:
      requests:
        cpu: "200m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "64Mi"

  containers:
  - name: app
    image: loadtest:v1
    ports:
    - containerPort: 8000
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "300m"
        memory: "256Mi"

  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "while true; do sleep 30; done"]
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
      limits:
        cpu: "100m"
        memory: "128Mi"
```

### `k8s-11-resource-management/k8s/namespace.yaml`

```yaml
# A dedicated namespace for the resource-management demos.
#
# WHY this matters:
#   LimitRange and ResourceQuota are NAMESPACE-SCOPED. Applying them to the
#   `default` namespace would silently affect every other workload there.
#   Worse: once a ResourceQuota sets requests.cpu/requests.memory on a
#   namespace, Kubernetes REJECTS any BestEffort Pod (one with no requests/
#   limits) created in it. Isolating the demos here keeps that contained.
apiVersion: v1
kind: Namespace

metadata:
  name: resource-demo
```

### `k8s-11-resource-management/k8s/priorityclass.yaml`

```yaml
# PriorityClass affects scheduling and eviction ORDER, on top of QoS.
#
# QoS vs Priority — they work together:
#   - QoS class   : decided automatically from requests/limits.
#   - Priority    : an explicit number you assign via priorityClassName.
#
# Under node pressure the kubelet evicts by QoS first (BestEffort, then
# Burstable, then Guaranteed); the scheduler uses priority to decide which
# pending Pod to place first and which low-priority running Pods to PREEMPT
# (evict) to make room for a higher-priority pending Pod.
#
# Higher value = more important. Reserve very large numbers for system pods.
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass

metadata:
  name: high-priority

value: 1000000
globalDefault: false
description: "Critical workloads — scheduled first, preempt lower-priority Pods."
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass

metadata:
  name: low-priority

value: 1000
globalDefault: false
description: "Best-effort batch jobs — first to be preempted under pressure."
---
# A Pod that opts into a PriorityClass.
apiVersion: v1
kind: Pod

metadata:
  name: important-app
  namespace: resource-demo
  labels:
    app: important

spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: loadtest:v1
    ports:
    - containerPort: 8000
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "250m"
        memory: "256Mi"
```

### `k8s-11-resource-management/k8s/qos-besteffort.yaml`

```yaml
# QoS Class: BestEffort
# Rule: NO requests and NO limits on any container.
# Result: lowest priority, FIRST to be evicted when the node runs out
#         of resources. Fine for non-critical, interruptible workloads.
apiVersion: v1
kind: Pod

metadata:
  name: qos-besteffort
  labels:
    qos: besteffort

spec:
  containers:
  - name: app
    image: loadtest:v1
    ports:
    - containerPort: 8000
    # no resources block at all
```

### `k8s-11-resource-management/k8s/qos-burstable.yaml`

```yaml
# QoS Class: Burstable
# Rule: at least one container sets a request or limit, but it does NOT
#       meet the Guaranteed criteria (requests != limits, or only one is set).
# Result: medium priority. Can use spare node resources up to its limit,
#         evicted before Guaranteed but after BestEffort.
apiVersion: v1
kind: Pod

metadata:
  name: qos-burstable
  labels:
    qos: burstable

spec:
  containers:
  - name: app
    image: loadtest:v1
    ports:
    - containerPort: 8000
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

### `k8s-11-resource-management/k8s/qos-guaranteed.yaml`

```yaml
# QoS Class: Guaranteed
# Rule: every container sets requests AND limits, and requests == limits
#       for BOTH cpu and memory.
# Result: highest priority, last to be evicted under node pressure.
apiVersion: v1
kind: Pod

metadata:
  name: qos-guaranteed
  labels:
    qos: guaranteed

spec:
  containers:
  - name: app
    image: loadtest:v1
    ports:
    - containerPort: 8000
    resources:
      requests:
        cpu: "250m"
        memory: "256Mi"
      limits:
        cpu: "250m"
        memory: "256Mi"
```

### `k8s-11-resource-management/k8s/resourcequota.yaml`

```yaml
# ResourceQuota caps the TOTAL resources a whole namespace can consume.
# Once the sum of all Pod requests/limits hits these numbers, new Pods that
# would exceed the quota are rejected at creation time.
apiVersion: v1
kind: ResourceQuota

metadata:
  name: namespace-quota
  namespace: resource-demo

spec:
  hard:
    # total of all container requests in the namespace
    requests.cpu: "1"
    requests.memory: "1Gi"

    # total of all container limits in the namespace
    limits.cpu: "2"
    limits.memory: "2Gi"

    # total ephemeral (disk) requests across the namespace
    requests.ephemeral-storage: "2Gi"

    # max number of pods
    pods: "10"

# NOTE: once this quota exists, EVERY new Pod in the namespace must declare
# cpu/memory requests and limits. A BestEffort Pod (no requests/limits) will
# be REJECTED. Apply the QoS demos BEFORE this quota, or give BestEffort its
# own namespace.
```

### `k8s-11-resource-management/k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service

metadata:
  name: loadtest-service

spec:
  selector:
    app: loadtest

  ports:
  - port: 80
    targetPort: 8000

  type: ClusterIP
```

### `k8s-11-resource-management/test/smoke-test.sh`

```bash
#!/usr/bin/env bash
#
# Smoke test for Project 11 - Resource Management.
# Deploys the demos into the `resource-demo` namespace, verifies QoS classes,
# triggers a CPU burn and a memory OOMKill, then cleans up.
#
# Requires: kubectl pointed at a cluster, metrics-server installed,
#           and the image `loadtest:v1` available to the cluster.
#
# Usage:
#   ./test/smoke-test.sh          # run the checks
#   ./test/smoke-test.sh clean    # delete everything the test created
set -euo pipefail

NS=resource-demo
K8S_DIR="$(cd "$(dirname "$0")/../k8s" && pwd)"

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; exit 1; }
info() { printf "\n\033[1m%s\033[0m\n" "$1"; }

cleanup() {
  info "Cleaning up namespace $NS and cluster-scoped objects"
  kubectl delete namespace "$NS" --ignore-not-found
  kubectl delete priorityclass high-priority low-priority --ignore-not-found
  pass "cleaned up"
}

if [[ "${1:-}" == "clean" ]]; then
  cleanup
  exit 0
fi

info "1. Create namespace"
kubectl apply -f "$K8S_DIR/namespace.yaml"

info "2. Deploy QoS pods (BEFORE the quota, which would reject BestEffort)"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-guaranteed.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-burstable.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-besteffort.yaml"
kubectl wait --for=condition=Ready pod -l qos -n "$NS" --timeout=120s || true

info "3. Verify QoS classes"
for pair in "qos-guaranteed:Guaranteed" "qos-burstable:Burstable" "qos-besteffort:BestEffort"; do
  pod="${pair%%:*}"; want="${pair##*:}"
  got="$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.status.qosClass}')"
  [[ "$got" == "$want" ]] && pass "$pod -> $got" || fail "$pod expected $want, got $got"
done

info "4. Deploy the load-test app"
kubectl apply -n "$NS" -f "$K8S_DIR/deployment.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/service.yaml"
kubectl rollout status deploy/loadtest -n "$NS" --timeout=120s
pass "loadtest rollout complete"

info "5. Trigger an OOMKill (limit is 256Mi; allocate ~400Mi)"
pod="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$pod" -- sh -c \
  'curl -s "http://localhost:8000/eat-memory?mb=200" >/dev/null; curl -s "http://localhost:8000/eat-memory?mb=200" >/dev/null' || true
sleep 10
reason="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)"
restarts="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')"
if [[ "$reason" == "OOMKilled" || "${restarts:-0}" -gt 0 ]]; then
  pass "memory limit enforced (reason=${reason:-restart}, restarts=$restarts)"
else
  fail "expected an OOMKill/restart, saw none (reason='$reason', restarts=$restarts)"
fi

info "6. Apply LimitRange + ResourceQuota (namespace governance)"
kubectl apply -f "$K8S_DIR/limitrange.yaml"
kubectl apply -f "$K8S_DIR/resourcequota.yaml"
pass "limitrange and quota applied"

info "7. Confirm the quota now REJECTS a BestEffort pod"
if kubectl run quota-reject --image=loadtest:v1 -n "$NS" --restart=Never \
     --overrides='{"spec":{"containers":[{"name":"quota-reject","image":"loadtest:v1"}]}}' 2>/dev/null; then
  fail "BestEffort pod was admitted despite the quota"
else
  pass "BestEffort pod correctly rejected by the quota"
fi

info "All checks passed. Run './test/smoke-test.sh clean' to tear down."
```

### `k8s-11-resource-management/README.md`

```markdown
# Project 11 - Resource Management

## Project Name

```text
k8s-11-resource-management
```

---

# 🎯 Goal

Learn how to **control CPU and memory consumption** in Kubernetes using:

- **Requests** — what a container is guaranteed
- **Limits** — the hard ceiling a container cannot cross
- **QoS Classes** — how Kubernetes decides who gets evicted first

You'll deploy a small app that can deliberately burn CPU and eat memory, then
watch Kubernetes **throttle** and **OOMKill** it.

---

# 📚 What You'll Learn

By the end of this project, you'll understand:

- The difference between a **request** and a **limit**
- What happens when a container exceeds its CPU limit (throttling)
- What happens when a container exceeds its memory limit (OOMKilled)
- How the scheduler uses requests to place Pods
- The three **QoS classes**: Guaranteed, Burstable, BestEffort
- How **LimitRange** sets namespace defaults
- How **ResourceQuota** caps a whole namespace
- Why resource management is critical in production

---

# 🚨 The Problem

A Kubernetes node has a fixed amount of CPU and memory.

```text
Node: 4 CPU / 8Gi RAM
```

If Pods are deployed with **no limits**:

```text
Pod A  -> eats all the memory
Pod B  -> starves
Pod C  -> starves
Node   -> becomes unstable / crashes
```

One badly behaved Pod can take down everything else on the node.

We need a way to say:

```text
"This container may use at most X CPU and Y memory."
```

That's what **requests** and **limits** do.

---

# 💡 Requests vs Limits

```text
Request = reserved amount (scheduler guarantees this)
Limit   = maximum amount (hard ceiling)
```

| | CPU | Memory |
|---|---|---|
| Exceed the **limit** | Throttled (slowed down) | **OOMKilled** (Pod killed) |
| Used by scheduler? | Request only | Request only |

Key idea:

```text
CPU    is compressible    -> you get less, you don't die
Memory is incompressible  -> exceed it and you are killed
```

---

# 🏗 Project Structure

```text
k8s-11-resource-management/
├── app/
│   └── loadtest/
│       ├── Dockerfile
│       ├── main.py
│       └── requirements.txt
│
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── qos-guaranteed.yaml
│   ├── qos-burstable.yaml
│   ├── qos-besteffort.yaml
│   ├── limitrange.yaml
│   └── resourcequota.yaml
│
└── test/
```

---

# 📦 Step 1 - Enable Metrics

To see CPU/memory usage you need the **metrics-server**.

## Minikube

```bash
minikube addons enable metrics-server
```

## Kind / Docker Desktop

```bash
kubectl apply -f \
https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:

```bash
kubectl get deployment metrics-server -n kube-system
```

---

# 📦 Step 2 - Build the App

The app exposes endpoints that consume resources on demand:

```text
/burn-cpu?seconds=10   -> burns CPU
/eat-memory?mb=100     -> allocates memory
/release               -> frees memory
```

Build the image:

```bash
docker build -t loadtest:v1 ./app/loadtest
```

> **Minikube tip:** load the image into the cluster:
> ```bash
> minikube image load loadtest:v1
> ```

---

# 🚀 Step 3 - Deploy with Requests & Limits

Look at `k8s/deployment.yaml`:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
```

```text
100m  = 0.1 CPU core
256Mi = 256 mebibytes of RAM
```

Apply:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

Verify:

```bash
kubectl get pods
kubectl describe pod -l app=loadtest
```

In the describe output look for:

```text
Limits:
  cpu:     250m
  memory:  256Mi
Requests:
  cpu:     100m
  memory:  128Mi
QoS Class: Burstable
```

---

# 📊 Step 4 - Watch Resource Usage

Port-forward the service:

```bash
kubectl port-forward svc/loadtest-service 8080:80
```

In another terminal, watch live usage:

```bash
kubectl top pod -l app=loadtest
```

---

# 🔥 Step 5 - Trigger CPU Throttling

Hit the CPU burner:

```bash
curl "http://localhost:8080/burn-cpu?seconds=20"
```

While it runs, watch:

```bash
kubectl top pod -l app=loadtest
```

You'll see CPU pinned near the **limit** (250m) and never go past it.
The container is **throttled** — slowed down, but **not killed**.

---

# 💥 Step 6 - Trigger an OOMKill

Memory is different. Exceed the limit and the kernel kills the container.

Our limit is `256Mi`. Allocate more than that:

```bash
curl "http://localhost:8080/eat-memory?mb=200"
curl "http://localhost:8080/eat-memory?mb=200"
```

Now watch the Pod:

```bash
kubectl get pods -w
```

You'll see it restart with:

```text
STATUS: OOMKilled  ->  CrashLoopBackOff
```

Confirm the reason:

```bash
kubectl describe pod -l app=loadtest
```

Look for:

```text
Last State:  Terminated
  Reason:    OOMKilled
```

This is exactly why memory limits matter — one Pod can't eat the node.

---

# 🧠 Step 7 - QoS Classes

Kubernetes assigns every Pod a **Quality of Service** class.
Under node pressure, it evicts Pods **worst class first**.

```text
BestEffort   -> evicted FIRST   (no requests, no limits)
Burstable    -> evicted SECOND  (some requests/limits)
Guaranteed   -> evicted LAST    (requests == limits)
```

Deploy all three and compare:

```bash
kubectl apply -f k8s/qos-guaranteed.yaml
kubectl apply -f k8s/qos-burstable.yaml
kubectl apply -f k8s/qos-besteffort.yaml
```

Check the assigned class for each:

```bash
kubectl get pod qos-guaranteed -o jsonpath='{.status.qosClass}{"\n"}'
kubectl get pod qos-burstable  -o jsonpath='{.status.qosClass}{"\n"}'
kubectl get pod qos-besteffort -o jsonpath='{.status.qosClass}{"\n"}'
```

Expected:

```text
Guaranteed
Burstable
BestEffort
```

## How the class is decided

```text
Guaranteed  : every container has requests == limits (cpu AND memory)
Burstable   : has some requests/limits, but not Guaranteed
BestEffort  : no requests and no limits at all
```

---

# 🧱 Step 8 - LimitRange (Namespace Defaults)

What if a developer forgets to set limits? A **LimitRange** applies defaults
automatically and enforces min/max bounds.

```bash
kubectl apply -f k8s/limitrange.yaml
```

Now deploy a Pod with **no** resources — it inherits the defaults:

```bash
kubectl run nolimits --image=loadtest:v1
kubectl describe pod nolimits
```

You'll see the defaults from the LimitRange were injected.

---

# 🚧 Step 9 - ResourceQuota (Namespace Caps)

A **ResourceQuota** caps the total resources an entire namespace may use.

```bash
kubectl apply -f k8s/resourcequota.yaml
```

View it:

```bash
kubectl describe resourcequota namespace-quota
```

You'll see used vs hard limits:

```text
Resource         Used   Hard
requests.cpu     ...    1
requests.memory  ...    1Gi
pods             ...    10
```

Try to exceed it and Kubernetes **rejects** the new Pod.

---

# 🧪 Useful Commands

## Live resource usage

```bash
kubectl top pod
kubectl top node
```

## See limits/requests on a Pod

```bash
kubectl describe pod <pod-name>
```

## See QoS class

```bash
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'
```

## Watch for OOMKills / restarts

```bash
kubectl get pods -w
```

## View events

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

# 🆚 Request vs Limit (Cheat Sheet)

| Question | Request | Limit |
|----------|---------|-------|
| Used by the scheduler? | ✅ | ❌ |
| Guaranteed to the container? | ✅ | ❌ |
| Hard ceiling? | ❌ | ✅ |
| Exceed CPU → ? | n/a | Throttled |
| Exceed Memory → ? | n/a | OOMKilled |

---

# 🎓 What You've Learned

✅ The difference between requests and limits

✅ CPU is throttled, memory is OOMKilled

✅ How the scheduler uses requests to place Pods

✅ The three QoS classes and eviction order

✅ How LimitRange sets namespace defaults

✅ How ResourceQuota caps a namespace

✅ Why resource management protects the whole cluster

---

# 🧠 Final Mental Model

```text
Request = "Reserve me at least this much"
Limit   = "Never let me use more than this"

CPU over limit     -> slowed down (throttled)
Memory over limit  -> killed (OOMKilled)

QoS decides who dies first when the node is full:
BestEffort -> Burstable -> Guaranteed
```

Think of it as a shared apartment:

```text
Request  = the room that's reserved for you
Limit    = the loudest you're allowed to be
QoS      = who gets evicted first when the landlord runs out of space
```
```
