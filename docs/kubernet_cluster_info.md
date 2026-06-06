# Kubernetes Cluster Information

The output below indicates that the Kubernetes cluster is running and the control plane components are reachable.

### Check Cluster Information

```bash
kubectl cluster-info
```

### output

```text
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

## What This Tells You

### 1. Control Plane is Running

```text
https://127.0.0.1:6443
```

Port `6443` is used by the **Kubernetes API Server**.

`kubectl` communicates with the **API Server**, which acts as the entry point to the Kubernetes cluster.

```text
kubectl
    ↓
API Server (6443)
    ↓
├── Scheduler
├── Controller Manager
└── etcd
```

#### Components

* **API Server** – Receives and processes all Kubernetes requests.
* **Scheduler** – Assigns Pods to Nodes.
* **Controller Manager** – Maintains the desired cluster state.
* **etcd** – Stores cluster configuration and state.

---

### 2. CoreDNS is Running

**CoreDNS** provides DNS-based service discovery inside the cluster.

When one Pod needs to communicate with another Service, it uses a DNS name instead of an IP address.

Example:

```text
my-service.default.svc.cluster.local
```

CoreDNS resolves the service name to the corresponding Service ClusterIP.

```text
Pod A
  ↓
my-service.default.svc.cluster.local
  ↓
CoreDNS
  ↓
Service ClusterIP
  ↓
Target Pods
```

---

## Cluster Communication Flow

```text
kubectl
    │
    ▼
API Server (127.0.0.1:6443)
    │
    ├── Scheduler
    ├── Controller Manager
    ├── etcd
    └── CoreDNS
            │
            ▼
          Pods
```

## Useful Verification Commands

### Check Nodes

```bash
kubectl get nodes
```

### Output

```text
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   10d   v1.32.2
```

### Check Pods in All Namespaces

```bash
kubectl get pods -A
```

### Output

```text
NAMESPACE     NAME                                     READY   STATUS    RESTARTS        AGE
aml           ai-case-summarization-dcfbbc7d5-5p2wf    1/1     Running   1 (5m44s ago)   4d3h
aml           ai-case-summarization-dcfbbc7d5-nrv9m    1/1     Running   1 (5m44s ago)   4d3h
default       hello-kubernetes-c7b8d77b9-tj4lp         1/1     Running   1 (5m44s ago)   4d9h
kube-system   coredns-668d6bf9bc-4vk62                 1/1     Running   2 (5m44s ago)   10d
kube-system   coredns-668d6bf9bc-pq8ln                 1/1     Running   2 (5m44s ago)   10d
kube-system   etcd-docker-desktop                      1/1     Running   2 (5m44s ago)   10d
kube-system   kube-apiserver-docker-desktop            1/1     Running   2 (5m44s ago)   10d
kube-system   kube-controller-manager-docker-desktop   1/1     Running   2 (5m44s ago)   10d
kube-system   kube-proxy-gfjr5                         1/1     Running   2 (5m44s ago)   10d
kube-system   kube-scheduler-docker-desktop            1/1     Running   3 (5m44s ago)   10d
kube-system   storage-provisioner                      1/1     Running   6 (5m4s ago)    10d
kube-system   vpnkit-controller                        1/1     Running   2 (5m44s ago)   10d
```

### Check Namespaces

```bash
kubectl get namespaces
```

### Output

```text
kubectl get namespaces
NAME              STATUS   AGE
aml               Active   4d7h
default           Active   10d
kube-node-lease   Active   10d
kube-public       Active   10d
kube-system       Active   10d
```

### List Available Resource Types

```bash
kubectl api-resources
```

### View Kubernetes Version

```bash
kubectl version
```

---

## Next Learning Step

Create and inspect a Pod:

```bash
kubectl run nginx --image=nginx
kubectl get pods
kubectl describe pod nginx
```

This helps you understand the Kubernetes resource flow:

```text
Cluster
  ↓
Node
  ↓
Pod
  ↓
Container
```
