# Project 06 - Rolling Updates & Rollbacks

## 🎯 Objective
Deploy new versions of your app with **ZERO DOWNTIME** using rolling updates, and learn how to **rollback** quickly when things go wrong.

## 📋 Prerequisites
- Completed Projects 01–05
- `fastapi-demo:v1` Docker image built (from Project 02)
- Kubernetes cluster running
- kubectl installed

## 🎓 What You'll Learn
- 🔄 **Rolling Updates** — replace pods gradually, zero downtime
- ⏪ **Rollbacks** — revert to a previous version instantly
- 🎚️ **`maxSurge` & `maxUnavailable`** — fine-tune the rollout speed
- 📜 **Revision History** — Kubernetes tracks every deployment
- 🚨 **Recreate Strategy** — when zero downtime isn't possible
- 🛑 **Pause/Resume** — safe canary-style deployments
- 💥 **Failed Rollouts** — what happens when a new version is broken

## 📁 Project Structure
```
k8s-06-rolling-updates/
├── README.md
├── app/
│   └── main.py                   # FastAPI app (reads APP_VERSION from env)
├── k8s/
│   ├── deployment.yaml           # Initial deployment (v1, RollingUpdate)
│   ├── deployment-recreate.yaml  # Recreate strategy (for COMPARISON, has downtime)
│   ├── deployment-broken.yaml    # Intentionally broken (for rollback demo)
│   └── service.yaml              # ClusterIP service
└── test/
    ├── 01-initial-deploy.sh      # Deploy v1
    ├── 02-rolling-update.sh      # Update to v2 with zero downtime check
    ├── 03-rollback.sh            # Rollback to previous version
    ├── 04-recreate-strategy.sh   # Show downtime with Recreate
    ├── 05-failed-rollout.sh      # Apply broken image, then rollback
    └── README.md
```

---

## 🧠 Core Concepts

### 1. The Problem: Updating Apps in Production

You have a live app serving customers. You need to deploy a new version.

**Naive approach** (don't do this!):
```
Stop all pods → Deploy new version → Start pods
                      ↑
              💥 Downtime here!
```

**Kubernetes way** (Rolling Update):
```
Pod1(v1) Pod2(v1) Pod3(v1) Pod4(v1)
                ↓
Pod1(v2) Pod2(v1) Pod3(v1) Pod4(v1)   ← gradual replacement
                ↓
Pod1(v2) Pod2(v2) Pod3(v1) Pod4(v1)
                ↓
Pod1(v2) Pod2(v2) Pod3(v2) Pod4(v1)
                ↓
Pod1(v2) Pod2(v2) Pod3(v2) Pod4(v2)   ← done, ZERO downtime!
```

### 2. Deployment Strategies

| Strategy | How It Works | Downtime? | Use Case |
|----------|--------------|-----------|----------|
| **RollingUpdate** ⭐ | Gradual: old pods replaced one-by-one | ❌ None | Default, 99% of apps |
| **Recreate** | Kill ALL old pods, then create new ones | ✅ Yes | Apps that can't run two versions (DB migrations, singletons) |
| **Blue/Green** | Deploy v2 alongside v1, switch traffic | ❌ None | Easy rollback, requires 2× resources |
| **Canary** | Send 5% traffic to v2, gradually increase | ❌ None | Risk-averse, A/B testing (Project 10) |

### 3. The Two Magic Knobs: maxSurge & maxUnavailable

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # How many EXTRA pods during update?
    maxUnavailable: 0  # How many pods can be DOWN during update?
```

#### Example: 4 replicas

| maxSurge | maxUnavailable | Behavior |
|----------|----------------|----------|
| **1, 0** ⭐ | Strictest. 4-5 pods exist, all 4 must be ready. ZERO downtime. |
| **25%, 25%** | Default. Allows 3-5 pods, 3 must be ready. Brief degradation OK. |
| **0, 1** | Conservative. 4 pods max, 3 ready at minimum. |
| **100%, 100%** | Fastest. Replace all at once (basically Recreate). |

```
maxSurge=1, maxUnavailable=0  (our choice ⭐)
─────────────────────────────────────────────
Start:  [v1][v1][v1][v1]                  Ready: 4/4
Step1:  [v1][v1][v1][v1][v2-pending]      Ready: 4/4 (5 exist)
Step2:  [v2][v1][v1][v1]                  Ready: 4/4 (v2 ready, kill 1 v1)
Step3:  [v2][v1][v1][v1][v2-pending]      Ready: 4/4
Step4:  [v2][v2][v1][v1]                  Ready: 4/4
... and so on
End:    [v2][v2][v2][v2]                  Ready: 4/4 ✅
```

### 4. Revision History

Kubernetes keeps a history of every deployment so you can rollback.

```bash
kubectl rollout history deployment/rolling-app
```

Output:
```
REVISION  CHANGE-CAUSE
1         Initial deployment v1.0.0
2         Update to v2.0.0
3         Hotfix for login bug
4         BROKEN release v9.9.9 (image doesn't exist!)
```

**Behind the scenes:** Each revision = one ReplicaSet (kept around for rollback).

### 5. Rollback Magic ⏪

```bash
# Rollback to PREVIOUS version (most common)
kubectl rollout undo deployment/rolling-app

# Rollback to a SPECIFIC revision
kubectl rollout undo deployment/rolling-app --to-revision=2
```

Rollback is itself a rolling update! Same `maxSurge`/`maxUnavailable` rules apply.

### 6. Readiness Probes = Zero Downtime Glue 🔗

Without readiness probes, K8s thinks a pod is ready as soon as it starts.
With readiness probes, K8s waits until the pod can ACTUALLY serve traffic.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 2
  periodSeconds: 5
```

**During rolling update:**
- ✅ New pod starts → readiness probe fails → NOT added to Service
- ✅ New pod ready → readiness probe passes → added to Service
- ✅ Old pod removed → Service stops sending traffic FIRST → then terminated

This is the magic that prevents users from hitting half-loaded pods!

---

## 🚀 Steps to Complete

### Step 1: Deploy v1 (Initial Version)

```bash
cd k8s-06-rolling-updates

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Verify
kubectl get deployment rolling-app
kubectl get pods -l app=rolling-app
```

### Step 2: Check Initial Revision History

```bash
kubectl rollout history deployment/rolling-app
```

You should see Revision 1 with our annotation.

### Step 3: Perform a Rolling Update (v1 → v2)

You can update in 3 ways:

**Option A — `kubectl set image` (quick, imperative):**
```bash
kubectl set image deployment/rolling-app fastapi=fastapi-demo:v2 \
  --record=true
```

**Option B — `kubectl edit` (interactive):**
```bash
kubectl edit deployment/rolling-app
# Change image: fastapi-demo:v1 → fastapi-demo:v2
```

**Option C — `kubectl apply` (declarative, recommended!):**
```bash
# Edit k8s/deployment.yaml, change image: fastapi-demo:v2
kubectl apply -f k8s/deployment.yaml
```

### Step 4: Watch the Rolling Update Live

```bash
# In one terminal - watch the rollout status
kubectl rollout status deployment/rolling-app

# In another terminal - watch pods change
kubectl get pods -l app=rolling-app -w

# Verify zero downtime with continuous requests
kubectl run client --image=curlimages/curl --restart=Never -- sleep 3600
while true; do
  kubectl exec client -- curl -s http://rolling-service:8000/version
  sleep 0.5
done
```

You'll see responses transition from `v1.0.0` → mix of `v1.0.0` and `v2.0.0` → all `v2.0.0` without any failures!

### Step 5: Check the New Revision History

```bash
kubectl rollout history deployment/rolling-app
```

Should now show Revision 1 (v1) and Revision 2 (v2).

### Step 6: Rollback to Previous Version (⏪)

```bash
# Quick rollback to previous revision
kubectl rollout undo deployment/rolling-app

# Watch it rollback
kubectl rollout status deployment/rolling-app

# Verify version
kubectl exec client -- curl -s http://rolling-service:8000/version
```

### Step 7: Try the Recreate Strategy (See the Downtime!)

```bash
# Deploy the recreate version
kubectl apply -f k8s/deployment-recreate.yaml
kubectl wait --for=condition=Available deployment/recreate-app --timeout=60s

# Now trigger an update — watch the downtime!
kubectl set image deployment/recreate-app fastapi=fastapi-demo:v2

# In another terminal, see ALL pods terminate before NEW ones appear
kubectl get pods -l app=recreate-app -w
```

### Step 8: Simulate a Failed Rollout & Rollback

```bash
# Apply the BROKEN deployment (image doesn't exist!)
kubectl apply -f k8s/deployment-broken.yaml

# Watch it fail
kubectl get pods -l app=rolling-app -w
# You'll see new pods stuck in ImagePullBackOff

# Check rollout status (it won't complete)
kubectl rollout status deployment/rolling-app --timeout=30s
# Output: timed out waiting for the condition

# Save the day - rollback!
kubectl rollout undo deployment/rolling-app

# Verify everything is healthy again
kubectl rollout status deployment/rolling-app
```

### Step 9: Pause & Resume Rollouts (Advanced)

You can pause a rollout mid-flight to do canary testing:

```bash
# Start a rollout
kubectl set image deployment/rolling-app fastapi=fastapi-demo:v2

# IMMEDIATELY pause it (only a few pods will be updated)
kubectl rollout pause deployment/rolling-app

# Inspect the few new pods, test them...
# If happy: resume
kubectl rollout resume deployment/rolling-app

# If unhappy: rollback
kubectl rollout undo deployment/rolling-app
```

---

## 🔍 Key Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl rollout status deploy/X` | Watch a rollout finish |
| `kubectl rollout history deploy/X` | List all revisions |
| `kubectl rollout history deploy/X --revision=2` | Inspect a specific revision |
| `kubectl rollout undo deploy/X` | Rollback to previous version |
| `kubectl rollout undo deploy/X --to-revision=N` | Rollback to specific revision |
| `kubectl rollout pause deploy/X` | Pause a rollout |
| `kubectl rollout resume deploy/X` | Resume a paused rollout |
| `kubectl rollout restart deploy/X` | Restart all pods (rolling) |
| `kubectl set image deploy/X container=image:tag` | Update image |
| `kubectl annotate deploy/X kubernetes.io/change-cause="..."` | Set change-cause |

---

## 💡 Key Insights

### 1. Rolling Update = Default
You don't have to configure anything to get rolling updates. They're the default behavior of Deployments. (Project 04 already used them silently!)

### 2. `kubectl rollout restart` = Magic Trick
Need to restart pods (e.g., after a ConfigMap change)? Don't delete pods!
```bash
kubectl rollout restart deployment/X
```
This triggers a rolling restart — zero downtime.

### 3. Readiness Probes are CRITICAL
Without them, your "zero-downtime" update will serve errors during transitions. Always define them.

### 4. `--record` is Deprecated, Use Annotations
The old `--record=true` flag is deprecated. Use annotations:
```bash
kubectl annotate deployment/X kubernetes.io/change-cause="My change"
```

### 5. Rollback is FAST
Because Kubernetes keeps old ReplicaSets, rollback is just "scale up old RS, scale down new RS". Takes seconds!

### 6. Rolling Updates Need Backward Compatibility
During a rolling update, **v1 and v2 pods run SIMULTANEOUSLY**. Make sure:
- ✅ Database schemas are backward compatible
- ✅ APIs support both old and new clients
- ✅ Shared state (cache, queues) works for both

### 7. Watch Out for Long-Lived Connections
WebSockets, gRPC streams, long polling — these don't gracefully transition. Consider `terminationGracePeriodSeconds` and connection draining.

---

## 🎯 Concepts Covered

✅ **Rolling Updates** — gradual, zero-downtime deployments  
✅ **Recreate Strategy** — when downtime is required  
✅ **maxSurge / maxUnavailable** — fine-tune the rollout  
✅ **Revision History** — Kubernetes tracks all changes  
✅ **Rollbacks** — instant revert to previous versions  
✅ **Failed Rollouts** — what happens & how to recover  
✅ **Pause/Resume** — canary-style deployments  
✅ **Readiness Probes** — the zero-downtime glue  

---

## 🧹 Cleanup

```bash
kubectl delete -f k8s/
kubectl delete pod client --ignore-not-found=true
```

---

## 📚 Next Project

**[Project 07 - ConfigMaps & Secrets](../k8s-07-configmaps-secrets/)** — Manage application configuration securely.
