# Kubernetes Learning Roadmap Through Projects

## Objective

Learn Kubernetes from scratch through hands-on projects that progressively introduce:

* Deployment
* Container Management
* Orchestration
* Service Discovery
* Load Balancing
* Self-Healing
* Scaling
* Rolling Updates
* Storage
* GitOps
* Production Deployments

---

# Project 01 - Hello Kubernetes

**Project Name**

```text
k8s-01-hello-world
```

## Goal

Deploy your first container on Kubernetes.

## Learn

* Kubernetes Cluster
* kubectl
* Pods
* YAML Basics
* Container Lifecycle

## Concepts Covered

* Container Management
* Pod Lifecycle

---

# Project 02 - FastAPI Deployment

**Project Name**

```text
k8s-02-fastapi
```

## Goal

Deploy a FastAPI application using Deployments.

## Learn

* Deployments
* ReplicaSets
* Labels
* Selectors

## Concepts Covered

* Deployment
* Container Orchestration

---

# Project 03 - Service Discovery & Load Balancing

**Project Name**

```text
k8s-03-services
```

## Goal

Expose FastAPI through Kubernetes Services.

## Learn

* ClusterIP
* NodePort
* Service Discovery

## Concepts Covered

* Load Balancing
* Networking
* Service Discovery

---

# Project 04 - Self Healing Applications

**Project Name**

```text
k8s-04-self-healing
```

## Goal

Understand how Kubernetes automatically recovers failed workloads.

## Learn

* ReplicaSets
* Desired State
* Pod Recovery

## Concepts Covered

* Self Healing
* Orchestration

---

# Project 05 - Horizontal Scaling

**Project Name**

```text
k8s-05-hpa-scaling
```

## Goal

Scale applications manually and automatically.

## Learn

* Scaling Deployments
* Metrics Server
* Horizontal Pod Autoscaler (HPA)

## Concepts Covered

* Scaling
* Resource Optimization

---

# Project 06 - Rolling Updates & Rollbacks

**Project Name**

```text
k8s-06-rolling-updates
```

## Goal

Deploy new versions without downtime.

## Learn

* Rolling Updates
* Rollbacks
* Deployment Strategies

## Concepts Covered

* Rolling Updates
* Release Management

---

# Project 07 - ConfigMaps & Secrets

**Project Name**

```text
k8s-07-configmaps-secrets
```

## Goal

Manage application configuration securely.

## Learn

* ConfigMaps
* Secrets
* Environment Variables

## Concepts Covered

* Configuration Management

---

# Project 08 - Persistent Storage

**Project Name**

```text
k8s-08-storage
```

## Goal

Persist data across Pod restarts.

## Learn

* Persistent Volumes (PV)
* Persistent Volume Claims (PVC)
* Storage Classes

## Concepts Covered

* Stateful Applications
* Storage Management

---

# Project 09 - Redis Deployment

**Project Name**

```text
k8s-09-redis
```

## Goal

Deploy Redis and connect it to FastAPI.

## Learn

* Multi-Service Applications
* Internal DNS
* Service Communication

## Concepts Covered

* Container Orchestration
* Service Discovery

---

# Project 10 - Ingress & Traffic Routing

**Project Name**

```text
k8s-10-ingress
```

## Goal

Expose applications through a single entry point.

## Learn

* Ingress Controller
* Host-Based Routing
* Path-Based Routing

## Concepts Covered

* Load Balancing
* Traffic Management

---

# Project 11 - Resource Management

**Project Name**

```text
k8s-11-resource-management
```

## Goal

Control CPU and Memory consumption.

## Learn

* Requests
* Limits
* Quality of Service (QoS)

## Concepts Covered

* Container Management
* Resource Allocation

---

# Project 12 - Health Checks

**Project Name**

```text
k8s-12-health-probes
```

## Goal

Implement health monitoring for applications.

## Learn

* Liveness Probe
* Readiness Probe
* Startup Probe

## Concepts Covered

* Self Healing
* Reliability

---

# Project 13 - Helm Packaging

**Project Name**

```text
k8s-13-helm
```

## Goal

Package Kubernetes resources using Helm.

## Learn

* Helm Charts
* Templates
* Values Files

## Concepts Covered

* Deployment Automation
* Reusability

---

# Project 14 - GitOps with ArgoCD

**Project Name**

```text
k8s-14-argocd
```

## Goal

Automate deployments using Git as the source of truth.

## Learn

* ArgoCD Applications
* Auto Sync
* Self Heal
* Prune

## Concepts Covered

* GitOps
* Continuous Deployment

---

# Project 15 - Monitoring Stack

**Project Name**

```text
k8s-15-monitoring
```

## Goal

Monitor applications and cluster health.

## Learn

* Prometheus
* Grafana
* Metrics Collection

## Concepts Covered

* Observability
* Monitoring

---

# Project 16 - Logging Stack

**Project Name**

```text
k8s-16-logging
```

## Goal

Centralize application and cluster logs.

## Learn

* Elasticsearch
* Kibana
* Log Collection

## Concepts Covered

* Logging
* Troubleshooting

---

# Project 17 - Production Platform

**Project Name**

```text
k8s-17-production-platform
```

## Goal

Build a complete production-ready Kubernetes platform.

## Architecture

```text
Internet
    │
Ingress
    │
Load Balancer
    │
FastAPI Deployment
    │
Service
    ├── Redis
    └── PostgreSQL
```

## Features Implemented

* Deployments
* Container Management
* Service Discovery
* Load Balancing
* Self Healing
* Rolling Updates
* Scaling
* Persistent Storage
* Monitoring
* Logging
* GitOps

## Concepts Covered

* Production Kubernetes
* High Availability
* Reliability
* Observability
* GitOps

---

# Learning Outcome Matrix

| Kubernetes Capability | Projects   |
| --------------------- | ---------- |
| Container Management  | 01, 02, 11 |
| Deployment            | 02, 13, 14 |
| Orchestration         | 02, 04, 09 |
| Service Discovery     | 03, 09     |
| Load Balancing        | 03, 10     |
| Self Healing          | 04, 12, 14 |
| Scaling               | 05         |
| Rolling Updates       | 06         |
| Storage Management    | 08         |
| Monitoring            | 15         |
| Logging               | 16         |
| GitOps                | 14         |
| Production Deployment | 17         |

---

# Final Learning Path

```text
k8s-01-hello-world
k8s-02-fastapi
k8s-03-services
k8s-04-self-healing
k8s-05-scaling
k8s-06-rolling-updates
k8s-07-configmaps-secrets
k8s-08-storage
k8s-09-redis
k8s-10-ingress
k8s-11-resource-management
k8s-12-health-probes
k8s-13-helm
k8s-14-argocd
k8s-15-monitoring
k8s-16-logging
k8s-17-production-platform
```
mkdir -p k8s-01-hello-world
cd k8s-01-hello-worldmkdir -p k8s-01-hello-world
cd k8s-01-hello-worldmkdir -p k8s-01-hello-world
cd k8s-01-hello-worldmkdir -p k8s-01-hello-world
cd k8s-01-hello-worldmkdir -p k8s-01-hello-world
cd k8s-01-hello-worldmkdir -p k8s-01-hello-world
cd k8s-01-hello-world
By completing these 17 projects, you will gain practical experience with the entire Kubernetes lifecycle—from deploying a single container to operating a production-grade platform using Helm, ArgoCD, monitoring, logging, scaling, and self-healing workloads.
