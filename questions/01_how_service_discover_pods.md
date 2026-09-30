# Kubernetes Service Discovery

## 1. What is Service Discovery?

A Kubernetes **Service** provides a stable network endpoint for accessing a group of Pods.

Pods are temporary and their IP addresses can change.

A Service solves this problem by:

* Finding the correct Pods
* Providing a stable IP address
* Providing a stable DNS name
* Routing traffic to the available Pods

---

## 2. How Does a Service Find Pods?

A Service uses a **Selector**.

Pods have **Labels**.

The Service selector is matched against Pod labels.

```text
Pod 1
labels:
    app: ml-api

Pod 2
labels:
    app: ml-api

Pod 3
labels:
    app: ml-api
```

Service:

```yaml
selector:
  app: ml-api
```

The Service discovers all Pods where:

```text
Pod label == Service selector
```

---

## 3. Example

### Pod Labels

A Deployment creates Pods with labels:

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
          image: ml-api:1.0
          ports:
            - containerPort: 8000
```

The Pods created by this Deployment will have:

```text
app=ml-api
```

---

## 4. Service Selector

The Service can select those Pods:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-api-service

spec:
  selector:
    app: ml-api

  ports:
    - port: 80
      targetPort: 8000
```

The important part is:

```yaml
selector:
  app: ml-api
```

This means:

> Find Pods having the label `app=ml-api`.

---

## 5. Complete Flow

```text
                    Client
                       |
                       v
              ml-api-service
                  Service
                       |
                       | selector:
                       | app=ml-api
                       |
                       v
                EndpointSlice
                       |
          +------------+------------+
          |            |            |
          v            v            v
       Pod 1         Pod 2        Pod 3
    10.0.1.10      10.0.1.11    10.0.1.12
       :8000          :8000        :8000
```

The complete relationship is:

```text
Service
   |
   | Selector
   v
Pod Labels
   |
   v
EndpointSlice
   |
   v
Pod IPs
   |
   v
Traffic Routing
   |
   v
Pod
```

---

# 6. What is EndpointSlice?

Kubernetes maintains **EndpointSlices** to keep track of the network endpoints associated with a Service.

For example:

```text
Service: ml-api-service

EndpointSlice:

10.0.1.10:8000
10.0.1.11:8000
10.0.1.12:8000
```

These are the Pods currently selected by the Service.

When Pods change, Kubernetes updates the EndpointSlice.

For example:

```text
Old Pods:

10.0.1.10
10.0.1.11
10.0.1.12

        Pod 2 deleted
             |
             v

New Pods:

10.0.1.10
10.0.1.12
10.0.1.15
```

The Service automatically gets the updated endpoint information.

---

# 7. Why Do We Need a Service?

Pod IP addresses are not stable.

For example:

```text
Pod 1
10.0.1.10
```

The Pod gets deleted.

A new Pod is created:

```text
Pod 4
10.0.1.20
```

If an application directly connects to:

```text
10.0.1.10
```

the connection can break.

Instead, the application connects to the Service:

```text
Client
   |
   v
ml-api-service
   |
   v
Current healthy Pods
```

The Service provides a stable endpoint even when Pods change.

---

# 8. Service Port vs TargetPort

Consider:

```yaml
ports:
  - port: 80
    targetPort: 8000
```

There are two different ports.

```text
Client
   |
   | Port 80
   v
Service
   |
   | TargetPort 8000
   v
Pod
```

### `port`

The port exposed by the Service.

```text
80
```

### `targetPort`

The port on which the application is listening inside the Pod.

```text
8000
```

Therefore:

```text
Client
   |
   | :80
   v
Service
   |
   | :8000
   v
Pod
```

---

# 9. Service DNS

A Service also gets a DNS name inside the Kubernetes cluster.

For example:

```text
ml-api-service
```

A Pod in the same namespace can usually access it using:

```text
http://ml-api-service
```

The fully qualified DNS name is:

```text
ml-api-service.<namespace>.svc.cluster.local
```

For example:

```text
ml-api-service.production.svc.cluster.local
```

So an application does not need to know the individual Pod IP addresses.

---

# 10. Service Discovery vs Traffic Routing

These are related but different concepts.

### Service Discovery

Answers:

> Which Pods belong to this Service?

This is primarily based on:

```text
Labels
+
Selectors
+
EndpointSlices
```

### Traffic Routing

Answers:

> Which available Pod should receive this request?

Kubernetes Service networking routes traffic to one of the available endpoints.

Conceptually:

```text
             Service
                |
        +-------+-------+
        |       |       |
        v       v       v
      Pod 1   Pod 2   Pod 3
```

---

# 11. Service + Deployment Relationship

A Service does **not** directly connect to a Deployment.

The relationship is:

```text
Deployment
     |
     | creates/manages
     v
ReplicaSet
     |
     | creates
     v
Pods
     |
     | labels
     v
Service Selector
     |
     v
EndpointSlice
     |
     v
Traffic to Pods
```

The Service only cares about the labels on Pods.

Therefore, a Service can select Pods created by:

* Deployment
* StatefulSet
* DaemonSet
* Job
* Manually created Pods

As long as the Pod labels match the Service selector.

---

# 12. Useful Commands

### Get Services

```bash
kubectl get services
```

or:

```bash
kubectl get svc
```

### Get Pods with a specific label

```bash
kubectl get pods -l app=ml-api
```

### Get Service details

```bash
kubectl describe service ml-api-service
```

### Get EndpointSlices

```bash
kubectl get endpointslices
```

For a specific Service:

```bash
kubectl get endpointslices \
  -l kubernetes.io/service-name=ml-api-service
```

### Check the Service YAML

```bash
kubectl get service ml-api-service -o yaml
```

---

# 13. Important Mental Model

Remember this simple chain:

```text
Pod
 |
 | has
 v
Label
 |
 | matched by
 v
Service Selector
 |
 v
EndpointSlice
 |
 v
Pod IP
```

And for the complete application:

```text
                    Kubernetes Cluster

                         Service
                            |
                     selector: app=ml-api
                            |
                            v
                      EndpointSlice
                            |
             +--------------+--------------+
             |              |              |
             v              v              v
           Pod 1          Pod 2          Pod 3
         app=ml-api     app=ml-api     app=ml-api
```

---

# 14. Key Points to Remember

1. **Pods have labels.**
2. **Services have selectors.**
3. **Selectors match Pod labels.**
4. Matching Pods become Service endpoints.
5. Kubernetes maintains these endpoints using **EndpointSlices**.
6. A Service provides a **stable IP and DNS name**.
7. Pod IPs can change; Service identity remains stable.
8. `port` is the Service port.
9. `targetPort` is the application port on the Pod.
10. A Service does not directly connect to a Deployment.
11. A Service can select Pods created by any controller.
12. **NetworkPolicy** can be used for additional network isolation.

---

## One-Line Interview Answer

> **A Kubernetes Service discovers Pods using label selectors, Kubernetes maintains the matching Pod IPs in EndpointSlices, and the Service provides a stable IP/DNS endpoint through which traffic is routed to those Pods.**
