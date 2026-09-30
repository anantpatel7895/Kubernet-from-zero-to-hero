# Kubernetes NodePort — Detailed Guide

## 1. What is NodePort?

`NodePort` is a Kubernetes Service type that exposes a Service on a specific port on **every Kubernetes node**.

It allows clients outside the cluster to access a Kubernetes Service using:

```text
<NodeIP>:<NodePort>
```

Example:

```text
192.168.1.10:30080
```

The traffic then reaches the Kubernetes Service and eventually one of its backend Pods.

Basic architecture:

```text
External Client
      |
      | NodeIP:30080
      v
+-------------------+
| Kubernetes Node   |
|                   |
| NodePort :30080   |
+---------+---------+
          |
          v
      Service
          |
     +----+----+
     |         |
     v         v
   Pod A     Pod B
```

---

# 2. Why Do We Need NodePort?

By default, a Kubernetes Service is:

```text
ClusterIP
```

A ClusterIP Service is normally accessible only from inside the Kubernetes cluster.

Example:

```text
Pod A
  |
  | request
  v
Service
  |
  v
Pod B
```

An external client cannot normally access the ClusterIP directly.

NodePort adds an externally reachable entry point:

```text
External Client
      |
      v
NodeIP:NodePort
      |
      v
Service
      |
      v
Pods
```

---

# 3. NodePort in the Kubernetes Service Types

Kubernetes Services commonly use:

```text
ClusterIP
NodePort
LoadBalancer
ExternalName
```

The relationship can be visualized as:

```text
ClusterIP
    |
    | provides internal Service networking
    v

NodePort
    |
    | adds node-level external access
    v

LoadBalancer
    |
    | typically adds an external/cloud load balancer
    v
External clients
```

NodePort is therefore an extension of the Service networking model.

---

# 4. Basic NodePort YAML

Example:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: ml-service

spec:
  type: NodePort

  selector:
    app: ml-api

  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30080
```

The important fields are:

```yaml
type: NodePort

ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30080
```

---

# 5. The Three Important Ports

This is the most important concept when learning NodePort.

There are three different ports:

```text
nodePort
port
targetPort
```

For example:

```yaml
ports:
  - port: 8000
    targetPort: 9000
    nodePort: 30080
```

Traffic flows approximately like:

```text
External Client
      |
      | :30080
      v
    Node
      |
      v
  Service :8000
      |
      v
    Pod :9000
```

Therefore:

```text
NodePort  → Service Port → Pod Target Port
  30080   →     8000     →     9000
```

---

# 6. What is `nodePort`?

`nodePort` is the port exposed on the Kubernetes nodes.

Example:

```yaml
nodePort: 30080
```

A client can connect to:

```text
<NodeIP>:30080
```

Example:

```text
192.168.1.10:30080
```

The request enters the Kubernetes networking system through that NodePort.

---

# 7. What is `port`?

`port` is the port exposed by the Kubernetes Service.

Example:

```yaml
port: 8000
```

Conceptually:

```text
NodePort
   |
   v
Service :8000
```

The Service uses this port as its own service port.

---

# 8. What is `targetPort`?

`targetPort` specifies the port on the backend Pod where the application is listening.

Example:

```yaml
targetPort: 9000
```

If the application inside the Pod listens on:

```text
9000
```

then:

```text
Service
   |
   | targetPort: 9000
   v
Pod :9000
```

---

# 9. Complete Port Mapping

Suppose:

```yaml
port: 8000
targetPort: 9000
nodePort: 30080
```

The conceptual traffic flow is:

```text
Client
  |
  | NodeIP:30080
  v
Node
  |
  | NodePort
  v
Service :8000
  |
  | targetPort
  v
Pod :9000
```

Remember:

```text
30080 → 8000 → 9000
```

---

# 10. Common Case: All Ports Are Different

Example:

```yaml
ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

Traffic:

```text
Client
   |
   | NodeIP:30080
   v
Node
   |
   v
Service :80
   |
   v
Pod :8080
```

This is perfectly valid.

---

# 11. Common Case: Service and Pod Use the Same Port

Very common:

```yaml
ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30080
```

Flow:

```text
30080
  |
  v
8000
  |
  v
8000
```

Meaning:

```text
NodePort = 30080
Service Port = 8000
Application Port = 8000
```

---

# 12. Why Isn't NodePort Usually the Same as the Application Port?

Suppose your application listens on:

```text
8000
```

You cannot normally just expose:

```text
NodeIP:8000
```

using a NodePort Service because Kubernetes reserves a separate NodePort range by default.

For example:

```text
Application:
8000

NodePort:
30080
```

So:

```text
NodeIP:30080
      |
      v
Service:8000
      |
      v
Pod:8000
```

---

# 13. Default NodePort Range

Kubernetes normally allocates NodePorts from:

```text
30000 - 32767
```

For example:

```text
30080
30081
30100
31000
32000
```

are within the default range.

You can specify a particular NodePort:

```yaml
nodePort: 30080
```

If you omit it:

```yaml
ports:
  - port: 8000
    targetPort: 8000
```

Kubernetes can automatically allocate a NodePort.

---

# 14. Automatically Assigned NodePort

Example:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: ml-service

spec:
  type: NodePort

  selector:
    app: ml-api

  ports:
    - port: 8000
      targetPort: 8000
```

You didn't specify:

```yaml
nodePort:
```

Kubernetes might assign:

```text
31234
```

You can see it using:

```bash
kubectl get svc
```

Example:

```text
NAME         TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)
ml-service   NodePort   10.96.20.10    <none>        8000:31234/TCP
```

Here:

```text
Service Port = 8000
NodePort     = 31234
```

---

# 15. NodePort Architecture

Suppose we have two nodes:

```text
Node 1
10.0.0.10

Node 2
10.0.0.11
```

Service:

```text
NodePort = 30080
```

The NodePort is exposed on both nodes:

```text
10.0.0.10:30080
10.0.0.11:30080
```

Architecture:

```text
                 Kubernetes Cluster

        +----------------+    +----------------+
        |    Node 1      |    |    Node 2      |
        |                |    |                |
        | :30080         |    | :30080         |
        |                |    |                |
        +-------+--------+    +--------+-------+
                |                      |
                +----------+-----------+
                           |
                        Service
                           |
                  +--------+--------+
                  |        |        |
                  v        v        v
                Pod A    Pod B    Pod C
```

---

# 16. Does Every Node Need a Pod?

No.

This is a very important point.

Suppose:

```text
Node 1
  |
  +-- Pod A

Node 2
  |
  +-- No Pod
```

The NodePort can still exist on Node 2.

So:

```text
Node 2:30080
```

can potentially receive traffic even though Node 2 doesn't have a backend Pod.

Kubernetes networking can route the traffic to an appropriate backend Pod.

---

# 17. Example: Pod on Another Node

Suppose:

```text
Node 1                         Node 2
+----------------+             +----------------+
|                |             |                |
| NodePort       |             |                |
| :30080         |             |                |
|                |             |    Pod A       |
|                |             |    :8000       |
+-------+--------+             +--------+-------+
        |                               |
        +-------------------------------+
                        |
                        v
                     Service
```

Client sends:

```text
Node1:30080
```

but the backend Pod is on Node 2.

Traffic can be forwarded across the cluster:

```text
Client
  |
  v
Node 1:30080
  |
  v
Service networking
  |
  v
Node 2
  |
  v
Pod A:8000
```

The client does not need to know where Pod A is running.

---

# 18. NodePort Does Not Belong to a Pod

A common misunderstanding is:

> "NodePort is the port of the Pod."

Incorrect.

NodePort belongs to the:

```text
Service
```

The Pod has:

```text
targetPort
```

Conceptually:

```text
NodePort
    ↓
Service
    ↓
targetPort
    ↓
Pod
```

---

# 19. NodePort and Service Selector

NodePort still uses a normal Service selector.

Example:

```yaml
spec:
  type: NodePort

  selector:
    app: ml-api
```

Pods:

```yaml
metadata:
  labels:
    app: ml-api
```

The Service finds Pods using:

```text
app=ml-api
```

So NodePort doesn't bypass normal Service selection.

---

# 20. NodePort and EndpointSlices

The Service identifies backend Pods.

Kubernetes maintains backend information through EndpointSlices.

Conceptually:

```text
NodePort
   |
   v
Service
   |
   v
EndpointSlice
   |
   +---- Pod A
   +---- Pod B
   +---- Pod C
```

You can inspect them:

```bash
kubectl get endpointslices
```

---

# 21. NodePort Traffic Flow

Let's go through a complete request.

Suppose:

```text
Node IP = 192.168.1.10
NodePort = 30080
Service Port = 8000
Target Port = 8080
```

Client sends:

```text
http://192.168.1.10:30080
```

### Step 1

Packet arrives at:

```text
Node 1:30080
```

### Step 2

Kubernetes networking recognizes the NodePort.

### Step 3

Traffic is associated with:

```text
Service
```

### Step 4

Service selects an eligible backend Pod.

### Step 5

Traffic is sent to:

```text
Pod:8080
```

Complete flow:

```text
192.168.1.10:30080
        |
        v
      Node
        |
        v
     Service
      :8000
        |
        v
   Selected Pod
      :8080
```

---

# 22. What Implements the Networking?

Kubernetes Service networking is implemented by Kubernetes networking components and the cluster's networking implementation.

Historically, `kube-proxy` has been the component commonly responsible for programming node-level rules for Services.

Depending on the cluster and networking stack, implementation can use technologies such as:

```text
iptables
IPVS
eBPF
```

For learning purposes, remember:

```text
NodePort
   ↓
Node networking
   ↓
Service
   ↓
Backend Pod
```

The exact implementation can vary by Kubernetes distribution and networking plugin.

---

# 23. kube-proxy Mental Model

A simplified model:

```text
                    Node
        +--------------------------+
        |                          |
        |  NodePort :30080         |
        |       |                  |
        |       v                  |
        |   Service rules         |
        |       |                  |
        +-------+------------------+
                |
                v
             Pod IP
```

`kube-proxy` can program the node's networking rules so that traffic destined for a Service or NodePort is redirected toward an appropriate backend.

---

# 24. NodePort and Load Balancing

Suppose:

```text
Service
   |
   +---- Pod A
   +---- Pod B
   +---- Pod C
```

Traffic entering the NodePort can be distributed across eligible backend Pods.

Conceptually:

```text
Request 1 → Pod A
Request 2 → Pod C
Request 3 → Pod B
Request 4 → Pod A
```

Do not assume strict round-robin ordering.

The actual selection behavior depends on the Kubernetes networking implementation.

---

# 25. `externalTrafficPolicy`

NodePort introduces an important configuration:

```yaml
externalTrafficPolicy
```

There are two common values:

```text
Cluster
Local
```

---

# 26. `externalTrafficPolicy: Cluster`

Example:

```yaml
spec:
  type: NodePort

  externalTrafficPolicy: Cluster
```

Conceptually:

```text
Client
   |
   v
Node 1
   |
   |-------------------+
   |                   |
   v                   v
Pod on Node 1       Pod on Node 2
```

The receiving node can forward traffic to a backend Pod on another node.

Advantages:

* Backend Pods can be selected across the cluster.
* Traffic can reach Pods even when the receiving node has no local backend.

Potential consequence:

* The original client source IP may not always be preserved through the full path.

---

# 27. `externalTrafficPolicy: Local`

Example:

```yaml
spec:
  type: NodePort

  externalTrafficPolicy: Local
```

Conceptually:

```text
Client
   |
   v
Node 1
   |
   v
Pod on Node 1
```

The node prefers/uses Pods local to that node for external traffic.

This can help preserve the original client source IP.

But there is an important consequence:

```text
Node 1
   |
   +-- No local Pod
```

If traffic arrives at Node 1 and there is no suitable local backend Pod, that traffic may not be handled successfully through that NodePort path.

---

# 28. Cluster vs Local

|                                  | `Cluster`   | `Local`                      |
| -------------------------------- | ----------- | ---------------------------- |
| Can route to Pod on another node | Yes         | No                           |
| Can use any cluster backend      | Yes         | No                           |
| Source IP preservation           | May be lost | Better preserved             |
| Requires local Pod               | No          | Yes                          |
| Cross-node traffic               | Possible    | Avoided for external traffic |

---

# 29. NodePort and Source IP

Suppose a client has:

```text
Client IP:
203.0.113.10
```

The request reaches:

```text
Node:30080
```

Depending on the traffic policy and network path, the backend application may see:

```text
203.0.113.10
```

or may see another address associated with the cluster/node networking.

This is why:

```yaml
externalTrafficPolicy: Local
```

can matter when the application needs the original client source IP.

---

# 30. NodePort and Health Checks

When NodePort is used behind an external load balancer, the load balancer may need to determine which nodes can receive traffic.

The exact health-check behavior depends on:

* Cloud provider
* Load balancer implementation
* Service configuration
* `externalTrafficPolicy`

This becomes particularly important with:

```yaml
externalTrafficPolicy: Local
```

because a node without a local backend Pod may not be an appropriate destination for external traffic.

---

# 31. NodePort and LoadBalancer

A common cloud architecture looks like:

```text
Internet
   |
   v
Cloud Load Balancer
   |
   v
NodePort
   |
   v
Service
   |
   v
Pods
```

Conceptually:

```text
              Cloud
        +----------------+
        | Load Balancer  |
        +-------+--------+
                |
                v
       +----------------+
       | Kubernetes     |
       | NodePort       |
       +-------+--------+
               |
               v
            Service
               |
        +------+------+------+
        |      |      |      |
        v      v      v      v
       Pod    Pod    Pod    Pod
```

A `LoadBalancer` Service can provision external load-balancer infrastructure depending on the environment.

---

# 32. NodePort vs Port Forward

These are very different.

## Port Forward

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Flow:

```text
Your Laptop
localhost:8000
      |
      v
kubectl
      |
      v
Service
      |
      v
Pod
```

Characteristics:

```text
Temporary
Developer-oriented
Requires kubectl
Not normally a production exposure mechanism
```

---

## NodePort

```text
Client
   |
   v
NodeIP:30080
   |
   v
Service
   |
   v
Pod
```

Characteristics:

```text
Actual Kubernetes Service exposure
Accessible through node networking
Can be used by external clients
Does not require kubectl running on the client
```

---

# 33. NodePort vs ClusterIP

## ClusterIP

```text
Pod / internal client
       |
       v
ClusterIP Service
       |
       v
Pod
```

Only internal cluster access is normally intended.

## NodePort

```text
External client
       |
       v
NodeIP:30080
       |
       v
Service
       |
       v
Pod
```

Provides node-level external access.

---

# 34. NodePort vs Ingress

NodePort:

```text
Client
   |
   v
NodeIP:30080
   |
   v
Service
```

Ingress:

```text
Client
   |
   v
Ingress Controller
   |
   +--------+--------+
   |        |        |
   v        v        v
Service A Service B Service C
```

Ingress is designed for HTTP/HTTPS routing and can provide host/path-based routing.

Example:

```text
example.com/api
      |
      v
API Service

example.com/ml
      |
      v
ML Service
```

NodePort does not provide this HTTP routing abstraction by itself.

---

# 35. NodePort and DNS

A NodePort does not normally give you a special external DNS name.

You typically access it using:

```text
Node IP + NodePort
```

Example:

```text
192.168.1.10:30080
```

If you want:

```text
api.example.com
```

you generally introduce DNS plus an external load balancer, Ingress, Gateway, or another appropriate exposure mechanism.

---

# 36. NodePort with Multiple Nodes

Suppose you have:

```text
Node 1 = 10.0.0.10
Node 2 = 10.0.0.11
Node 3 = 10.0.0.12
```

NodePort:

```text
30080
```

Then conceptually:

```text
10.0.0.10:30080
10.0.0.11:30080
10.0.0.12:30080
```

can act as entry points to the Service.

Architecture:

```text
                 Service
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
      Node 1      Node 2      Node 3
      :30080      :30080      :30080
        |           |           |
        +-----------+-----------+
                    |
                    v
                  Pods
```

---

# 37. Does NodePort Create a Port on the Physical Machine?

Conceptually, yes, but don't think of it as:

> "Kubernetes starts a normal application process listening on port 30080."

Instead, Kubernetes networking configures the node so that traffic destined for the NodePort is handled by the Service networking path.

Depending on the networking implementation, this can involve:

```text
iptables
IPVS
eBPF
```

So NodePort is primarily a **networking rule**, not a normal application server process.

---

# 38. NodePort Does Not Mean the Container Listens on 30080

This is another important distinction.

Suppose:

```text
NodePort = 30080
```

Your application still listens on:

```text
8000
```

The container does not need:

```text
listen(30080)
```

Instead:

```text
Node :30080
      |
      ↓
Service
      |
      ↓
Pod :8000
```

---

# 39. Example: FastAPI

FastAPI:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}
```

Run:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

Inside Pod:

```text
FastAPI :8000
```

Service:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: fastapi-service

spec:
  type: NodePort

  selector:
    app: fastapi

  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30080
```

External request:

```text
http://<NodeIP>:30080/health
```

Flow:

```text
Client
  |
  | :30080
  v
Node
  |
  v
NodePort
  |
  v
Service :8000
  |
  v
Pod :8000
  |
  v
FastAPI
```

---

# 40. Example: ML Inference API

Suppose your model server listens on:

```text
8000
```

Deployment:

```text
3 replicas
```

Architecture:

```text
                 NodePort :30080
                       |
                       v
                    Service
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
      ML Pod          ML Pod         ML Pod
      :8000           :8000          :8000
        |              |              |
      Model           Model          Model
        |              |              |
      GPU             GPU            GPU
```

Client:

```text
POST http://<NodeIP>:30080/predict
```

Service chooses an eligible backend.

---

# 41. NodePort in a Multi-Node ML Cluster

Suppose:

```text
Node 1
  |
  +-- ML Pod A

Node 2
  |
  +-- ML Pod B

Node 3
  |
  +-- ML Pod C
```

NodePort:

```text
30080
```

External client can target a node:

```text
Node1:30080
Node2:30080
Node3:30080
```

The request can then reach the appropriate backend Pod according to the Service/networking configuration.

---

# 42. Why NodePort Can Be Awkward for Production

NodePort exposes a relatively low-level endpoint:

```text
NodeIP:30080
```

Problems in larger production systems can include:

* Managing node addresses
* Managing firewall rules
* Exposing arbitrary high ports
* TLS termination
* Host/path routing
* Load-balancer integration
* Source IP behavior
* Node failure handling
* Security policies

Therefore, production systems commonly place another layer in front:

```text
Internet
   |
   v
Load Balancer
   |
   v
Ingress / Gateway
   |
   v
Service
   |
   v
Pods
```

---

# 43. NodePort in Local Kubernetes

NodePort is useful when learning Kubernetes locally.

Examples:

```text
Minikube
Kind
Docker Desktop Kubernetes
```

For example, depending on the environment:

```bash
kubectl get svc
```

might show:

```text
NAME          TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)
ml-service    NodePort   10.96.10.20    <none>        8000:30080/TCP
```

You can then use the environment-specific node address to access:

```text
<NodeIP>:30080
```

---

# 44. Useful Commands

## Create the Service

```bash
kubectl apply -f service.yaml
```

## List Services

```bash
kubectl get svc
```

or:

```bash
kubectl get services
```

## Detailed information

```bash
kubectl describe svc ml-service
```

## Get YAML

```bash
kubectl get svc ml-service -o yaml
```

## Check Pods

```bash
kubectl get pods -o wide
```

The `-o wide` output helps you see which node each Pod is running on.

## Check EndpointSlices

```bash
kubectl get endpointslices
```

## Check endpoints

```bash
kubectl get endpoints
```

---

# 45. Debugging NodePort

If:

```text
NodeIP:30080
```

doesn't work, check the following.

### 1. Is the Service present?

```bash
kubectl get svc
```

### 2. Is it actually NodePort?

```bash
kubectl get svc ml-service
```

Look for:

```text
TYPE
NodePort
```

### 3. Is the NodePort assigned?

```bash
kubectl get svc ml-service
```

Example:

```text
8000:30080/TCP
```

### 4. Are Pods running?

```bash
kubectl get pods
```

### 5. Are Pods ready?

```bash
kubectl get pods
```

Look for:

```text
READY
1/1
```

### 6. Do Service selectors match Pod labels?

```bash
kubectl describe svc ml-service
```

### 7. Does the Service have endpoints?

```bash
kubectl get endpoints ml-service
```

### 8. Can the application itself respond?

Check:

```bash
kubectl logs <pod-name>
```

### 9. Is the node/network/firewall allowing the NodePort?

A cloud security group, firewall, or network policy can prevent access even when the Kubernetes Service is correctly configured.

---

# 46. NodePort and Cloud Firewall

Suppose:

```text
NodePort = 30080
```

but the cloud VM's firewall blocks:

```text
TCP 30080
```

Then:

```text
Internet
   |
   X
Firewall
   |
   X
NodePort
```

The Kubernetes Service can be perfectly configured but the request still won't reach it.

Therefore external access requires both:

```text
Kubernetes networking
+
Infrastructure/network firewall access
```

---

# 47. NodePort and Security

If nodes are reachable from the Internet and you expose:

```text
30080
```

then the service may become externally reachable.

Therefore you should consider:

* Cloud security groups
* Firewall rules
* Network ACLs
* Authentication
* TLS
* Network policies
* Ingress/Gateway
* Internal vs external load balancers

Don't assume:

```text
NodePort
```

automatically means secure exposure.

---

# 48. NodePort and NetworkPolicy

A `NetworkPolicy` can restrict Pod traffic.

For example:

```text
NodePort
   |
   v
Service
   |
   v
NetworkPolicy
   |
   X
Pod
```

Whether traffic is allowed depends on the policies and networking plugin.

Therefore when debugging connectivity, consider both:

```text
Service configuration
+
NetworkPolicy
+
Node firewall
+
Cloud firewall
+
CNI/networking plugin
```

---

# 49. NodePort and Pod Readiness

Suppose:

```text
Pod starts
    |
    v
Model loading
    |
    v
GPU initialization
    |
    v
Model ready
```

During model loading, the Pod may be running but not ready.

Use readiness probes:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
```

The Service should route traffic only to eligible ready backends.

For ML workloads, readiness is particularly important because model loading can take significant time.

---

# 50. NodePort and Liveness Probe

Liveness answers:

> Is the application still alive?

Readiness answers:

> Can the application receive traffic?

Example:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
```

For an ML server:

```text
Pod starts
   |
   v
Model loading
   |
   +---- Liveness = OK
   |
   +---- Readiness = NOT READY
   |
   v
Model loaded
   |
   v
Readiness = READY
   |
   v
Service sends traffic
```

---

# 51. Important Interview Question

## Does NodePort directly connect the client to a Pod?

Not exactly.

The conceptual flow is:

```text
Client
  ↓
Node IP + NodePort
  ↓
Service networking
  ↓
Selected backend
  ↓
Pod
```

The Service abstraction remains in the path.

---

# 52. Important Interview Question

## Does NodePort create a new Pod?

No.

NodePort is a Service type.

```text
Deployment
    ↓
creates/manages Pods

Service
    ↓
provides networking

NodePort
    ↓
exposes Service through node ports
```

---

# 53. Important Interview Question

## Does NodePort mean the application must listen on the NodePort?

No.

Example:

```text
NodePort = 30080
Application = 8000
```

The application listens on:

```text
Pod:8000
```

not:

```text
Pod:30080
```

The networking layer translates/routes:

```text
Node:30080
     ↓
Service:8000
     ↓
Pod:8000
```

---

# 54. Important Interview Question

## Does every Node have the NodePort?

For a NodePort Service, Kubernetes makes the NodePort available through the node networking path on nodes, subject to the cluster's networking configuration.

Example:

```text
Node 1 → :30080
Node 2 → :30080
Node 3 → :30080
```

---

# 55. Important Interview Question

## What happens if the Pod is on Node 2 but the request arrives on Node 1?

With the default `externalTrafficPolicy: Cluster`, traffic can be routed across nodes:

```text
Client
  |
  v
Node 1:30080
  |
  v
Service networking
  |
  v
Node 2
  |
  v
Pod
```

With:

```yaml
externalTrafficPolicy: Local
```

external traffic is handled using local backend Pods, which also affects source-IP preservation and which nodes are suitable as external entry points.

---

# 56. Important Interview Question

## What is the difference between NodePort and LoadBalancer?

NodePort:

```text
Client
   |
   v
NodeIP:30080
   |
   v
Service
```

LoadBalancer:

```text
Client
   |
   v
External Load Balancer
   |
   v
Service
```

NodePort exposes a node-level port.

LoadBalancer integrates with an external load-balancing mechanism, commonly provided by a cloud platform.

---

# 57. Important Interview Question

## Why use Ingress instead of NodePort?

NodePort gives:

```text
NodeIP:30080
```

Ingress can provide:

```text
example.com/api
example.com/ml
example.com/auth
```

and can handle HTTP/HTTPS concerns such as:

* Host-based routing
* Path-based routing
* TLS termination
* Multiple backend Services

---

# 58. Complete Example

Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: ml-api

spec:
  replicas: 3

  selector:
    matchLabels:
      app: ml-api

  template:
    metadata:
      labels:
        app: ml-api

    spec:
      containers:
        - name: ml-api
          image: my-ml-api:1.0

          ports:
            - containerPort: 8000

          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
```

Service:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: ml-service

spec:
  type: NodePort

  selector:
    app: ml-api

  ports:
    - name: http
      port: 8000
      targetPort: 8000
      nodePort: 30080
```

Architecture:

```text
                         External Client
                               |
                               |
                        NodeIP:30080
                               |
                               v
                     +----------------+
                     |   NodePort     |
                     |    :30080      |
                     +-------+--------+
                             |
                             v
                      +-------------+
                      |   Service   |
                      |    :8000    |
                      +------+------+
                             |
                  +----------+----------+
                  |          |          |
                  v          v          v
               ML Pod     ML Pod     ML Pod
                :8000       :8000       :8000
                  |          |          |
                Model      Model      Model
                  |          |          |
                 GPU        GPU        GPU
```

Request:

```text
POST http://<NodeIP>:30080/predict
```

Traffic:

```text
Client
  ↓
NodeIP:30080
  ↓
NodePort
  ↓
Service:8000
  ↓
Selected ready Pod:8000
  ↓
FastAPI
  ↓
ML Model
  ↓
GPU
```

---

# 59. Final Mental Model

The most important diagram to remember:

```text
                 EXTERNAL CLIENT
                       |
                       |
                 NodeIP:30080
                       |
                       v
              +----------------+
              | Kubernetes     |
              | Node            |
              |                |
              | NodePort 30080 |
              +-------+--------+
                      |
                      v
                  SERVICE
                   :8000
                      |
             +--------+--------+
             |        |        |
             v        v        v
           POD A    POD B    POD C
           :8000    :8000    :8000
```

The three-port relationship:

```text
                 Node
                  |
             :30080
             nodePort
                  |
                  v
               Service
                :8000
                port
                  |
                  v
                 Pod
                :8000
             targetPort
```

### Remember these four rules

```text
1. NodePort is a Service type.

2. NodePort exposes the Service through a port on Kubernetes nodes.

3. nodePort is NOT the same thing as the Pod's application port.

4. Traffic flows conceptually:

   Client
      ↓
   NodeIP:NodePort
      ↓
   Service
      ↓
   Backend Pod
```

### One-line definition

> **NodePort is a Kubernetes Service type that exposes a Service on a port of the cluster's nodes, allowing external clients to reach the Service using `<NodeIP>:<NodePort>`.**
