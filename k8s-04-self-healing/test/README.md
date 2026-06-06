# Project 04 - Test Suite

Test scripts to verify Kubernetes self-healing capabilities.

## 📜 Available Tests

| Script | What It Tests | Duration |
|--------|---------------|----------|
| `test-pod-deletion.sh` | Pod recreation after deletion | ~30s |
| `test-crash-recovery.sh` | Container restart on crash | ~60s |
| `test-replicaset-scaling.sh` | Desired state enforcement | ~30s |
| `test-zero-downtime.sh` | Service availability during failures | ~30s |
| `run-all-tests.sh` | All tests sequentially | ~3 min |

## 🚀 Quick Start

```bash
# Make scripts executable
chmod +x test/*.sh

# Run all tests
./test/run-all-tests.sh

# Or run individually
./test/test-pod-deletion.sh
./test/test-crash-recovery.sh
./test/test-replicaset-scaling.sh
./test/test-zero-downtime.sh
```

## ✅ What Each Test Proves

### test-pod-deletion.sh
**Proves:** ReplicaSet enforces desired state by recreating deleted pods.

```
Before: 3 pods (A, B, C)
Action: Delete pod A
After:  3 pods (B, C, D)  ← new pod D created automatically
```

### test-crash-recovery.sh
**Proves:** Kubelet restarts crashed containers within the same pod.

```
Container exits with code 1
  ↓
Kubelet restarts container (same pod)
  ↓
Restart count: 1, 2, 3, 4...
  ↓
After many crashes: CrashLoopBackOff
```

### test-replicaset-scaling.sh
**Proves:** Changing desired state triggers immediate reconciliation.

```
Scale to 5 → ReplicaSet creates 2 new pods
Scale to 2 → ReplicaSet deletes 3 pods
Scale to 3 → Back to original
```

### test-zero-downtime.sh
**Proves:** Service continues serving while pods are recreated.

```
30 requests + delete 2 pods during test
  ↓
Most requests succeed (load balanced to healthy pods)
  ↓
Brief failures possible (acceptable for HA setups)
```

## 🧹 Cleanup

```bash
kubectl delete pod crashing-pod --ignore-not-found=true
kubectl delete -f k8s/
```
