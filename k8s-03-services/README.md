# Project 03 - Service Discovery & Load Balancing

## Objective
Learn how to expose your FastAPI application using Kubernetes Services and understand different Service types for **networking** and **load balancing**.

## Prerequisites
- Completed Project 01 & 02
- FastAPI deployment from Project 02 running
- Kubernetes cluster running
- kubectl installed

## What You'll Learn
- **Services**: Expose applications running on Pods
- **Service Discovery**: How Pods find each other using DNS
- **Load Balancing**: Distribute traffic across multiple Pods
- **Service Types**: ClusterIP, NodePort, LoadBalancer
- **Endpoints**: How Services track Pod IPs
- **DNS**: Internal DNS resolution in Kubernetes

## Project Structure
```
k8s-03-services/
├── README.md
├── QUICKSTART.md
└── k8s/
    ├── service-clusterip.yaml    # Internal cluster access
    ├── service-nodeport.yaml     # External access via node port
    └── service-loadbalancer.yaml # External access via load balancer
```

---

## Understanding Services

### The Problem

In Project 02, you learned that:
- Deployments create and manage Pods
- Pods can be deleted and recreated (self-healing)
- Each Pod gets a new IP address when **recreated**
- Pod IPs are ephemeral and change frequently

**Question:** How do you access Pods if their IPs keep changing? 🤔

**Answer:** Kubernetes Services! 🎯

### What is a Service?

**Service** is an abstraction that defines a logical set of Pods and provides:
1. **Stable IP address** - Never changes
2. **DNS name** - e.g., `myapp-service.default.svc.cluster.local`
3. **Load balancing** - Distributes traffic across healthy Pods
4. **Service discovery** - Other Pods can find your app

### How Services Work

```
┌─────────────────────────────────────────────┐
│           Service (Stable IP)               │
│         ClusterIP: 10.96.100.50             │
│         DNS: fastapi-service                │
│                                             │
│    Selector: app=fastapi                    │
└──────────────┬──────────────────────────────┘
               │
               │ Routes traffic to Pods
               │ with matching labels
               │
     ┌─────────┼─────────┬─────────────┐
     ▼         ▼         ▼             ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │
│ IP: x.1 │ │ IP: x.2 │ │ IP: x.3 │
│ app:    │ │ app:    │ │ app:    │
│ fastapi │ │ fastapi │ │ fastapi │
└─────────┘ └─────────┘ └─────────┘
```

**Key Points:**
- Service IP (10.96.100.50) remains constant
- Pod IPs (x.1, x.2, x.3) change when Pods restart
- Service automatically updates which Pods to route to
- Uses **label selectors** to find Pods (from Project 02!)

---

## Service Types

Kubernetes provides different Service types for different use cases:

### 1. ClusterIP (Default)

**Purpose:** Internal cluster communication only

```yaml
type: ClusterIP
```

**Characteristics:**
- Only accessible within the cluster
- Gets a cluster-internal IP
- Default service type
- Used for microservice communication

**Use Cases:**
- Backend APIs
- Databases
- Internal services
- Microservices talking to each other

**Access:**
```bash
# From within cluster only
curl http://fastapi-service:8000

# From your machine (requires port-forward)
kubectl port-forward service/fastapi-service 8000:8000
```

### 2. NodePort

**Purpose:** External access via node's IP and static port

```yaml
type: NodePort
```

**Characteristics:**
- Accessible from outside the cluster
- Opens a port (30000-32767) on ALL nodes
- Routes to ClusterIP automatically created
- Good for dev/test environments

**Use Cases:**
- Development environments
- Testing external access
- Simple deployments without load balancer

**Access:**
```bash
# Access via any node's IP
curl http://<node-ip>:30080
```

### 3. LoadBalancer

**Purpose:** External access via cloud load balancer

```yaml
type: LoadBalancer
```

**Characteristics:**
- Creates cloud provider's load balancer
- Gets external IP address
- Routes to NodePort (auto-created)
- Production-ready external access

**Use Cases:**
- Production applications
- Public-facing services
- High availability requirements

**Access:**
```bash
# Access via load balancer's external IP
curl http://<external-ip>:8000
```

### Comparison Table

| Feature | ClusterIP | NodePort | LoadBalancer |
|---------|-----------|----------|--------------|
| **External Access** | ❌ No | ✅ Yes | ✅ Yes |
| **Internal Access** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Port Range** | Any | 30000-32767 | Any |
| **Cloud Cost** | Free | Free | 💰 Paid |
| **Use in Production** | ✅ Internal | ⚠️ Limited | ✅ Yes |
| **Load Balancing** | ✅ Internal | ✅ Node-level | ✅ External |

---

## Steps to Complete

### 1. Ensure FastAPI Deployment is Running

```bash
# Check if deployment from Project 02 is running
kubectl get deployments

# If not running, apply it
cd ../k8s-02-fastapi
kubectl apply -f k8s/deployment-scaled.yaml

# Verify pods are running
kubectl get pods -l app=fastapi
```

### 2. Create ClusterIP Service (Internal Access)

```bash
cd k8s-03-services

# Apply the ClusterIP service
kubectl apply -f k8s/service-clusterip.yaml

# Check the service
kubectl get service fastapi-service

# See the endpoints (Pod IPs)
kubectl get endpoints fastapi-service

# Describe the service
kubectl describe service fastapi-service
```

**Test Internal Access:**
```bash
# Port forward to access from your machine
kubectl port-forward service/fastapi-service 8000:8000

# In another terminal
curl http://localhost:8000
curl http://localhost:8000/info
```

### 3. Test Service Discovery with DNS

```bash
# Create a test pod
kubectl run test-pod --image=curlimages/curl:latest -it --rm -- sh

# From inside the test pod, access the service using DNS
curl http://fastapi-service:8000
curl http://fastapi-service.default.svc.cluster.local:8000

# Exit the test pod
exit
```

### 4. Create NodePort Service (External Access)

```bash
# Apply the NodePort service (this will replace ClusterIP)
kubectl apply -f k8s/service-nodeport.yaml

# Get the NodePort
kubectl get service fastapi-service

# The output shows the NodePort (e.g., 30080)
# NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# fastapi-service   NodePort   10.96.100.50    <none>        8000:30080/TCP   1m
```

**Test External Access:**

For **Docker Desktop**:
```bash
curl http://localhost:30080
```

For **Minikube**:
```bash
minikube service fastapi-service --url
# Opens the service in your browser
```

For **Kind**:
```bash
# Kind requires extra port mapping (covered in QUICKSTART)
kubectl port-forward service/fastapi-service 8000:8000
```

### 5. Create LoadBalancer Service (Cloud Provider)

**Note:** LoadBalancer only works with cloud providers (AWS, GCP, Azure) or local solutions like MetalLB.

```bash
# Apply the LoadBalancer service
kubectl apply -f k8s/service-loadbalancer.yaml

# Watch for external IP (may take 1-2 minutes)
kubectl get service fastapi-service --watch

# On cloud: You'll see an external IP
# NAME              TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
# fastapi-service   LoadBalancer   10.96.100.50    34.123.45.67      8000:30080/TCP   2m

# On local (Docker Desktop/Minikube/Kind): Shows <pending>
# Use NodePort instead for local development
```

**Test LoadBalancer:**
```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get service fastapi-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access the service
curl http://$EXTERNAL_IP:8000
```

### 6. Verify Load Balancing

```bash
# Make multiple requests and see different Pods responding
for i in {1..10}; do
  curl http://localhost:8000/info | grep hostname
  echo ""
done

# You should see different Pod names in the responses
# This proves load balancing is working!
```

### 7. Test Service Updates with Pod Changes

```bash
# Delete a pod
kubectl delete pod <pod-name>

# Service automatically updates endpoints
kubectl get endpoints fastapi-service

# Service continues to work (self-healing!)
curl http://localhost:8000
```

### 8. Explore Service Details

```bash
# View service configuration
kubectl get service fastapi-service -o yaml

# View endpoints (Pod IPs service routes to)
kubectl get endpoints fastapi-service -o yaml

# Describe service for events and details
kubectl describe service fastapi-service

# View all services
kubectl get services --all-namespaces
```

---

## Key Concepts Learned

### 1. Service Discovery

Services provide **DNS-based service discovery**:

```bash
# Short name (same namespace)
curl http://fastapi-service:8000

# Full DNS name
curl http://fastapi-service.default.svc.cluster.local:8000

# Format: <service-name>.<namespace>.svc.cluster.local
```

### 2. Label Selectors (from Project 02)

Services use selectors to find Pods:

```yaml
# Service
selector:
  app: fastapi

# Deployment Pod Template
labels:
  app: fastapi
  version: v1
  tier: backend
```

**The service routes to ALL Pods with `app: fastapi` label.**

### 3. Endpoints

Kubernetes automatically maintains a list of Pod IPs:

```bash
kubectl get endpoints fastapi-service

# Output shows Pod IPs
# NAME              ENDPOINTS                           AGE
# fastapi-service   10.244.0.5:8000,10.244.0.6:8000    1m
```

When Pods are created/deleted, endpoints update automatically!

### 4. Load Balancing Algorithms

Kubernetes uses **round-robin** load balancing by default:
- Request 1 → Pod 1
- Request 2 → Pod 2
- Request 3 → Pod 3
- Request 4 → Pod 1 (cycles back)

### 5. Port Mapping

```yaml
ports:
- port: 80           # Service port (what clients use)
  targetPort: 8000   # Pod port (where app listens)
  nodePort: 30080    # Node port (for NodePort type only)
```

**Example:**
```
Client → Service:80 → Pod:8000
```

---

## Common Commands Cheat Sheet

```bash
# Services
kubectl get services
kubectl get svc  # Short form
kubectl describe service <name>
kubectl get service <name> -o yaml

# Endpoints
kubectl get endpoints
kubectl get ep  # Short form
kubectl describe endpoints <name>

# Test service
kubectl port-forward service/<service-name> 8000:8000
curl http://localhost:8000

# DNS testing
kubectl run test --image=curlimages/curl -it --rm -- sh
# Inside pod: curl http://service-name:port

# Delete service
kubectl delete service <name>
kubectl delete -f service.yaml
```

---

## Troubleshooting

### Service Has No Endpoints

```bash
# Check endpoints
kubectl get endpoints fastapi-service

# Output: <none> means no Pods match the selector
```

**Solutions:**
1. Check service selector matches Pod labels
```bash
kubectl describe service fastapi-service | grep Selector
kubectl get pods --show-labels
```

2. Ensure Pods are running
```bash
kubectl get pods -l app=fastapi
```

### Cannot Access Service

**For ClusterIP:**
- Use `kubectl port-forward` from your machine
- Or access from within the cluster

**For NodePort:**
- Check firewall rules
- Use correct node IP
- Verify port is in range 30000-32767

**For LoadBalancer:**
- Wait for external IP (may take minutes)
- Check cloud provider console
- Verify cloud provider supports LoadBalancer

### DNS Not Resolving

```bash
# Test DNS from a pod
kubectl run test --image=curlimages/curl -it --rm -- sh
nslookup fastapi-service
nslookup fastapi-service.default.svc.cluster.local
```

---

## Service Traffic Flow

### ClusterIP Flow
```
Pod A (10.244.0.10)
    │
    │ curl http://fastapi-service:8000
    ▼
Service (10.96.100.50:8000)
    │
    │ Load balances to Pod IPs
    ▼
Pods (10.244.0.5, 10.244.0.6, 10.244.0.7)
```

### NodePort Flow
```
External Client
    │
    │ http://<node-ip>:30080
    ▼
Node (192.168.1.100:30080)
    │
    │ Routes to Service
    ▼
Service (10.96.100.50:8000)
    │
    │ Load balances to Pod IPs
    ▼
Pods (10.244.0.5, 10.244.0.6, 10.244.0.7)
```

### LoadBalancer Flow
```
External Client
    │
    │ http://34.123.45.67:8000
    ▼
Cloud Load Balancer (34.123.45.67)
    │
    │ Routes to Nodes
    ▼
NodePort (30080)
    │
    │ Routes to Service
    ▼
Service (10.96.100.50:8000)
    │
    │ Load balances to Pod IPs
    ▼
Pods (10.244.0.5, 10.244.0.6, 10.244.0.7)
```

---

## Best Practices

### 1. Use ClusterIP for Internal Services
```yaml
# For databases, caches, internal APIs
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
  - port: 6379
```

### 2. Use LoadBalancer for Public Services
```yaml
# For public-facing APIs
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8000
```

### 3. Always Use Readiness Probes
```yaml
# Ensures only healthy Pods receive traffic
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 4. Name Services Descriptively
```yaml
# Good names
metadata:
  name: user-api-service
  name: postgres-service
  name: frontend-service

# Avoid
metadata:
  name: service1
  name: svc
```

---

## Cleanup

```bash
# Delete services
kubectl delete service fastapi-service

# Keep deployment running for next project
kubectl get deployments
```

---

## Next Steps

Once completed, move to:
- **Project 04**: Self-Healing Applications - Deep dive into ReplicaSets
- **Project 10**: Ingress & Traffic Routing - Advanced routing beyond Services

---

## Additional Exercises

1. **Create services for different environments**
```yaml
# Development (ClusterIP)
# Staging (NodePort)
# Production (LoadBalancer)
```

2. **Test session affinity**
```yaml
spec:
  sessionAffinity: ClientIP
```

3. **Use different port numbers**
```yaml
ports:
- port: 80
  targetPort: 8000
  name: http
```

4. **Create headless service**
```yaml
spec:
  clusterIP: None  # For direct Pod access
```

---

## Resources
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
