# Project 04 - Self Healing Applications

## 🎯 Objective
Understand how Kubernetes automatically recovers failed workloads through **ReplicaSets**, **Desired State Reconciliation**, and **Pod Recovery**.

## 📋 Prerequisites
- Completed Project 01, 02 & 03
- FastAPI Docker image built (`fastapi-demo:v1`)
- Kubernetes cluster running
- kubectl installed

## 🎓 What You'll Learn
- **ReplicaSets**: The "muscle" behind Deployments that maintains pod count
- **Desired State**: How Kubernetes compares actual vs desired state
- **Pod Recovery**: Different recovery scenarios (deletion, crashes, node failure)
- **Restart Policies**: Always, OnFailure, Never
- **Reconciliation Loop**: The heartbeat of Kubernetes self-healing

## 📁 Project Structure
```
k8s-04-self-healing/
├── README.md
├── k8s/
│   ├── deployment.yaml              # Self-healing deployment (3 replicas)
│   ├── service.yaml                 # Service to expose deployment
│   ├── replicaset-standalone.yaml   # Standalone ReplicaSet (educational)
│   └── crashing-pod.yaml            # Pod that crashes to demo restart
└── test/
    ├── test-pod-deletion.sh         # Delete pods, watch recreation
    ├── test-crash-recovery.sh       # Watch container restart
    ├── test-replicaset-scaling.sh   # ReplicaSet maintains count
    ├── test-zero-downtime.sh        # Traffic continues during failures
    └── run-all-tests.sh             # Run all tests
```

---

## 🧠 Core Concepts

### 1. The Self-Healing Philosophy

Kubernetes follows a simple but powerful principle:

> **"Tell me WHAT you want, not HOW to do it."**

You declare your **desired state** (e.g., "I want 3 pods running"), and Kubernetes works continuously to make the **actual state** match.

```
┌──────────────────────────────────────────────────┐
│           KUBERNETES CONTROL PLANE               │
│                                                  │
│   ┌─────────────────┐      ┌────────────────┐    │
│   │  Desired State  │      │  Actual State  │    │
│   │  (Your YAML)    │      │  (Reality)     │    │
│   │                 │      │                │    │
│   │  replicas: 3    │      │  pods: 2 ❌    │    │
│   └────────┬────────┘      └───────┬────────┘    │
│            │                       │             │
│            └───────────┬───────────┘             │
│                        ▼                         │
│            ┌──────────────────────┐              │
│            │  Controller Manager  │              │
│            │  "Difference: -1"    │              │
│            │  "Action: Create 1"  │              │
│            └──────────────────────┘              │
│                        │                         │
│                        ▼                         │
│                  Creates Pod ✅                  │
└──────────────────────────────────────────────────┘
```

### 2. The Hierarchy: Deployment → ReplicaSet → Pod

```
┌──────────────────────────────────────┐
│         Deployment                   │  ← You manage this
│  (Manages rollouts, versions)        │
└─────────────────┬────────────────────┘
                  │ creates & manages
                  ▼
┌──────────────────────────────────────┐
│         ReplicaSet                   │  ← Created automatically
│  (Maintains desired pod count)       │
└─────────────────┬────────────────────┘
                  │ creates & manages
                  ▼
┌──────────────────────────────────────┐
│    Pod 1    Pod 2    Pod 3           │  ← The actual workloads
└──────────────────────────────────────┘
```

**Who does what?**

| Component | Responsibility |
|-----------|----------------|
| **Deployment** | Rolling updates, rollbacks, version history |
| **ReplicaSet** | Maintains the exact number of pod replicas |
| **Pod** | Runs your container(s) |

### 3. The Reconciliation Loop

This is the **heart of Kubernetes** self-healing. It runs continuously:

```
T+0s   You typed: kubectl delete pod self-healing-app-58f67b6848-252fd
       │
T+0s   ┌─────────────────────────────────────────┐
       │ API Server: "Pod 252fd marked for       │
       │             deletion"                    │
       └─────────────────────────────────────────┘
       │
T+1s   ┌─────────────────────────────────────────┐
       │ ReplicaSet Controller wakes up:         │
       │  - Desired: 3 pods                       │
       │  - Actual:  2 pods (252fd gone)          │
       │  - Difference: -1                        │
       │  - Decision: CREATE 1 pod                │
       └─────────────────────────────────────────┘
       │
T+2s   ┌─────────────────────────────────────────┐
       │ Scheduler: "Assign new pod to node"     │
       └─────────────────────────────────────────┘
       │
T+3s   ┌─────────────────────────────────────────┐
       │ Kubelet on node: "Start container"      │
       └─────────────────────────────────────────┘
       │
T+9s   ┌─────────────────────────────────────────┐
       │ Pod fjd7t: Running ✅                    │
       │ Desired = Actual = 3                     │
       └─────────────────────────────────────────┘
```

### 4. Self-Healing Scenarios

Kubernetes handles many failure scenarios automatically:

| Scenario | What Kubernetes Does |
|----------|----------------------|
| 🗑️ Pod deleted | ReplicaSet creates a new one |
| 💥 Container crashes | Kubelet restarts the container |
| 🔥 Node fails | Pods rescheduled to healthy nodes |
| 🐢 Pod becomes unresponsive | Liveness probe triggers restart |
| 📈 Need more capacity | HPA scales up replicas (Project 05) |

### 5. Restart Policies

Configure how containers behave on failure:

```yaml
spec:
  restartPolicy: Always      # Default - always restart
  # restartPolicy: OnFailure # Only on non-zero exit
  # restartPolicy: Never     # Never restart
```

| Policy | Use Case |
|--------|----------|
| `Always` | Long-running apps (web servers, APIs) - **default** |
| `OnFailure` | Batch jobs that should retry on error |
| `Never` | One-shot tasks where failure is acceptable |

---

## 🚀 Steps to Complete

### Step 1: Deploy the Self-Healing Application

```bash
cd k8s-04-self-healing

# Apply the deployment
kubectl apply -f k8s/deployment.yaml

# Apply the service
kubectl apply -f k8s/service.yaml

# Verify everything is running
kubectl get deployment self-healing-app
kubectl get replicaset -l app=self-healing
kubectl get pods -l app=self-healing
```

**Expected output:**
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
self-healing-app   3/3     3            3           30s
```

### Step 2: Observe the Hierarchy

```bash
# See the Deployment
kubectl get deployment self-healing-app

# See the ReplicaSet created BY the Deployment
kubectl get rs -l app=self-healing

# See the Pods created BY the ReplicaSet
kubectl get pods -l app=self-healing -o wide
```

Notice how:
- **1 Deployment** created **1 ReplicaSet**
- **1 ReplicaSet** created **3 Pods**
- Pod names follow pattern: `<deployment>-<replicaset-hash>-<pod-id>`

> Learned Points:
> - Pods are created and managed by ReplicaSets
> - ReplicaSets are created and managed by Deployments
> - pod name and container name are not the same

### Step 3: Test Self-Healing - Delete a Pod

```bash
# Get a pod name
POD=$(kubectl get pods -l app=self-healing -o jsonpath='{.items[0].metadata.name}')
echo "Deleting pod: $POD"

# Open a watch in another terminal first:
# kubectl get pods -l app=self-healing -w

# Delete the pod
kubectl delete pod $POD

# Watch the magic happen
kubectl get pods -l app=self-healing
```

**What happens:**
1. ⏱️ T+0s: You delete the pod
2. 🔍 T+1s: ReplicaSet controller detects only 2/3 pods
3. ⚡ T+2s: ReplicaSet creates a new pod
4. ✅ T+10s: New pod is Running with a different name & IP

### Step 4: Test Container Crash Recovery

```bash
# Deploy the crashing pod
kubectl apply -f k8s/crashing-pod.yaml

# Watch it crash and restart (CrashLoopBackOff)
kubectl get pod crashing-pod -w

# In another terminal, check restart count
kubectl get pod crashing-pod
# Watch RESTARTS column increase: 0 → 1 → 2 → 3...

# See the logs from previous crashed container
kubectl logs crashing-pod --previous

# Check events
kubectl describe pod crashing-pod
```

**Notice:**
- Container exits with code 1
- Kubernetes **restarts** the container (not recreates the pod)
- Backoff time increases: 10s, 20s, 40s, 80s, ... (max 5 min)
- Status becomes `CrashLoopBackOff`

### Step 5: Test ReplicaSet Directly

```bash
# Apply standalone ReplicaSet
kubectl apply -f k8s/replicaset-standalone.yaml

# See it create 3 pods
kubectl get rs standalone-replicaset
kubectl get pods -l app=replicaset-demo

# Try deleting the ReplicaSet (pods deleted too)
kubectl delete rs standalone-replicaset
```

### Step 6: Test Desired State Enforcement

```bash
# Try to manually scale via the ReplicaSet
RS_NAME=$(kubectl get rs -l app=self-healing -o jsonpath='{.items[0].metadata.name}')

# Scale the ReplicaSet to 5
kubectl scale rs $RS_NAME --replicas=5

# Check pods - you now have 5
kubectl get pods -l app=self-healing

# But the DEPLOYMENT still wants 3!
# Kubernetes will eventually scale back down... or will it?
# Actually no - because we scaled the RS, the Deployment doesn't know.
# Always scale via Deployment, not ReplicaSet!

# Correct way:
kubectl scale deployment self-healing-app --replicas=5
kubectl scale deployment self-healing-app --replicas=3
```

### Step 7: Zero-Downtime Test

```bash
# Terminal 1: Continuously curl the service
kubectl port-forward service/self-healing-service 8080:8000 &
while true; do
  curl -s http://localhost:8080/ | jq -r '.hostname' 2>/dev/null || echo "Failed"
  sleep 1
done

# Terminal 2: Delete pods one by one
kubectl delete pod -l app=self-healing --wait=false
```

**Observation:** Despite pods being deleted, the service keeps responding because:
- Multiple replicas exist
- Service load balances to healthy pods
- ReplicaSet recreates deleted pods

---

## 🧪 Running the Tests

```bash
# Make scripts executable
chmod +x test/*.sh

# Run individual tests
./test/test-pod-deletion.sh
./test/test-crash-recovery.sh
./test/test-replicaset-scaling.sh
./test/test-zero-downtime.sh

# Or run all tests
./test/run-all-tests.sh
```

---

## 🔍 Key Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl get rs` | List ReplicaSets |
| `kubectl describe rs <name>` | See ReplicaSet details & events |
| `kubectl get pods -w` | Watch pods in real-time |
| `kubectl delete pod <name>` | Delete a pod (triggers recreation) |
| `kubectl scale deployment <name> --replicas=N` | Change desired replicas |
| `kubectl logs <pod> --previous` | See logs from crashed container |
| `kubectl get events --sort-by='.lastTimestamp'` | See recent cluster events |

---

## 💡 Key Insights

### 1. Pods are Cattle, Not Pets 🐄
- Don't get attached to pod names or IPs
- They're meant to be replaced
- Treat them as disposable, replaceable units

### 2. ReplicaSet vs Deployment
- **Always use Deployments** in production
- ReplicaSets handle replication
- Deployments handle replication **+** rolling updates **+** rollbacks
- Deployments create and manage ReplicaSets for you

### 3. The Magic of Reconciliation
- No human intervention needed for failures
- Kubernetes continuously watches and acts
- Self-healing is a **side effect** of declarative configuration

### 4. Limits of Self-Healing
Kubernetes CAN'T fix:
- ❌ Bugs in your application code
- ❌ Misconfigured environment variables
- ❌ Wrong container images
- ❌ Resource exhaustion (without HPA)
- ❌ Network issues outside the cluster

---

## 🎯 Concepts Covered

✅ **Self Healing** - Automatic recovery from failures  
✅ **Orchestration** - Coordinated management of multiple pods  
✅ **ReplicaSets** - The replication primitive  
✅ **Desired State** - Declarative configuration model  
✅ **Reconciliation** - The heartbeat of Kubernetes

---

## 🧹 Cleanup

```bash
# Delete everything created in this project
kubectl delete -f k8s/

# Or delete by labels
kubectl delete all -l project=k8s-04
kubectl delete pod crashing-pod
```

---

## 📚 Next Project

**[Project 05 - Horizontal Scaling](../k8s-05-scaling/)** - Learn to scale apps manually and automatically with HPA.
