# Service Type in Kubernetes

### 1. ClusterIP
- Default service type
- Exposes service on a cluster-internal IP
- Accessible only within the cluster    

### 2. NodePort
- Exposes service on each Node's IP at a static port (the NodePort)
- Accessible from outside the cluster using `<NodeIP>:<NodePort>`