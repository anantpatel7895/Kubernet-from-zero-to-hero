# Kubernetes Namespace

## What is a Namespace?

A **Namespace** is a logical partition inside a Kubernetes cluster used to organize and isolate resources.

```text
Kubernetes Cluster
│
├── development
├── staging
└── production
```

## Why Use Namespaces?

Namespaces help with:

* **Organization** — separate resources by team, project, or environment.
* **Resource isolation** — keep resources logically separated.
* **Access control** — apply RBAC permissions per namespace.
* **Resource limits** — use `ResourceQuota` and `LimitRange`.
* **Name isolation** — the same resource name can exist in different namespaces.

Example:

```text
development/api
staging/api
production/api
```

## Common Commands

```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace development

# Get Pods in a namespace
kubectl get pods -n development

# Get all resources in a namespace
kubectl get all -n development

# Delete namespace
kubectl delete namespace development
```

## Namespace vs Node

```text
Namespace → Logical organization/isolation
Node      → Physical/virtual machine that runs Pods
```

Multiple namespaces can use the same Kubernetes nodes.

## Important

A Namespace **does not provide complete isolation by itself**.

For stronger isolation, Kubernetes commonly uses:

```text
Namespace
   +
RBAC
   +
ResourceQuota
   +
NetworkPolicy
```

## Key Takeaway

> **Namespace is a logical boundary used to organize Kubernetes resources and apply separate access, resource, and policy rules within the same cluster.**
