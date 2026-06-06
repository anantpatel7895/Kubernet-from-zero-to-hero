# Test Scripts Summary

## Available Tests

### 📋 Quick Demo (`quick-demo.sh`)
**Duration:** ~30 seconds  
**Purpose:** Fast overview of service functionality

**What it tests:**
- Service info and ClusterIP
- Endpoint discovery
- DNS resolution
- HTTP connectivity
- Load balancing distribution

**Run:** `./test/quick-demo.sh`

---

### 🔵 ClusterIP Test (`test-clusterip.sh`)
**Duration:** ~2 minutes  
**Purpose:** Comprehensive ClusterIP service testing

**What it tests:**
- Service type verification
- Cluster IP assignment
- DNS resolution (multiple formats)
- Endpoints tracking
- HTTP connectivity
- Port-forward capability
- Health check endpoints
- Load balancing basics

**Run:** `./test/test-clusterip.sh`

---

### 🔶 NodePort Test (`test-nodeport.sh`)
**Duration:** ~2 minutes  
**Purpose:** External access via NodePort

**What it tests:**
- NodePort assignment (30000-32767 range)
- Environment detection (Docker Desktop/Minikube/Kind)
- External accessibility
- Multiple endpoint testing
- Internal cluster access (ClusterIP mode)

**Run:** `./test/test-nodeport.sh`

**Environments:**
- ✅ Docker Desktop: `http://localhost:30080`
- ✅ Minikube: `http://$(minikube ip):30080`
- ⚠️ Kind: Requires port-forward

---

### 🔍 Service Discovery Test (`test-service-discovery.sh`)
**Duration:** ~3 minutes  
**Purpose:** DNS and service discovery mechanisms

**What it tests:**
- DNS short name (`fastapi-service`)
- DNS namespace-qualified (`fastapi-service.default`)
- DNS FQDN (`fastapi-service.default.svc.cluster.local`)
- HTTP via different DNS formats
- Cross-namespace service access
- Service environment variables
- DNS SRV records

**Run:** `./test/test-service-discovery.sh`

---

### ⚖️ Load Balancing Test (`test-load-balancing.sh`)
**Duration:** ~3 minutes  
**Purpose:** Traffic distribution and load balancing

**What it tests:**
- Request distribution across pods
- Load balancing algorithm (round-robin/random)
- Session affinity configuration
- Concurrent request handling
- Pod failure simulation
- Automatic endpoint updates

**Run:** `./test/test-load-balancing.sh`

**Best with:** 3+ pods for visible distribution

---

### 🚀 Run All Tests (`run-all-tests.sh`)
**Duration:** ~5-10 minutes  
**Purpose:** Complete test suite

**What it does:**
- Auto-detects service type
- Runs all applicable tests
- Provides comprehensive summary
- Returns exit code for CI/CD

**Run:** `./test/run-all-tests.sh`

---

## Test Results Guide

### ✅ Success (Green)
```
✓ Service 'fastapi-service' exists
✓ Service type is ClusterIP
✓ Found 3 endpoint(s)
```
Everything working as expected.

### ⚠️ Warning (Yellow)
```
⚠ Only 1 pod running
⚠ LoadBalancer external IP pending
```
Partial success or informational message.

### ❌ Failure (Red)
```
✗ Service 'fastapi-service' not found
✗ HTTP request failed (Status: 503)
```
Action required to fix the issue.

---

## Quick Commands

```bash
# Make all scripts executable
chmod +x test/*.sh

# Quick demo (30 seconds)
./test/quick-demo.sh

# Test current service type
SERVICE_TYPE=$(kubectl get service fastapi-service -o jsonpath='{.spec.type}')
./test/test-${SERVICE_TYPE,,}.sh

# Run all tests
./test/run-all-tests.sh

# Test specific feature
./test/test-service-discovery.sh
./test/test-load-balancing.sh
```

---

## Prerequisites

### Required
✅ Kubernetes cluster running  
✅ `kubectl` configured  
✅ FastAPI deployment with label `app=fastapi`  
✅ At least one service deployed  

### Check Prerequisites
```bash
# Cluster
kubectl cluster-info

# Pods
kubectl get pods -l app=fastapi

# Service
kubectl get service fastapi-service
```

### Fix Missing Prerequisites
```bash
# Deploy FastAPI
cd ../k8s-02-fastapi
kubectl apply -f k8s/deployment-scaled.yaml

# Deploy Service
cd ../k8s-03-services
kubectl apply -f k8s/service-clusterip.yaml
```

---

## Common Use Cases

### 1. Verify New Service
```bash
# Deploy service
kubectl apply -f k8s/service-clusterip.yaml

# Quick check
./test/quick-demo.sh
```

### 2. Test After Scaling
```bash
# Scale deployment
kubectl scale deployment fastapi-deployment --replicas=5

# Test load balancing
./test/test-load-balancing.sh
```

### 3. Compare Service Types
```bash
# Test ClusterIP
kubectl apply -f k8s/service-clusterip.yaml
./test/test-clusterip.sh

# Test NodePort  
kubectl apply -f k8s/service-nodeport.yaml
./test/test-nodeport.sh
```

### 4. CI/CD Integration
```bash
#!/bin/bash
# deploy-and-test.sh

# Deploy
kubectl apply -f k8s/service-nodeport.yaml

# Wait for service
kubectl wait --for=condition=ready pod -l app=fastapi

# Run tests
./test/run-all-tests.sh

# Check result
if [ $? -eq 0 ]; then
    echo "✓ Tests passed!"
    exit 0
else
    echo "✗ Tests failed!"
    exit 1
fi
```

---

## Troubleshooting

### Tests hang or timeout
```bash
# Check if pods are running
kubectl get pods -l app=fastapi

# Check service exists
kubectl get service fastapi-service

# Check cluster connectivity
kubectl cluster-info
```

### Permission denied
```bash
chmod +x test/*.sh
```

### Service not found
```bash
kubectl apply -f k8s/service-clusterip.yaml
```

### No load balancing visible
```bash
# Scale to multiple pods
kubectl scale deployment fastapi-deployment --replicas=3
```

---

## Test Output Locations

All tests output to **stdout** with colored formatting:
- No log files created
- Clean, real-time output
- Easy to read and understand
- CI/CD friendly

---

## What You Learn

### From quick-demo.sh
- Basic service functionality
- Quick verification workflow

### From test-clusterip.sh
- Internal cluster networking
- DNS service discovery
- Port forwarding patterns

### From test-nodeport.sh
- External access methods
- Environment differences
- NodePort mechanics

### From test-service-discovery.sh
- DNS name formats
- Service discovery patterns
- Cross-namespace communication

### From test-load-balancing.sh
- Traffic distribution
- Load balancing algorithms
- Failover behavior

---

## Next Steps

After running tests:
1. ✅ **Understand results** - Review what passed/failed
2. ✅ **Try different service types** - ClusterIP → NodePort → LoadBalancer
3. ✅ **Scale and test** - See load balancing in action
4. ✅ **Move to Project 04** - Self-healing applications
5. ✅ **Eventually Project 10** - Ingress for advanced routing

---

## Files

| File | Purpose | Duration |
|------|---------|----------|
| `quick-demo.sh` | Fast overview | 30s |
| `test-clusterip.sh` | ClusterIP tests | 2m |
| `test-nodeport.sh` | NodePort tests | 2m |
| `test-service-discovery.sh` | DNS tests | 3m |
| `test-load-balancing.sh` | Load balancing | 3m |
| `run-all-tests.sh` | Complete suite | 5-10m |
| `README.md` | Detailed docs | - |
| `SUMMARY.md` | This file | - |

---

## Summary

These tests help you:
- ✅ Verify service configuration
- ✅ Understand service types
- ✅ Learn DNS patterns
- ✅ See load balancing
- ✅ Troubleshoot issues
- ✅ Prepare for production

**Start with:** `./test/quick-demo.sh`  
**Complete test:** `./test/run-all-tests.sh`

Happy testing! 🚀
