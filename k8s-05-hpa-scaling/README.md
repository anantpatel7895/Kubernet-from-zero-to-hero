# Project 05 - Horizontal Scaling

## 🎯 Objective
Learn how Kubernetes scales applications **manually** and **automatically** based on resource usage using the **Horizontal Pod Autoscaler (HPA)** and **Metrics Server**.

## 📋 Prerequisites
- Completed Project 01–04
- FastAPI Docker image built (`fastapi-demo:v1`)
- Kubernetes cluster running (Docker Desktop / Minikube / Kind)
- kubectl installed
- **Metrics Server** installed (we'll install it together)

## 🎓 What You'll Learn
- 📏 **Manual Scaling** — `kubectl scale` and updating YAML
- 📊 **Metrics Server** — how K8s sees pod CPU/memory usage
- 🤖 **HPA (Horizontal Pod Autoscaler)** — automatic scaling based on metrics
- ⚖️ **Resource Requests** — why they're MANDATORY for HPA
- 🔄 **The HPA Reconciliation Loop** — how K8s decides to scale up/down
- 🎚️ **Scale Behavior** — controlling how fast it scales

## 📁 Project Structure
```
k8s-05-scaling/
├── README.md
├── k8s/
│   ├── deployment.yaml       # App with resource requests (REQUIRED for HPA)
│   ├── service.yaml          # ClusterIP service
│   ├── hpa.yaml              # HorizontalPodAutoscaler config
│   └── load-generator.yaml   # Pod that generates load to trigger scaling
└── test/
    ├── 01-manual-scaling.sh       # Manual scale up/down
    ├── 02-install-metrics.sh      # Install metrics-server
    ├── 03-watch-hpa.sh            # Watch HPA in action
    ├── 04-trigger-scaling.sh      # Generate load & watch scaling
    ├── 05-cleanup.sh              # Clean up everything
    └── README.md
```

---

## 🧠 Core Concepts

### 1. Two Types of Scaling

| Type | What | When |
|------|------|------|
| **Vertical** (VPA) | Give pods MORE CPU/memory | Single-pod limits hit |
| **Horizontal** (HPA) ⭐ | Add MORE pods | High load, distributed apps |

We focus on **Horizontal** scaling here — adding more pod replicas to handle more traffic.

### 2. Manual Scaling (3 ways)

```bash
# Method 1: imperative (quick)
kubectl scale deployment scaling-app --replicas=5

# Method 2: edit live
kubectl edit deployment scaling-app

# Method 3: declarative (production!)
# Update replicas in deployment.yaml, then:
kubectl apply -f k8s/deployment.yaml
```

### 3. The Problem With Manual Scaling

```
Monday  9am:    Traffic: 100 req/s → You set replicas=2 ✅
Tuesday 1pm:    Traffic: 5000 req/s → 💥 App crashes (you're at lunch)
Wednesday 3am:  Traffic: 10 req/s   → 💸 You're paying for 10 pods
```

**Solution:** Let Kubernetes scale automatically based on actual load!

### 4. Metrics Server

Before HPA can autoscale, K8s needs to **measure** pod CPU/memory usage.

```
    Pods
     ↓ (every 15s)
  Kubelet (on each node) collects metrics
     ↓
  Metrics Server (cluster-wide aggregator)
     ↓
  kubectl top  /  HPA  reads metrics
```

**Without Metrics Server:**
- `kubectl top pods` → ❌ Error
- HPA → ❌ "unknown metrics"

### 5. The Horizontal Pod Autoscaler (HPA)

HPA continuously monitors pods and **adjusts replicas** to keep metrics near target.

```
   ┌─────────────────────────────────────┐
   │  Every 15 seconds:                  │
   │                                     │
   │  1. Get current CPU usage           │
   │  2. Calculate desired replicas      │
   │  3. Scale Deployment up/down        │
   │                                     │
   └─────────────────────────────────────┘
```

**The Formula:**
```
desiredReplicas = ceil(currentReplicas × (currentMetric / targetMetric))
```

**Example:** 2 pods at 90% CPU, target 50%
```
desired = ceil(2 × (90 / 50))
        = ceil(2 × 1.8)
        = ceil(3.6)
        = 4 pods
```

K8s scales UP from 2 → 4 pods.

### 6. Why Resource Requests Are Mandatory

HPA needs a **baseline** to calculate percentages.

```yaml
resources:
  requests:
    cpu: "100m"   # This = "100%" for HPA
```

#### how to calculate CPU utilization:

```
CPU Utilization = (actual / requested) × 100
                = (4m / 100m) × 100
                = 4%
```

If a pod uses 50m, HPA sees **50% utilization**.  
Without `requests.cpu`, HPA has nothing to compare against → ❌ doesn't work.

### 7. HPA Behavior (Anti-Flapping)

Without controls, HPA might:
- Scale up to 10 pods at noon
- Scale down to 2 pods at 12:01
- Scale up to 10 pods at 12:02 (😵 flapping!)

So HPA has `behavior` settings:
- **scaleUp.stabilizationWindowSeconds**: 0 (scale up fast!)
- **scaleDown.stabilizationWindowSeconds**: 60-300 (scale down slowly)

---

## 🚀 Steps to Complete

### Step 1: Deploy the App and Service

```bash
cd k8s-05-scaling

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Verify
kubectl get deployment scaling-app
kubectl get pods -l app=scaling-app
```

Expected:
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
scaling-app   2/2     2            2           30s
```

### Step 2: Try Manual Scaling

```bash
# Scale up to 5
kubectl scale deployment scaling-app --replicas=5
kubectl get pods -l app=scaling-app

# Scale down to 1
kubectl scale deployment scaling-app --replicas=1
kubectl get pods -l app=scaling-app

# Back to 2
kubectl scale deployment scaling-app --replicas=2
```

### Step 3: Install Metrics Server

On Docker Desktop / Minikube, Metrics Server is NOT installed by default.

```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For Docker Desktop, may need to patch (TLS workaround)
kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait for it to be ready
kubectl wait --for=condition=Available --timeout=60s -n kube-system deployment/metrics-server

# Verify it works
kubectl top nodes
kubectl top pods
```

### Step 4: Apply the HPA

```bash
kubectl apply -f k8s/hpa.yaml

# Check HPA status
kubectl get hpa
kubectl describe hpa scaling-app-hpa
```

You should see:
```
NAME              REFERENCE                TARGETS      MINPODS   MAXPODS   REPLICAS   AGE
scaling-app-hpa   Deployment/scaling-app   1%/50%       2         10        2          30s
```

The `TARGETS` column shows `current/target` CPU usage.

### Step 5: Trigger Auto-Scaling with Load

```bash
# Deploy the load generator
kubectl apply -f k8s/load-generator.yaml

# Watch HPA in real time (in another terminal)
kubectl get hpa scaling-app-hpa -w

# Watch pods being created (in another terminal)
kubectl get pods -l app=scaling-app -w
```

You'll see:
1. **T+0s:** CPU usage spikes (load generator is hammering)
2. **T+15s:** HPA notices: CPU 90% > target 50%
3. **T+30s:** HPA scales up: 2 → 4 pods
4. **T+45s:** Still hot, scales up: 4 → 8 pods
5. **T+60s:** Load distributed, stabilizes

### Step 6: Watch Scale Down

```bash
# Delete the load generator
kubectl delete pod load-generator

# Watch HPA scale DOWN (this takes ~60s due to stabilization window)
kubectl get hpa scaling-app-hpa -w
```

Notice the **slow scale-down** — that's the `stabilizationWindowSeconds: 60` working.

### Step 7: Cleanup

```bash
kubectl delete -f k8s/
```

---

## 🔍 Key Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl scale deploy/X --replicas=N` | Manual scaling |
| `kubectl top nodes` | Node CPU/memory usage |
| `kubectl top pods` | Pod CPU/memory usage |
| `kubectl get hpa` | List HPAs |
| `kubectl describe hpa <name>` | HPA details & events |
| `kubectl autoscale deploy X --min=2 --max=10 --cpu-percent=50` | Create HPA imperatively |

---

## 💡 Key Insights

### 1. HPA is Reactive, Not Predictive
- It scales **AFTER** seeing high load
- There's always a ~30-60s lag
- For predictable spikes (Black Friday), pre-scale manually!

### 2. Resource Requests = HPA's Foundation
```
No requests.cpu → No HPA
Wrong requests → Wrong scaling decisions
```

### 3. Scale Up Fast, Scale Down Slow
- **Up:** Users are waiting! Scale fast.
- **Down:** What if load returns? Wait a bit.

### 4. HPA vs Cluster Autoscaler
- **HPA**: Adds PODS (within existing nodes)
- **Cluster Autoscaler**: Adds NODES (when pods can't fit)

Both work together in production.

### 5. Tune Your Targets
- **Target too low (e.g., 20%)**: Over-scales (waste $$$)
- **Target too high (e.g., 90%)**: Under-scales (slow responses)
- **Sweet spot**: 50-70% for most apps

---

## 🎯 Concepts Covered

✅ **Manual Scaling** — `kubectl scale`, edit, apply  
✅ **Metrics Server** — measuring pod resource usage  
✅ **HPA** — automatic scaling based on CPU  
✅ **Resource Requests** — the HPA contract  
✅ **Scaling Formula** — how K8s calculates replicas  
✅ **Scale Behavior** — anti-flapping controls  

---

## 🧹 Cleanup

```bash
kubectl delete -f k8s/
# Optional: remove metrics-server
# kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 📚 Next Project

**[Project 06 - Rolling Updates & Rollbacks](../k8s-06-rolling-updates/)** — Deploy new versions with zero downtime.
