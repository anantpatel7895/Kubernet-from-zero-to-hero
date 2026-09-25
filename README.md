# Kubernet-from-zero-to-hero


# Kubernetes Zero to Hero Roadmap 🚀

Complete Beginner-to-Production Kubernetes Learning Plan using AWS EC2, Docker, FastAPI, Helm, and ArgoCD.

```
               kubectl
                    |
                    v
            +---------------+
            |  API Server   |
            +---------------+
              /     |      \
             /      |       \
            v       v        v
         etcd   Scheduler  Controller Manager
                              |
                              v
                           kubelet
                              |
                              v
                             Pods
```

The Kubernetes API Server is the central entry point of the cluster. Every component kubectl, kubelets, controllers, schedulers, and operators communicates with Kubernetes through the API Server.

# IMPORTANT POINTS
- In kubernet Each resource (ex- namespace, deployment, servide etc) have **name and labels** in the **metadata**.


# 3. Services

![services](./k8s-03-services/README.md)

### 3.1 The Problem

In Project 02, you learned that:
- Deployments create and manage Pods
- Pods can be deleted and recreated (self-healing)
- Each Pod gets a new IP address when **recreated**
- Pod IPs are ephemeral and change frequently

**Question:** How do you access Pods if their IPs keep changing? 🤔

**Answer:** Kubernetes Services! 🎯


# 11. Resource Management


