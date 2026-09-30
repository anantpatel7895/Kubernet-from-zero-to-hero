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
