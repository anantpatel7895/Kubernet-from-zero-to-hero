# Project 01 - Hello Kubernetes

## Objective
Deploy your first container on Kubernetes and understand basic Pod concepts.

## Prerequisites
- Kubernetes cluster running (minikube, kind, or Docker Desktop)
- kubectl installed and configured

## What You'll Learn
- Kubernetes Cluster basics
- kubectl CLI usage
- Pods and their lifecycle
- YAML manifest basics
- Container lifecycle management

## Project Structure
```
k8s-01-hello-world/
├── README.md
├── pod.yaml                 # Simple pod definition
└── pod-with-labels.yaml     # Pod with labels and metadata
```

---

## Steps to Complete

### 1. Verify Kubernetes Cluster
First, ensure your Kubernetes cluster is running:

```bash
# Check cluster information
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check current context
kubectl config current-context
```

### 2. Deploy Your First Pod
Apply the basic pod configuration:

```bash
kubectl apply -f pod.yaml
```

### 3. Check Pod Status
```bash
# List all pods
kubectl get pods

# Get detailed pod information
kubectl get pods -o wide

# Watch pods in real-time
kubectl get pods -w
```

### 4. Inspect the Pod
```bash
# Describe the pod (shows events, status, configuration)
kubectl describe pod hello-kubernetes

# Get pod logs
kubectl logs hello-kubernetes

# Get pod logs (follow mode)
kubectl logs -f hello-kubernetes
```

### 5. Access the Application
Forward a local port to the pod:

```bash
kubectl port-forward pod/hello-kubernetes 8080:80
```

Then visit http://localhost:8080 in your browser to see the nginx welcome page.

### 6. Execute Commands Inside the Pod
```bash
# Get an interactive shell
kubectl exec -it hello-kubernetes -- /bin/bash

# Run a single command
kubectl exec hello-kubernetes -- ls /usr/share/nginx/html

# Check nginx version
kubectl exec hello-kubernetes -- nginx -v
```

### 7. Deploy Pod with Labels
```bash
kubectl apply -f pod-with-labels.yaml

# View pods with labels
kubectl get pods --show-labels

# Filter pods by label
kubectl get pods -l app=hello
kubectl get pods -l environment=learning
```

### 8. Cleanup
Delete the pods when you're done:

```bash
kubectl delete pod hello-kubernetes
kubectl delete pod hello-kubernetes-labeled

# Or delete using the manifest files
kubectl delete -f pod.yaml
kubectl delete -f pod-with-labels.yaml
```

---

## Key Concepts Learned

### Pods
- **What**: The smallest deployable unit in Kubernetes
- **Why**: Pods wrap one or more containers and provide networking and storage
- **How**: Defined using YAML manifests with `kind: Pod`

### kubectl
- **What**: Command-line tool for interacting with Kubernetes
- **Common commands**:
  - `apply`: Create/update resources
  - `get`: List resources
  - `describe`: Show detailed information
  - `logs`: View container logs
  - `exec`: Execute commands in containers
  - `delete`: Remove resources

### YAML Manifests
- **apiVersion**: Specifies the API version
- **kind**: Type of resource (Pod, Deployment, Service, etc.)
- **metadata**: Name, labels, annotations
- **spec**: Desired state and configuration

### Container Lifecycle
- **Pending**: Pod accepted but container(s) not yet running
- **Running**: Pod bound to node, containers running
- **Succeeded**: All containers terminated successfully
- **Failed**: All containers terminated, at least one failed
- **Unknown**: Pod state cannot be determined

---

## Troubleshooting

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check if image is pulling
kubectl get pods -o wide
```

### Image Pull Errors
- Check image name and tag
- Verify network connectivity
- Check if image exists in registry

### Container Crashes
```bash
# View previous container logs
kubectl logs <pod-name> --previous
```

---

## Next Steps
Once you've completed this project, move on to:
- **Project 02**: Deploy a FastAPI application using Deployments
- Learn about ReplicaSets and how they differ from standalone Pods

---

## Additional Exercises

1. **Try different images**: Modify `pod.yaml` to use different containers (e.g., `httpd`, `busybox`)
2. **Add environment variables**: Add `env` section to pass configuration
3. **Multiple containers**: Add a second container to the pod (sidecar pattern)
4. **Resource limits**: Add CPU/memory requests and limits

Example with environment variables:
```yaml
spec:
  containers:
  - name: nginx
    image: nginx:latest
    env:
    - name: ENVIRONMENT
      value: "learning"
    ports:
    - containerPort: 80
```

---

## Resources
- [Kubernetes Pods Documentation](https://kubernetes.io/docs/concepts/workloads/pods/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [YAML Basics](https://yaml.org/spec/1.2/spec.html)
