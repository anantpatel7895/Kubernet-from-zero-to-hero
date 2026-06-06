# Kubernetes Labels and Selectors

## Overview

**Labels** and **Selectors** are fundamental concepts in Kubernetes that enable resource organization, selection, and grouping. They work together to create flexible and powerful relationships between different Kubernetes objects.

---

## What are Labels?

**Labels** are key-value pairs attached to Kubernetes objects (like Pods, Services, Deployments) for **identification and organization**.

### Labels Structure

```yaml
metadata:
  labels:
    key1: value1
    key2: value2
    app: myapp
    environment: production
    version: v1.2.3
```

**Characteristics:**
- Key-value pairs
- Attached to any Kubernetes object
- Multiple labels per object
- Used for organization and selection
- Not unique (many objects can have the same label)

### Example: Pod with Labels

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  labels:
    app: frontend           # Application name
    tier: frontend          # Application tier
    environment: production # Environment
    version: v2.1          # Version
    team: ui-team          # Team ownership
spec:
  containers:
  - name: nginx
    image: nginx:1.21
```

---

## What are Selectors?

**Selectors** are queries used to find and group Kubernetes objects based on their labels. They allow you to select a subset of objects that match specific label criteria.

### Types of Selectors

#### 1. Equality-Based Selectors
Match labels with exact values.

```yaml
selector:
  app: frontend
  environment: production
```

This selects all objects where:
- Label `app` equals `frontend` **AND**
- Label `environment` equals `production`

#### 2. Set-Based Selectors (matchLabels and matchExpressions)
More powerful and flexible.

```yaml
selector:
  matchLabels:
    app: frontend
  matchExpressions:
  - key: environment
    operator: In
    values:
    - production
    - staging
  - key: tier
    operator: NotIn
    values:
    - backend
```

**Operators:**
- `In` - Label value is in the list
- `NotIn` - Label value is not in the list
- `Exists` - Label key exists (any value)
- `DoesNotExist` - Label key does not exist

---

## How Labels and Selectors Work Together

### Example 1: Deployment Managing Pods

**Deployment YAML:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
spec:
  replicas: 3
  selector:                    # ← SELECTOR: How to find Pods
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:                  # ← LABELS: Applied to Pods
        app: frontend
        version: v1
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
```

**What happens:**
```
1. Deployment looks for Pods with label: app=frontend
2. Finds 3 Pods (or creates them if missing)
3. Manages those Pods (scaling, updates, etc.)
```

**Visual Representation:**
```
┌─────────────────────────────────────┐
│       Deployment                    │
│   selector:                         │
│     matchLabels:                    │
│       app: frontend  ←──────┐       │
└─────────────────────────────│───────┘
                              │
                              │ Selects Pods with
                              │ app=frontend
                              │
        ┌─────────────────────┼───────────────────┬─────────────────┐
        ▼                     ▼                   ▼                 ▼
┌───────────────┐     ┌───────────────┐   ┌───────────────┐
│   Pod 1       │     │   Pod 2       │   │   Pod 3       │
│ labels:       │     │ labels:       │   │ labels:       │
│  app: frontend│     │  app: frontend│   │  app: frontend│
│  version: v1  │     │  version: v1  │   │  version: v1  │
└───────────────┘     └───────────────┘   └───────────────┘
```

---

### Example 2: Service Routing Traffic to Pods

**Service YAML:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:                    # ← SELECTOR: Which Pods to route to
    app: frontend
    tier: frontend
  ports:
  - port: 80
    targetPort: 8080
```

**Pods YAML:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod-1
  labels:                      # ← LABELS: Matched by Service
    app: frontend
    tier: frontend
    version: v1
spec:
  containers:
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
```

**What happens:**
```
1. Service looks for Pods with labels: app=frontend AND tier=frontend
2. Routes traffic to all matching Pods
3. Load balances across them
```

**Visual Representation:**
```
┌─────────────────────────────────────┐
│       Service                       │
│   selector:                         │
│     app: frontend    ────────┐      │
│     tier: frontend           │      │
└──────────────────────────────│──────┘
                               │
                               │ Routes traffic to
                               │ matching Pods
                               │
        ┌──────────────────────┼──────────────────┬────────────────┐
        ▼                      ▼                  ▼                ▼
┌──────────────┐     ┌──────────────┐    ┌──────────────┐
│   Pod 1      │     │   Pod 2      │    │   Pod 3      │
│ labels:      │     │ labels:      │    │ labels:      │
│  app: frontend│    │  app: frontend│   │  app: frontend│
│  tier: frontend│   │  tier: frontend│  │  tier: frontend│
└──────────────┘     └──────────────┘    └──────────────┘
     ↑                    ↑                    ↑
     └────────────────────┴────────────────────┘
          Traffic distributed to all 3 Pods
```

---

## Practical Examples

### Example 3: Multiple Versions Running Side-by-Side

**Deployment v1:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: v1          # ← Selects only v1 pods
  template:
    metadata:
      labels:
        app: myapp
        version: v1        # ← Labels for v1
    spec:
      containers:
      - name: app
        image: myapp:1.0
```

**Deployment v2:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: v2          # ← Selects only v2 pods
  template:
    metadata:
      labels:
        app: myapp
        version: v2        # ← Labels for v2
    spec:
      containers:
      - name: app
        image: myapp:2.0
```

**Service (routes to both versions):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp             # ← Matches both v1 and v2 pods
  ports:
  - port: 80
    targetPort: 8080
```

**Result:**
- 3 Pods running v1
- 1 Pod running v2
- Service routes traffic to all 4 Pods (75% v1, 25% v2)
- This is a canary deployment!

---

## Common Label Patterns

### Application Labels
```yaml
labels:
  app: myapp                    # Application name
  app.kubernetes.io/name: myapp # Recommended key
  app.kubernetes.io/version: 1.2.3
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: kubectl
```

### Environment Labels
```yaml
labels:
  environment: production   # development, staging, production
  tier: frontend           # frontend, backend, cache, database
  region: us-east-1        # Geographic region
```

### Team and Ownership
```yaml
labels:
  team: platform          # Team ownership
  owner: john-doe         # Individual ownership
  cost-center: engineering
```

### Release and Version
```yaml
labels:
  version: v1.2.3        # Semantic version
  release: stable        # stable, beta, alpha
  build: "12345"         # Build number
```

---

## Using Selectors in kubectl

### Select Pods by Label

```bash
# Single label
kubectl get pods -l app=frontend

# Multiple labels (AND)
kubectl get pods -l app=frontend,environment=production

# Using != (NOT equal)
kubectl get pods -l environment!=production

# Using IN
kubectl get pods -l 'environment in (production,staging)'

# Using NOT IN
kubectl get pods -l 'tier notin (backend,cache)'

# Label exists
kubectl get pods -l environment

# Label doesn't exist
kubectl get pods -l '!environment'
```

### Show Labels

```bash
# Show all labels
kubectl get pods --show-labels

# Show specific labels as columns
kubectl get pods -L app,version,environment

# Filter and show labels
kubectl get pods -l app=frontend --show-labels
```

### Other Resources

```bash
# Deployments
kubectl get deployments -l app=frontend

# Services
kubectl get services -l tier=frontend

# All resources with label
kubectl get all -l app=myapp

# Multiple resource types
kubectl get pods,services,deployments -l environment=production
```

---

## Selector Rules and Best Practices

### 1. Selector Must Match Template Labels

**✅ CORRECT:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp          # ← Selector
  template:
    metadata:
      labels:
        app: myapp        # ← Matches selector ✅
        version: v1       # Additional labels OK
```

**❌ WRONG:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp          # ← Selector
  template:
    metadata:
      labels:
        app: different    # ← Doesn't match! ❌
```

**Error:**
```
The Deployment "myapp" is invalid: spec.template.metadata.labels: 
Invalid value: map[string]string{"app":"different"}: 
`selector` does not match template `labels`
```

---

### 2. Immutable Selectors

Once a Deployment/Service is created, you **cannot change the selector**.

```bash
# This will FAIL:
kubectl patch deployment myapp -p '{"spec":{"selector":{"matchLabels":{"app":"newapp"}}}}'

# Error: field is immutable
```

**Solution:** Delete and recreate, or create a new Deployment.

---

### 3. Label Naming Conventions

**Recommended format:**
```yaml
labels:
  # Simple key
  app: myapp
  
  # Prefixed key (recommended for shared environments)
  mycompany.com/app: myapp
  
  # Kubernetes recommended labels
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: 1.0.0
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: ecommerce-platform
  app.kubernetes.io/managed-by: helm
```

**Rules:**
- Keys: alphanumeric, `-`, `_`, `.`
- Optional prefix: `domain.com/key`
- Values: up to 63 characters
- Values: alphanumeric, `-`, `_`, `.`

---

## Real-World Use Cases

### Use Case 1: Blue-Green Deployment

**Blue (current version):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0
```

**Green (new version):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:2.0
```

**Service (switch traffic by changing selector):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue    # ← Change to 'green' to switch traffic
  ports:
  - port: 80
    targetPort: 8080
```

---

### Use Case 2: Multi-Tenant Application

```yaml
# Tenant A
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-tenant-a
spec:
  selector:
    matchLabels:
      app: myapp
      tenant: tenant-a
  template:
    metadata:
      labels:
        app: myapp
        tenant: tenant-a
    spec:
      containers:
      - name: app
        image: myapp:1.0
        env:
        - name: TENANT_ID
          value: tenant-a

---
# Tenant B
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-tenant-b
spec:
  selector:
    matchLabels:
      app: myapp
      tenant: tenant-b
  template:
    metadata:
      labels:
        app: myapp
        tenant: tenant-b
    spec:
      containers:
      - name: app
        image: myapp:1.0
        env:
        - name: TENANT_ID
          value: tenant-b
```

**List resources by tenant:**
```bash
kubectl get all -l tenant=tenant-a
kubectl get all -l tenant=tenant-b
```

---

### Use Case 3: Environment-Based Selection

```yaml
# Development
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dev
  namespace: development
spec:
  selector:
    matchLabels:
      app: myapp
      environment: development
  template:
    metadata:
      labels:
        app: myapp
        environment: development
    spec:
      containers:
      - name: app
        image: myapp:latest

---
# Production
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-prod
  namespace: production
spec:
  selector:
    matchLabels:
      app: myapp
      environment: production
  template:
    metadata:
      labels:
        app: myapp
        environment: production
    spec:
      containers:
      - name: app
        image: myapp:1.0.0
```

---

## Advanced Selector Examples

### Complex matchExpressions

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex-app
spec:
  selector:
    matchLabels:
      app: myapp
    matchExpressions:
    # Environment must be production OR staging
    - key: environment
      operator: In
      values:
      - production
      - staging
    # Tier must NOT be database
    - key: tier
      operator: NotIn
      values:
      - database
    # Must have a version label (any value)
    - key: version
      operator: Exists
    # Must NOT have a deprecated label
    - key: deprecated
      operator: DoesNotExist
```

**This selects Pods where:**
- `app=myapp` (required)
- `environment` is `production` OR `staging`
- `tier` is NOT `database`
- Has a `version` label
- Does NOT have a `deprecated` label

---

## Troubleshooting Selectors

### Problem 1: Pods Not Managed by Deployment

```bash
# Check deployment
kubectl get deployment myapp

# Output shows 0/3 ready
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
myapp   0/3     3            0           1m
```

**Diagnosis:**
```bash
# Check deployment selector
kubectl describe deployment myapp | grep -A 5 Selector

# Check pod labels
kubectl get pods -l app=myapp --show-labels
```

**Common cause:** Selector doesn't match Pod labels.

---

### Problem 2: Service Not Routing Traffic

```bash
# Service has no endpoints
kubectl get endpoints myapp-service

# Output shows no endpoints
NAME            ENDPOINTS   AGE
myapp-service   <none>      5m
```

**Diagnosis:**
```bash
# Check service selector
kubectl describe service myapp-service | grep Selector

# Check if pods exist with matching labels
kubectl get pods -l app=myapp
```

**Solution:** Ensure Service selector matches Pod labels.

---

## Summary

### Labels
- ✅ Key-value pairs for identification
- ✅ Attached to any Kubernetes object
- ✅ Used for organization and grouping
- ✅ Multiple labels per object allowed
- ✅ Not unique across objects

### Selectors
- ✅ Query mechanism to find objects
- ✅ Match based on labels
- ✅ Used by Deployments, Services, etc.
- ✅ Two types: equality-based and set-based
- ✅ Immutable once created (for Deployments/Services)

### Key Relationship
```
Labels (on Pods) ← matched by → Selectors (in Deployment/Service)
```

---

## Quick Reference

### Common Label Keys
```yaml
app:                          # Application name
version:                      # Application version
environment:                  # dev/staging/prod
tier:                        # frontend/backend/cache
component:                   # web/api/worker
release:                     # stable/canary/beta
team:                        # Owning team
```

### Common Selector Patterns
```yaml
# Simple
selector:
  matchLabels:
    app: myapp

# With version
selector:
  matchLabels:
    app: myapp
    version: v1

# Complex
selector:
  matchLabels:
    app: myapp
  matchExpressions:
  - key: environment
    operator: In
    values: [production, staging]
```

---

## Related Concepts

- **Annotations**: Like labels but for non-identifying metadata
- **Node Selectors**: Select nodes for Pod scheduling
- **Affinity Rules**: Advanced scheduling based on labels
- **Network Policies**: Use selectors to define traffic rules

---

## Resources

- **Project 01** - Basic Pod labels
- **Project 02** - Deployment selectors in action
- **Project 03** - Service selectors for traffic routing
- [Kubernetes Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
