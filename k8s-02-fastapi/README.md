# Project 02 - FastAPI Deployment

## Objective
Deploy a FastAPI application using Kubernetes Deployments and understand how Deployments manage ReplicaSets and Pods.

## Prerequisites
- Completed Project 01
- Kubernetes cluster running
- kubectl installed
- Docker installed (for building custom image)

## What You'll Learn
- **Deployments**: Declarative way to manage applications
- **ReplicaSets**: Maintain a stable set of replica Pods
- **Labels & Selectors**: How Deployments find and manage Pods
- **Desired State**: Kubernetes automatically maintains your desired configuration
- **Container Orchestration**: Managing multiple replicas of your application

## Project Structure
```
k8s-02-fastapi/
├── README.md
├── QUICKSTART.md
├── app/
│   ├── main.py              # FastAPI application
│   └── requirements.txt     # Python dependencies
├── docker/
│   └── Dockerfile           # Container image definition
└── k8s/
    ├── deployment.yaml      # Deployment manifest
    └── deployment-scaled.yaml # Deployment with multiple replicas
```

---

## Steps to Complete

### 1. Build the FastAPI Application

First, let's build the Docker image:

```bash
# Build the Docker image from project root
docker build -f docker/Dockerfile -t fastapi-demo:v1 .

# Test locally (optional)
docker run -p 8000:8000 fastapi-demo:v1
# Visit http://localhost:8000
```

**For Minikube users:**
```bash
# Use minikube's Docker daemon
eval $(minikube docker-env)
docker build -f docker/Dockerfile -t fastapi-demo:v1 .
```

**For Kind users:**
```bash
# Build and load into kind cluster
docker build -f docker/Dockerfile -t fastapi-demo:v1 .
kind load docker-image fastapi-demo:v1
```

**Note**: The Dockerfile is in the `docker/` folder and builds from the project root to access the `app/` directory.

### 2. Deploy Using Deployment (Single Replica)

```bash
# change directory to project root
cd k8s-02-fastapi

# Build the Docker image
docker build -f docker/Dockerfile -t fastapi-demo:v1 .

# Apply the deployment
kubectl apply -f k8s/deployment.yaml

# Check deployment status
kubectl get deployments

# Check ReplicaSets (created automatically by Deployment)
kubectl get replicasets

# Check Pods (created by ReplicaSet)
kubectl get pods

# See the relationship
kubectl get all -l app=fastapi
```

### 3. Understanding the Hierarchy

```
Deployment
    └── ReplicaSet
            ├── Pod 1
            ├── Pod 2
            └── Pod 3
```

**Why this matters:**
- **Deployment**: Manages rollouts, updates, and rollbacks
- **ReplicaSet**: Ensures the right number of Pods are running
- **Pod**: Runs your actual application container

### 4. Scale Your Application

```bash
# Scale to 3 replicas using kubectl
kubectl scale deployment fastapi-deployment --replicas=3

# Watch pods being created
kubectl get pods -w

# Or apply the scaled deployment manifest
kubectl apply -f k8s/deployment-scaled.yaml

# Verify scaling
kubectl get pods -l app=fastapi # -l means "label selector"
kubectl get deployment fastapi-deployment
```

### 5. Explore Labels and Selectors

```bash
# Show all labels
kubectl get pods --show-labels

# Filter by label
kubectl get pods -l app=fastapi
kubectl get pods -l version=v1

# Describe deployment to see selector
kubectl describe deployment fastapi-deployment

# Get all resources with specific label
kubectl get all -l app=fastapi
```

### 6. Test Self-Healing

Delete a pod and watch Kubernetes recreate it automatically:

```bash
# Get pod names
kubectl get pods

# Delete one pod
kubectl delete pod <pod-name>

# Watch Kubernetes automatically create a new one
kubectl get pods -w

# The ReplicaSet ensures desired state is maintained!
```

### 7. Access the Application

```bash
# Port forward to one of the pods
kubectl port-forward deployment/fastapi-deployment 8000:8000

# Visit http://localhost:8000
# Try the interactive docs at http://localhost:8000/docs
```

### 8. Update the Application

```bash
# Update the image version in deployment.yaml to v2
# Then apply the changes
kubectl apply -f k8s/deployment.yaml

# Watch the rolling update
kubectl rollout status deployment/fastapi-deployment

# Check rollout history
kubectl rollout history deployment/fastapi-deployment
```

### 9. Cleanup

```bash
kubectl delete -f k8s/deployment.yaml
# Or
kubectl delete deployment fastapi-deployment
```

---

## Key Concepts Learned

### 1. Deployments vs Pods

| Feature | Pod | Deployment |
|---------|-----|------------|
| **Self-healing** | ❌ If deleted, gone forever | ✅ Automatically recreated |
| **Scaling** | ❌ Manual pod creation | ✅ Simple replica count |
| **Updates** | ❌ Manual recreation | ✅ Rolling updates |
| **Rollback** | ❌ Not possible | ✅ Easy rollback |
| **Use case** | Learning, testing | Production apps |

### 2. Labels and Selectors

**Labels** (defined in Pod template):
```yaml
metadata:
  labels:
    app: fastapi
    version: v1
```

**Selectors** (how Deployment finds its Pods):
```yaml
selector:
  matchLabels:
    app: fastapi
```

**Why it matters**: Deployments use selectors to manage only the Pods with matching labels.

### 3. Desired State

Kubernetes constantly works to match **desired state** (your YAML) with **actual state**:

```bash
# You say: "I want 3 replicas"
replicas: 3

# Kubernetes ensures: "There will always be 3 replicas"
# - Pod dies? → Create new one
# - Too many pods? → Delete extras
# - Node fails? → Reschedule on another node
```

### 4. ReplicaSet

- Created automatically by Deployment
- You rarely interact with ReplicaSets directly
- Manages the actual Pod replicas
- Old ReplicaSets are kept for rollback purposes

---

## Common Commands Cheat Sheet

```bash
# Deployments
kubectl get deployments
kubectl describe deployment <name>
kubectl scale deployment <name> --replicas=5
kubectl rollout status deployment <name>
kubectl rollout history deployment <name>
kubectl rollout undo deployment <name>

# ReplicaSets
kubectl get replicasets
kubectl describe replicaset <name>

# Pods managed by deployment
kubectl get pods -l app=fastapi
kubectl logs -l app=fastapi --tail=50
kubectl delete pod <name>  # Will be recreated!

# All resources with label
kubectl get all -l app=fastapi
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check deployment events
kubectl describe deployment fastapi-deployment

# Check pod status
kubectl get pods
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Image Pull Errors

- Verify image name and tag
- For local images, ensure they're available in your cluster
- For minikube: `eval $(minikube docker-env)` then rebuild

### Port Forward Not Working

```bash
# Ensure pod is running
kubectl get pods

# Use deployment name instead
kubectl port-forward deployment/fastapi-deployment 8000:8000
```

---

## Differences from Project 01

| Aspect | Project 01 (Pod) | Project 02 (Deployment) |
|--------|------------------|-------------------------|
| **Resource** | Pod | Deployment → ReplicaSet → Pod |
| **Replicas** | Single pod | Multiple replicas |
| **Self-healing** | No | Yes |
| **Updates** | Manual | Rolling updates |
| **Production-ready** | No | Yes |

---

## Next Steps

Once completed, move to:
- **Project 03**: Expose FastAPI through Services (ClusterIP, NodePort, LoadBalancer)
- Learn how Services use labels to route traffic to Pods

---

## Additional Exercises

1. **Scale up and down**: Try different replica counts (1, 3, 5, 10)
2. **Label experiments**: Add custom labels and filter by them
3. **Multiple versions**: Run v1 and v2 side-by-side with different labels
4. **Resource limits**: Add CPU/memory requests and limits
5. **Environment variables**: Add env vars to configure the app

Example with environment variables:
```yaml
spec:
  containers:
  - name: fastapi
    image: fastapi-demo:v1
    env:
    - name: ENVIRONMENT
      value: "production"
    - name: LOG_LEVEL
      value: "info"
```

---

## Resources
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
