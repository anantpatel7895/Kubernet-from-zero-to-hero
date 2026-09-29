# Keep in mind things

- Deployment, service, configmap, secret, ingress are all **Kubernetes resources**.
- A resource created inside a specific namespace is bounded by that namespace's scope. (any resource created in a namespace can only be accessed by other resources in the same namespace)





## ReplicaSets

- ReplicaSets created automatically by Deployment
- replicaSets ensure the right number of Pods are running
- deployment have the **ownership** of replicaSets
- replicaSets have the **ownership** of Pods
- at the time of rollout, deployment creates a new replicaSet and scales down the old one


#### Understanding the Hierarchy

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