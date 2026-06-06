# Project 05 - Test Suite

Test scripts for horizontal scaling and HPA.

## 📜 Tests (Run in Order!)

| # | Script | Purpose | Duration |
|---|--------|---------|----------|
| 1 | `01-manual-scaling.sh` | Manual scaling demo | ~30s |
| 2 | `02-install-metrics.sh` | Install Metrics Server | ~2 min |
| 3 | `03-watch-hpa.sh` | Watch HPA status (run in 2nd terminal) | continuous |
| 4 | `04-trigger-scaling.sh` | Generate load & watch auto-scaling | ~3 min |
| 5 | `05-cleanup.sh` | Clean up all resources | ~10s |

## 🚀 Quick Start

```bash
# Make scripts executable
chmod +x test/*.sh

# Step 1: Deploy app
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Step 2: Try manual scaling
./test/01-manual-scaling.sh

# Step 3: Install metrics server (one-time)
./test/02-install-metrics.sh

# Step 4: Apply HPA
kubectl apply -f k8s/hpa.yaml

# Step 5: Trigger scaling
./test/04-trigger-scaling.sh

# Step 6: Cleanup when done
./test/05-cleanup.sh
```

## 💡 Tip: Use 2 Terminals

For the most educational experience:

**Terminal 1:** Run `./test/03-watch-hpa.sh` to watch HPA in real-time  
**Terminal 2:** Run `./test/04-trigger-scaling.sh` to generate load

You'll see the HPA react to load LIVE.
