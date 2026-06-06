# Kubernet-from-zero-to-hero


# Kubernetes Zero to Hero Roadmap 🚀

Complete Beginner-to-Production Kubernetes Learning Plan using AWS EC2, Docker, FastAPI, Helm, and ArgoCD.

---

# 📌 Goal

> we will create multiple projects from simple to complex, covering all essential Kubernetes concepts and practices. By the end of this roadmap, you will have hands-on experience with deploying and managing applications on Kubernetes, using AWS EC2 for infrastructure, and implementing GitOps with ArgoCD.

---

Technologies stacked in this roadmap:
- FastAPI
- Redis
- Docker
- k8s (Kubernetes)
- AWS EC2
- Helm
- ArgoCD
- PostgreSQL
- Prometheus
- Grafana
- NGINX Ingress Controller.

--- 

projects naming convention:
- `k8s-01-hello-world`: Basic Kubernetes deployment




This repository is designed to help beginners learn:

* Docker
* Kubernetes
* Container Orchestration
* Scaling
* Self-Healing
* AWS EC2 Cluster Setup
* Helm
* Ingress
* Monitoring
* GitOps using ArgoCD

By the end of this roadmap, you will be able to:

✅ Deploy applications on Kubernetes
✅ Scale applications automatically
✅ Handle node failures
✅ Use rolling updates
✅ Build production-ready deployments
✅ Deploy FastAPI applications
✅ Use Helm charts
✅ Use ArgoCD for GitOps

---

# 📚 Learning Roadmap

| Phase | Topic                      | Status |
| ----- | -------------------------- | ------ |
| 0     | Linux + Networking Basics  | ⬜      |
| 1     | Docker Deep Dive           | ⬜      |
| 2     | Kubernetes Fundamentals    | ⬜      |
| 3     | Local Kubernetes Practice  | ⬜      |
| 4     | AWS EC2 Kubernetes Cluster | ⬜      |
| 5     | FastAPI Deployment         | ⬜      |
| 6     | Scaling + Orchestration    | ⬜      |
| 7     | Helm                       | ⬜      |
| 8     | Ingress + Networking       | ⬜      |
| 9     | Monitoring + Logging       | ⬜      |
| 10    | ArgoCD + GitOps            | ⬜      |
| 11    | Production Best Practices  | ⬜      |

---

# 🧠 What is Kubernetes?

Kubernetes is a container orchestration platform.

It helps automate:

* deployment
* scaling
* load balancing
* self healing
* rolling updates
* container management

---

# 🏗️ Final Architecture

```text
                    INTERNET
                        │
                AWS Load Balancer
                        │
                    Ingress
                        │
        ┌───────────────┴───────────────┐
        │                               │
    FastAPI Pod 1                  FastAPI Pod 2
        │                               │
        └───────────────┬───────────────┘
                        │
                    Redis Service
                        │
                  PostgreSQL DB
```

---

# ☁️ AWS Infrastructure

## Recommended Beginner Cluster

| Node          | Purpose                  | Instance Type |
| ------------- | ------------------------ | ------------- |
| Master Node   | Kubernetes Control Plane | t3.medium     |
| Worker Node 1 | Application Pods         | t3.medium     |
| Worker Node 2 | Application Pods         | t3.medium     |

---

# 📦 Tech Stack

| Tool          | Purpose                    |
| ------------- | -------------------------- |
| Docker        | Containerization           |
| Kubernetes    | Orchestration              |
| k3s           | Lightweight Kubernetes     |
| Helm          | Kubernetes Package Manager |
| ArgoCD        | GitOps Deployment          |
| FastAPI       | Backend API                |
| Redis         | Cache / Queue              |
| PostgreSQL    | Database                   |
| Prometheus    | Monitoring                 |
| Grafana       | Visualization              |
| NGINX Ingress | Traffic Routing            |

---

Practice:

* scaling
* orchestration
* self healing
* rolling updates
* autoscaling
* monitoring

This will teach real-world Kubernetes deployment skills.

