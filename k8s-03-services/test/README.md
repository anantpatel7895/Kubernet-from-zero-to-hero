# Service Testing Suite

This folder contains comprehensive tests for Kubernetes Services to help you understand and verify service behavior.

## Test Scripts

### 1. `test-clusterip.sh`
Tests ClusterIP service functionality (internal cluster access).

**What it tests:**
- Service existence and type
- Service endpoints (Pod IPs)
- DNS resolution within cluster
- HTTP connectivity
- Port-forward capability
- Load balancing across pods

**Run:**
```bash
./test/test-clusterip.sh
```

**Prerequisites:**
- ClusterIP service deployed: `kubectl apply -f k8s/service-clusterip.yaml`

---

### 2. `test-nodeport.sh`
Tests NodePort service functionality (external access via node ports).

**What it tests:**
- Service type verification
- NodePort assignment
- External accessibility
- Environment detection (Docker Desktop, Minikube, Kind)
- Multiple endpoint testing
- Internal cluster access (ClusterIP functionality)

**Run:**
```bash
./test/test-nodeport.sh
```

**Prerequisites:**
- NodePort service deployed: `kubectl apply -f k8s/service-nodeport.yaml`

**Environment-specific behavior:**
- **Docker Desktop**: Tests `http://localhost:30080`
- **Minikube**: Tests `http://$(minikube ip):30080`
- **Kind**: Suggests port-forward alternative

---

### 3. `test-service-discovery.sh`
Tests DNS-based service discovery mechanisms.

**What it tests:**
- DNS resolution (short name, namespace-qualified, FQDN)
- HTTP connectivity via different DNS formats
- Cross-namespace service discovery
- Service environment variables
- DNS SRV records

**Run:**
```bash
./test/test-service-discovery.sh
```

**DNS formats tested:**
- `fastapi-service` (short name, same namespace)
- `fastapi-service.default` (namespace-qualified)
- `fastapi-service.default.svc.cluster.local` (FQDN)

---

### 4. `test-load-balancing.sh`
Tests load balancing behavior across multiple pods.

**What it tests:**
- Request distribution across pods
- Session affinity settings
- Concurrent request handling
- Load balancing with pod failures
- Traffic redistribution

**Run:**
```bash
./test/test-load-balancing.sh
```

**Best with:**
- 3+ pods for visible load balancing
- Scale up: `kubectl scale deployment fastapi-deployment --replicas=3`

---

### 5. `run-all-tests.sh`
Runs all applicable tests based on current service type.

**Run:**
```bash
./test/run-all-tests.sh
```

**What it does:**
- Detects service type (ClusterIP, NodePort, LoadBalancer)
- Runs appropriate tests
- Provides comprehensive summary
- Returns exit code (0 = all pass, 1 = some failed)

---

## Quick Start

### Make scripts executable
```bash
chmod +x test/*.sh
```

### Run all tests
```bash
./test/run-all-tests.sh
```

### Run individual tests
```bash
# Test ClusterIP service
kubectl apply -f k8s/service-clusterip.yaml
./test/test-clusterip.sh

# Test NodePort service
kubectl apply -f k8s/service-nodeport.yaml
./test/test-nodeport.sh

# Test service discovery (works with any service type)
./test/test-service-discovery.sh

# Test load balancing (better with 3+ pods)
kubectl scale deployment fastapi-deployment --replicas=3
./test/test-load-balancing.sh
```

---

## Test Output

All tests provide:
- ✅ **Green checkmarks** for passed tests
- ❌ **Red X marks** for failed tests
- ⚠️ **Yellow warnings** for partial success or info
- 📊 **Detailed output** for each test step

Example output:
```
==========================================
Testing ClusterIP Service
==========================================

1. Checking if service exists...
✓ Service 'fastapi-service' exists

2. Verifying service type is ClusterIP...
✓ Service type is ClusterIP

3. Service Details:
   Cluster IP: 10.97.71.170
   Port: 8000
   Target Port: 8000

...
```

---

## Prerequisites

### Required
- Kubernetes cluster running
- `kubectl` configured
- FastAPI deployment running (`kubectl get pods -l app=fastapi`)
- At least one service deployed

### Optional (for better testing)
- Multiple pods (3+) for load balancing tests
- Different Kubernetes environments (Docker Desktop, Minikube, Kind)

---

## Test Scenarios

### Scenario 1: Test ClusterIP
```bash
# Deploy ClusterIP service
kubectl apply -f k8s/service-clusterip.yaml

# Run tests
./test/test-clusterip.sh
./test/test-service-discovery.sh
./test/test-load-balancing.sh
```

### Scenario 2: Test NodePort
```bash
# Switch to NodePort
kubectl apply -f k8s/service-nodeport.yaml

# Run tests
./test/test-nodeport.sh
./test/test-service-discovery.sh
./test/test-load-balancing.sh
```

### Scenario 3: Test with Scaling
```bash
# Scale to 3 replicas
kubectl scale deployment fastapi-deployment --replicas=3

# Wait for pods
kubectl wait --for=condition=ready pod -l app=fastapi --timeout=60s

# Run load balancing test
./test/test-load-balancing.sh
```

### Scenario 4: Full Test Suite
```bash
# Deploy service
kubectl apply -f k8s/service-nodeport.yaml

# Run all tests
./test/run-all-tests.sh
```

---

## Troubleshooting

### Scripts not executable
```bash
chmod +x test/*.sh
```

### Service not found
```bash
# Check if service exists
kubectl get service fastapi-service

# Deploy service
kubectl apply -f k8s/service-clusterip.yaml
```

### No pods running
```bash
# Check pods
kubectl get pods -l app=fastapi

# Deploy from Project 02
cd ../k8s-02-fastapi
kubectl apply -f k8s/deployment-scaled.yaml
```

### Tests fail on Minikube
```bash
# Ensure minikube is running
minikube status

# For NodePort tests
minikube service fastapi-service --url
```

### Tests fail on Kind
```bash
# Kind requires port mapping or port-forward
kubectl port-forward service/fastapi-service 8000:8000
```

---

## Understanding Test Results

### All Green (Success)
```
✓ ClusterIP Service Test
✓ Service Discovery Test
✓ Load Balancing Test

🎉 All tests passed!
```
Your service is working correctly!

### Some Yellow (Warnings)
```
✓ ClusterIP Service Test
⚠ Load Balancing Test (only 1 pod)

⚠ Some warnings. Review output.
```
Service works but could be improved (e.g., scale up for better load balancing).

### Red (Failures)
```
✗ NodePort Service Test

⚠ Some tests failed.
```
Review the detailed output to identify the issue.

---

## What Each Test Teaches

### ClusterIP Test
- How services provide stable IPs
- Internal cluster networking
- DNS-based service discovery
- Port forwarding for local access

### NodePort Test
- External access patterns
- Environment-specific differences
- Port mapping concepts
- NodePort range (30000-32767)

### Service Discovery Test
- DNS in Kubernetes
- Different DNS formats
- Cross-namespace communication
- Service environment variables

### Load Balancing Test
- Traffic distribution algorithms
- Session affinity
- Automatic failover
- Endpoint management

---

## Advanced Usage

### Run tests in CI/CD
```bash
# Exit code: 0 = success, 1 = failure
./test/run-all-tests.sh
if [ $? -eq 0 ]; then
    echo "Tests passed, deploying to production"
else
    echo "Tests failed, blocking deployment"
    exit 1
fi
```

### Test specific endpoints
```bash
# Modify test scripts to test your custom endpoints
# Edit test-clusterip.sh and add your endpoints
```

### Continuous monitoring
```bash
# Run tests in a loop
while true; do
    ./test/run-all-tests.sh
    sleep 60
done
```

---

## Files

- `test-clusterip.sh` - ClusterIP service tests
- `test-nodeport.sh` - NodePort service tests  
- `test-service-discovery.sh` - DNS and service discovery tests
- `test-load-balancing.sh` - Load balancing behavior tests
- `run-all-tests.sh` - Master test runner
- `README.md` - This file

---

## Related Documentation

- Main README: `../README.md`
- Quick Start: `../QUICKSTART.md`
- Kubernetes Services: https://kubernetes.io/docs/concepts/services-networking/service/
- DNS for Services: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

---

## Contributing

To add new tests:

1. Create a new test script: `test-mytest.sh`
2. Follow the existing format (colors, structure)
3. Make it executable: `chmod +x test/test-mytest.sh`
4. Add it to `run-all-tests.sh`
5. Update this README

---

## Summary

These tests help you:
- ✅ Verify service configuration
- ✅ Understand service types
- ✅ Learn DNS service discovery
- ✅ See load balancing in action
- ✅ Troubleshoot service issues
- ✅ Prepare for production deployments

Happy testing! 🚀
