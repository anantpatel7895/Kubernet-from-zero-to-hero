# Service Discovery & Load Balancing - Quick Start

## Prerequisites

Ensure FastAPI deployment from Project 02 is running:

```bash
kubectl get deployments
kubectl get pods -l app=fastapi
```

If not running:
```bash
cd ../k8s-02-fastapi
kubectl apply -f k8s/deployment-scaled.yaml
```

---

## Quick Start

### 1. ClusterIP Service (Internal Access)

```bash
# Apply the service
kubectl apply -f k8s/service-clusterip.yaml

# Check the service
kubectl get service fastapi-service

# View endpoints (Pod IPs)
kubectl get endpoints fastapi-service

# Port forward to access from your machine
kubectl port-forward service/fastapi-service 8000:8000
```

**Test:**
```bash
# In another terminal
curl http://localhost:8000
curl http://localhost:8000/docs
curl http://localhost:8000/info
```

---

### 2. NodePort Service (External Access)

```bash
# Replace ClusterIP with NodePort
kubectl apply -f k8s/service-nodeport.yaml

# Get the NodePort (look for PORT(S) column)
kubectl get service fastapi-service
# Output: 8000:30080/TCP means NodePort is 30080
```

**Test (Docker Desktop):**
```bash
curl http://localhost:30080
```

**Test (Minikube):**
```bash
minikube service fastapi-service --url
# Or
curl http://$(minikube ip):30080
```

**Test (Kind):**
```bash
# Kind needs port forwarding
kubectl port-forward service/fastapi-service 8000:8000
curl http://localhost:8000
```

---

### 3. LoadBalancer Service (Cloud Only)

**Note:** Only works with cloud providers or MetalLB

```bash
# Apply LoadBalancer service
kubectl apply -f k8s/service-loadbalancer.yaml

# Watch for external IP (takes 1-2 minutes on cloud)
kubectl get service fastapi-service --watch

# On local clusters, it will stay <pending>
# Use NodePort instead for local development
```

**Test (Cloud Provider):**
```bash
# Get external IP
EXTERNAL_IP=$(kubectl get service fastapi-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access the service
curl http://$EXTERNAL_IP:8000
```

---

## Test Service Discovery

### DNS Resolution

```bash
# Create a test pod with curl
kubectl run test-pod --image=curlimages/curl:latest -it --rm -- sh

# Inside the pod, test DNS resolution
curl http://fastapi-service:8000
curl http://fastapi-service.default.svc.cluster.local:8000

# Test specific endpoints
curl http://fastapi-service:8000/info
curl http://fastapi-service:8000/health

# Exit
exit
```

---

## Test Load Balancing

```bash
# Make multiple requests and see different Pods responding
for i in {1..10}; do
  curl -s http://localhost:8000/info | grep hostname
done

# You should see different Pod names proving load balancing works!
```

---

## View Service Details

```bash
# Service configuration
kubectl get service fastapi-service -o yaml

# Endpoints (Pod IPs)
kubectl get endpoints fastapi-service

# Detailed information
kubectl describe service fastapi-service

# All services
kubectl get services
```

---

## Test Self-Healing with Service

```bash
# Get current pods
kubectl get pods -l app=fastapi

# Delete one pod
kubectl delete pod <pod-name>

# Service automatically updates endpoints
kubectl get endpoints fastapi-service

# Service continues to work!
kubectl port-forward service/fastapi-service 8000:8000
curl http://localhost:8000
```

---

## Switch Between Service Types

```bash
# Switch to ClusterIP
kubectl apply -f k8s/service-clusterip.yaml

# Switch to NodePort
kubectl apply -f k8s/service-nodeport.yaml

# Switch to LoadBalancer
kubectl apply -f k8s/service-loadbalancer.yaml

# Each apply updates the existing service
```

---

## Key Endpoints to Test

```bash
# Welcome message
curl http://localhost:8000/

# API documentation
curl http://localhost:8000/docs

# Health check
curl http://localhost:8000/health

# Pod information
curl http://localhost:8000/info

# User API
curl http://localhost:8000/api/v1/users
```

---

## Cleanup

```bash
# Delete service
kubectl delete service fastapi-service

# Or delete using file
kubectl delete -f k8s/service-nodeport.yaml

# Keep deployment running for next project
kubectl get deployments
```

---

## Common Issues

### Service has no endpoints

```bash
# Check if pods are running
kubectl get pods -l app=fastapi

# Check if labels match
kubectl describe service fastapi-service | grep Selector
kubectl get pods --show-labels
```

### Cannot access NodePort

```bash
# Verify service type
kubectl get service fastapi-service

# Check NodePort number
kubectl get service fastapi-service -o yaml | grep nodePort

# For Docker Desktop, use localhost
curl http://localhost:<nodePort>

# For Minikube, use minikube IP
curl http://$(minikube ip):<nodePort>
```

### Port forward fails

```bash
# Check if service exists
kubectl get service fastapi-service

# Check if pods are ready
kubectl get pods -l app=fastapi

# Use correct port
kubectl port-forward service/fastapi-service 8000:8000
```

---

## Service Type Comparison

| Type | Access | Command |
|------|--------|---------|
| **ClusterIP** | Internal only | `kubectl port-forward service/fastapi-service 8000:8000` |
| **NodePort** | External | `curl http://localhost:30080` (Docker Desktop) |
| **LoadBalancer** | External | `curl http://<EXTERNAL-IP>:8000` (Cloud only) |

---

## Next Steps

- Learn about **Ingress** (Project 10) for advanced routing
- Explore **Network Policies** for security
- Set up **Service Mesh** (Istio/Linkerd) for advanced traffic management
