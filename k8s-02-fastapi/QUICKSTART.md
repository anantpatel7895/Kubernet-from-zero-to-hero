# FastAPI Demo - Quick Start

## Build and Deploy

### 1. Build the Docker Image

```bash
# Build from project root (k8s-02-fastapi directory)
docker build -f docker/Dockerfile -t fastapi-demo:v1 .
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

**Note**: The Dockerfile includes SSL workarounds for corporate networks.

### 2. Test Locally (Optional)

```bash
docker run -p 8000:8000 fastapi-demo:v1
```

Visit:
- http://localhost:8000 - Welcome message
- http://localhost:8000/docs - Interactive API docs
- http://localhost:8000/health - Health check
- http://localhost:8000/info - Pod information

### 3. Deploy to Kubernetes

```bash
# Deploy with 1 replica
kubectl apply -f k8s/deployment.yaml

# Check deployment
kubectl get deployments
kubectl get pods
kubectl get replicasets

# View logs
kubectl logs -l app=fastapi
```

### 4. Access the Application

```bash
kubectl port-forward deployment/fastapi-deployment 8000:8000
```

Then visit http://localhost:8000

### 5. Scale the Application

```bash
# Scale to 3 replicas
kubectl scale deployment fastapi-deployment --replicas=3

# Or apply the scaled deployment
kubectl apply -f k8s/deployment-scaled.yaml

# Watch pods being created
kubectl get pods -w
```

### 6. Test Self-Healing

```bash
# Delete a pod
kubectl delete pod <pod-name>

# Watch it get recreated automatically
kubectl get pods -w
```

## Key Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check
- `GET /info` - Pod/container information
- `GET /api/v1/users` - List users
- `GET /api/v1/users/{id}` - Get specific user
- `GET /docs` - Interactive API documentation

## Useful Commands

```bash
# View all resources with label
kubectl get all -l app=fastapi

# View logs from all pods
kubectl logs -l app=fastapi --tail=50

# Describe the deployment
kubectl describe deployment fastapi-deployment

# Check rollout status
kubectl rollout status deployment/fastapi-deployment

# View rollout history
kubectl rollout history deployment/fastapi-deployment
```
