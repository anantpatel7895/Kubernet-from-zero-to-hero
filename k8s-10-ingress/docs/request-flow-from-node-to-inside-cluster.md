# How Traffic Reaches the Ingress NGINX Pod from a Node

One of the most confusing parts of Kubernetes networking is understanding what happens after a request reaches a worker node.

Many people understand:

```text
Internet
    ↓
DNS
    ↓
Load Balancer
    ↓
Worker Node
```

But then ask:

> How does the request move from the node to the Ingress NGINX pod?

The answer involves:

* NodePort Service
* kube-proxy
* Service Endpoints
* Cluster Networking (Calico/Flannel/Cilium)
* Pod IPs

---

# Example Setup

Assume the following Kubernetes cluster:

```text
Node-1 : 10.0.1.10
Node-2 : 10.0.1.11
Node-3 : 10.0.1.12
```

Ingress Controller pods:

```text
ingress-nginx-controller-1
  Pod IP: 10.244.1.5
  Running on Node-1

ingress-nginx-controller-2
  Pod IP: 10.244.3.8
  Running on Node-3
```

Ingress Service:

```yaml
kind: Service
metadata:
  name: ingress-nginx-controller

spec:
  type: NodePort
```

Kubernetes assigns:

```text
ClusterIP : 10.96.15.20
NodePort  : 32080
```

---

# Step 1: User Sends Request

User opens:

```text
https://myapp.com
```

Browser performs:

```text
DNS Lookup
   ↓
Load Balancer IP
```

Browser connects:

```text
LoadBalancerIP:443
```

---

# Step 2: Load Balancer Forwards to a Node

Load Balancer has backend targets:

```text
Node-1:32080
Node-2:32080
Node-3:32080
```

It chooses one node.

Example:

```text
Load Balancer
      ↓
Node-2:32080
```

At this point the packet has reached the Linux server.

---

# Step 3: kube-proxy Receives the Traffic

Every Kubernetes node runs:

```text
kubelet
kube-proxy
container runtime
```

`kube-proxy` watches Services and Endpoints.

It creates networking rules inside Linux.

These rules are usually implemented using:

```text
iptables
IPVS
eBPF (via Cilium)
```

---

# Step 4: NodePort Rule Matches

When traffic arrives:

```text
Node-2:32080
```

Linux networking checks the rules installed by kube-proxy.

Conceptually:

```text
IF destination port = 32080
THEN route to ingress-nginx-controller Service
```

This mapping is created automatically by Kubernetes.

---

# Step 5: Service Resolves to Endpoints

The Service itself is not a process.

A Service is mainly:

```text
Virtual IP
+
Load balancing rules
```

Kubernetes knows the Service endpoints:

```text
ingress-nginx-controller

Endpoints:

10.244.1.5
10.244.3.8
```

These endpoint IPs belong to the Ingress Controller pods.

---

# Step 6: Service Selects a Pod

The Service chooses one endpoint.

Example:

```text
Selected Endpoint:

10.244.1.5
```

which corresponds to:

```text
Ingress NGINX Pod
Running on Node-1
```

---

# Step 7: Packet Destination is Rewritten

Originally:

```text
Destination:
Node-2:32080
```

After kube-proxy:

```text
Destination:
10.244.1.5:80
```

The packet is rewritten to target the selected pod.

This process is called:

```text
DNAT
(Destination Network Address Translation)
```

---

# Step 8: Cluster Network Delivers the Packet

The pod is not on Node-2.

It is on:

```text
Node-1
```

Kubernetes networking plugins make Pod IPs reachable across nodes.

Examples:

```text
Calico
Flannel
Cilium
Weave
```

The packet travels:

```text
Node-2
   ↓
Cluster Network
   ↓
Node-1
   ↓
Ingress NGINX Pod
```

---

# Step 9: Ingress NGINX Processes the Request

The packet finally arrives at:

```text
Ingress NGINX Pod
```

NGINX examines:

```text
Host Header
URL Path
```

Example:

```text
Host: myapp.com
Path: /api/users
```

It consults the Ingress resources:

```yaml
kind: Ingress
```

and determines:

```text
/api
   ↓
api-service
```

---

# Step 10: NGINX Forwards to Application Service

NGINX sends traffic to:

```text
api-service
```

The Service resolves endpoints:

```text
api-pod-1
api-pod-2
api-pod-3
```

One pod is selected.

Example:

```text
api-pod-2
```

---

# Complete Traffic Flow

```text
User Browser
      ↓
DNS
      ↓
External Load Balancer
      ↓
Node-2:32080
      ↓
kube-proxy
      ↓
Ingress Service
      ↓
Ingress Pod IP
      ↓
Ingress NGINX Pod
      ↓
Ingress Rules
      ↓
api-service
      ↓
api-pod-2
      ↓
Response
```

---

# Important Realization

A Kubernetes Service is NOT a running application.

Many beginners imagine:

```text
Node
   ↓
Service
   ↓
Pod
```

as if the Service is a process.

It is not.

A Service is primarily:

```text
Networking Rules
+
Virtual IP
+
Endpoint Discovery
```

implemented by:

```text
iptables
IPVS
eBPF
```

inside the node.

---

# Mental Model

Think of a Service as a smart routing table.

```text
NodePort 32080
        ↓
Ingress Service
        ↓
Ingress Pod A
Ingress Pod B
```

When traffic reaches the node:

1. kube-proxy intercepts it.
2. Service rules match the NodePort.
3. An endpoint pod is selected.
4. The packet is rewritten.
5. Cluster networking delivers it to the pod.

No "Service process" exists between the node and the pod.
