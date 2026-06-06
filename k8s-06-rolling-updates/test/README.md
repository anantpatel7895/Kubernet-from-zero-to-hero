# Project 06 — Test Suite

Test scripts that walk through every rolling update scenario, in order.

## 📜 Available Tests

| # | Script | What It Demonstrates | Duration |
|---|--------|----------------------|----------|
| 1 | `01-initial-deploy.sh` | Deploy v1 baseline | ~15s |
| 2 | `02-rolling-update.sh` | Zero-downtime update v1→v2 | ~90s |
| 3 | `03-rollback.sh` | Rollback to previous revision | ~30s |
| 4 | `04-recreate-strategy.sh` | Recreate strategy = DOWNTIME | ~60s |
| 5 | `05-failed-rollout.sh` | Broken image + rollback recovery | ~90s |

## 🚀 Quick Start

```bash
# Make scripts executable
chmod +x test/*.sh

# Run in order
./test/01-initial-deploy.sh
./test/02-rolling-update.sh
./test/03-rollback.sh
./test/04-recreate-strategy.sh
./test/05-failed-rollout.sh
```

## ✅ What Each Test Proves

### 01-initial-deploy.sh
Establishes our v1 baseline:
- 4 pods running v1.0.0
- Service routing to them
- Initial revision history (Revision 1)

### 02-rolling-update.sh — ZERO DOWNTIME ⭐
Triggers v1 → v2 update while sending continuous requests:
- Pods replaced one-by-one (maxSurge=1, maxUnavailable=0)
- Mid-update: responses show MIX of v1 and v2
- After update: ALL responses are v2
- **0 failed requests** = zero downtime achieved!

### 03-rollback.sh — Time Travel ⏪
Reverts to previous revision in seconds:
- New ReplicaSet created from old template
- Rolling update applied in reverse
- Revision number increments (rollback = new revision)

### 04-recreate-strategy.sh — Why You Need RollingUpdate 🚨
Shows what happens with `strategy: Recreate`:
- ALL pods terminated at once
- New pods created from scratch
- **DOWNTIME WINDOW** visible in request stream
- Useful for understanding when NOT to use it

### 05-failed-rollout.sh — Saved by maxUnavailable=0 🛟
Demonstrates failure recovery:
- Deploy a broken image (`fastapi-demo:v9-doesnotexist`)
- New pods stuck in `ImagePullBackOff`
- **Old pods keep serving traffic** (zero impact!)
- One command rollback fixes everything

## 🧹 Cleanup

```bash
kubectl delete -f k8s/
kubectl delete pod client --ignore-not-found=true
kubectl delete service recreate-service --ignore-not-found=true
```
