# Kubernetes Port Forwarding

## 1. What is Port Forwarding?

Kubernetes port forwarding allows you to access an application running inside a Kubernetes cluster from your local machine.

The main command is:

```bash
kubectl port-forward
```

It creates a temporary connection between a port on your local machine and a port inside the Kubernetes cluster.

### Basic example

```bash
kubectl port-forward pod/my-api-pod 8000:8000
```

Now:

```text
Local Machine
localhost:8000
      |
      | kubectl port-forward
      |
      v
Kubernetes Pod
container:8000
```

You can access the application using:

```text
http://localhost:8000
```

---

# 2. Why Do We Need Port Forwarding?

Pods normally run inside the Kubernetes network.

For example:

```text
                Kubernetes Cluster
              +----------------------+
              |                      |
              |   Pod                |
              |  +----------------+  |
              |  | FastAPI        |  |
              |  | Port 8000      |  |
              |  +----------------+  |
              |                      |
              +----------------------+

Your Laptop
localhost:8000
```

Your laptop cannot normally access the Pod directly.

Port forwarding creates a temporary path:

```text
Laptop
localhost:8000
     |
     | kubectl
     |
     v
Kubernetes API
     |
     v
Pod
:8000
```

---

# 3. Basic Syntax

```bash
kubectl port-forward <resource> <local-port>:<remote-port>
```

Examples:

```bash
kubectl port-forward pod/my-pod 8000:8000
```

```bash
kubectl port-forward service/my-service 8000:8000
```

```bash
kubectl port-forward deployment/my-deployment 8000:8000
```

---

# 4. Port Mapping

Consider:

```bash
kubectl port-forward pod/my-api 9000:8000
```

The format is:

```text
LOCAL_PORT : REMOTE_PORT
```

Therefore:

```text
localhost:9000
      |
      v
Pod:8000
```

The application inside the Pod listens on:

```text
8000
```

but your local machine uses:

```text
9000
```

You access it with:

```text
http://localhost:9000
```

---

# 5. Port Forwarding to a Pod

You can directly forward traffic to a Pod.

First:

```bash
kubectl get pods
```

Example:

```text
NAME                         READY   STATUS
ml-api-7d9f8d9c7c-x8abc      1/1     Running
```

Then:

```bash
kubectl port-forward pod/ml-api-7d9f8d9c7c-x8abc 8000:8000
```

Output:

```text
Forwarding from 127.0.0.1:8000 -> 8000
Forwarding from [::1]:8000 -> 8000
```

Now:

```text
http://localhost:8000
```

reaches that specific Pod.

---

# 6. Pod Port Forwarding Architecture

```text
                Local Machine
             +----------------+
             |                |
             | localhost:8000 |
             |                |
             +-------+--------+
                     |
                     |
              kubectl process
                     |
                     v
             Kubernetes API
                     |
                     v
             +---------------+
             |     Pod       |
             |               |
             | FastAPI :8000 |
             +---------------+
```

### Important

When forwarding directly to a Pod:

```text
localhost
   |
   v
specific Pod
```

You are not using a Kubernetes Service for routing.

---

# 7. Port Forwarding to a Deployment

You can also specify a Deployment.

```bash
kubectl port-forward deployment/ml-api 8000:8000
```

Example:

```text
Deployment
    |
    +---- Pod A
    |
    +---- Pod B
    |
    +---- Pod C
```

The Deployment itself does not run the application.

Pods run the application.

Kubernetes resolves the Deployment to a Pod and establishes the port-forward to that Pod.

Conceptually:

```text
localhost:8000
      |
      v
Deployment
      |
      v
   Pod A
```

---

# 8. Important Deployment Behavior

Suppose:

```text
Deployment: ml-api

Replicas = 3

Pod A
Pod B
Pod C
```

You run:

```bash
kubectl port-forward deployment/ml-api 8000:8000
```

Kubernetes selects one Pod.

Conceptually:

```text
localhost:8000
      |
      v
Deployment
      |
      v
    Pod B
```

The port-forward is not a permanent load balancer across all three Pods.

It is primarily useful for development and debugging.

---

# 9. Port Forwarding to a Service

You can also forward to a Service.

```bash
kubectl port-forward service/ml-service 8000:8000
```

or:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Suppose:

```text
Service: ml-service
       |
       +------ Pod A
       |
       +------ Pod B
       |
       +------ Pod C
```

Then:

```text
localhost:8000
      |
      v
Service
      |
      +---- Pod A
      +---- Pod B
      +---- Pod C
```

The Service provides the abstraction over the Pods.

---

# 10. Service Port vs Target Port

Consider:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-service
spec:
  selector:
    app: ml-api

  ports:
    - port: 80
      targetPort: 8000
```

Here:

```text
Service port       = 80
Pod targetPort     = 8000
```

You can run:

```bash
kubectl port-forward service/ml-service 9000:80
```

The flow is:

```text
localhost:9000
      |
      v
Service:80
      |
      v
Pod:8000
```

This is an important distinction.

---

# 11. Pod vs Deployment vs Service

## Pod

```bash
kubectl port-forward pod/ml-api-abc123 8000:8000
```

Flow:

```text
localhost
   |
   v
specific Pod
```

Use when you want to debug one specific Pod.

---

## Deployment

```bash
kubectl port-forward deployment/ml-api 8000:8000
```

Flow:

```text
localhost
   |
   v
Deployment
   |
   v
selected Pod
```

Useful for quickly accessing an application managed by a Deployment.

---

## Service

```bash
kubectl port-forward service/ml-service 8000:8000
```

Flow:

```text
localhost
   |
   v
Service
   |
   +---- Pod A
   +---- Pod B
   +---- Pod C
```

Useful when you want to test the Service-facing application path.

---

# 12. Comparison

| Feature                      | Pod          | Deployment                   | Service             |
| ---------------------------- | ------------ | ---------------------------- | ------------------- |
| Targets                      | Specific Pod | Pod selected from Deployment | Service             |
| Stable endpoint              | No           | No                           | Yes, within cluster |
| Good for debugging           | Yes          | Yes                          | Yes                 |
| Works with multiple replicas | Not directly | Selects a Pod                | Yes                 |
| Uses Service                 | No           | No                           | Yes                 |
| Production exposure          | No           | No                           | No                  |
| Temporary                    | Yes          | Yes                          | Yes                 |

---

# 13. Example: FastAPI ML Model

Suppose you have an ML API:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/predict")
def predict():
    return {"prediction": 1}
```

The container runs:

```text
FastAPI
Port 8000
```

Your Kubernetes Deployment:

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
```

Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-service
spec:
  selector:
    app: ml-api

  ports:
    - port: 8000
      targetPort: 8000
```

Architecture:

```text
                 Kubernetes Cluster

              Deployment: ml-api
                       |
          +------------+------------+
          |            |            |
          v            v            v
       Pod A         Pod B        Pod C
       :8000         :8000        :8000
          \            |            /
           \           |           /
            +----------+----------+
                       |
                   Service
                 ml-service:8000
```

Run:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Now:

```text
localhost:8000
      |
      v
ml-service
      |
      v
one of the available Pods
```

You can call:

```bash
curl http://localhost:8000/predict
```

---

# 14. Port Forwarding and ML Model Testing

Port forwarding is very useful when developing ML inference services.

For example:

```text
                    Kubernetes

                 +-------------+
                 | ML Service  |
                 +------+------+
                        |
             +----------+----------+
             |          |          |
             v          v          v
          Pod A      Pod B      Pod C
          Model      Model      Model
             |
             |
        FastAPI :8000
             ^
             |
      kubectl port-forward
             ^
             |
       localhost:8000
             ^
             |
        Developer
```

You can test:

* `/health`
* `/predict`
* `/generate`
* `/embedding`
* `/rerank`
* `/metrics`
* Swagger UI
* OpenAPI

For example:

```text
http://localhost:8000/docs
```

---

# 15. Port Forwarding to Different Local Port

Suppose the Pod uses:

```text
8000
```

but your laptop already has something running on port 8000.

Use:

```bash
kubectl port-forward svc/ml-service 9000:8000
```

Now:

```text
localhost:9000
       |
       v
Service:8000
       |
       v
Pod:8000
```

---

# 16. Port Forwarding Multiple Ports

You can forward multiple ports in one command.

```bash
kubectl port-forward pod/my-pod 8000:8000 5000:5000
```

Now:

```text
localhost:8000 -> Pod:8000

localhost:5000 -> Pod:5000
```

---

# 17. Namespace

If your resource is in a different namespace:

```bash
kubectl port-forward -n ml-prod svc/ml-service 8000:8000
```

Without `-n`, Kubernetes uses the current/default namespace.

Check namespaces:

```bash
kubectl get namespaces
```

Check Pods:

```bash
kubectl get pods -n ml-prod
```

---

# 18. Port Forward Using Pod Name

```bash
kubectl get pods
```

Then:

```bash
kubectl port-forward pod/ml-api-7d9f8d9c7c-x8abc 8000:8000
```

---

# 19. Port Forward Using Service Name

```bash
kubectl get services
```

Then:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

---

# 20. Port Forward Using Deployment Name

```bash
kubectl get deployments
```

Then:

```bash
kubectl port-forward deployment/ml-api 8000:8000
```

---

# 21. Binding to localhost

By default, port forwarding listens on localhost:

```text
127.0.0.1
```

Example:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Usually:

```text
localhost:8000
```

is accessible only from your local machine.

---

# 22. Binding to All Interfaces

You can use:

```bash
kubectl port-forward --address 0.0.0.0 svc/ml-service 8000:8000
```

This can make the forwarded port accessible through other network interfaces of your machine.

Example:

```text
Other machine
      |
      v
Your machine:8000
      |
      v
kubectl port-forward
      |
      v
Kubernetes Service
```

### Security Warning

Do not use:

```bash
--address 0.0.0.0
```

carelessly on a shared or publicly reachable machine.

---

# 23. Port Forwarding is Temporary

When you execute:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

the command stays running:

```text
Forwarding from 127.0.0.1:8000 -> 8000
```

If you press:

```text
Ctrl + C
```

the port forwarding stops.

Therefore:

```text
kubectl process running
        |
        v
port forwarding active

kubectl process stopped
        |
        v
port forwarding stopped
```

---

# 24. Port Forwarding is Not a Production Exposure Mechanism

Do not use:

```bash
kubectl port-forward
```

as the normal way to expose a production application.

For production, Kubernetes commonly uses:

```text
                    Internet / Client
                           |
                           v
                    Load Balancer
                           |
                           v
                       Ingress
                           |
                           v
                        Service
                           |
              +------------+------------+
              |            |            |
              v            v            v
             Pod          Pod          Pod
```

Depending on the architecture, you may use:

* LoadBalancer
* NodePort
* Ingress
* Gateway API
* Internal Load Balancer
* Service Mesh

---

# 25. Port Forwarding vs NodePort

## Port Forward

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Characteristics:

```text
Temporary
Developer-oriented
No public endpoint
Requires kubectl
Requires Kubernetes access
```

---

## NodePort

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

Architecture:

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

NodePort creates a Kubernetes network endpoint on nodes.

---

# 26. Port Forward vs LoadBalancer

Port forwarding:

```text
Developer
    |
    v
localhost
    |
    v
kubectl
    |
    v
Pod/Service
```

LoadBalancer:

```text
Client
    |
    v
Cloud Load Balancer
    |
    v
Kubernetes Service
    |
    v
Pods
```

LoadBalancer is designed for exposing services externally.

---

# 27. Port Forward vs Ingress

Port forwarding:

```text
localhost
    |
    v
kubectl
    |
    v
Service/Pod
```

Ingress:

```text
Internet
   |
   v
Ingress Controller
   |
   +--------+
   |        |
   v        v
Service A Service B
   |        |
   v        v
Pods       Pods
```

Ingress is appropriate when you need HTTP/HTTPS routing for applications.

---

# 28. What Happens Internally?

When you execute:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

the general flow is:

```text
1. kubectl
     |
     v
2. Kubernetes API Server
     |
     v
3. Port-forward connection
     |
     v
4. Selected Pod
     |
     v
5. Container port 8000
```

The important point is that `kubectl` establishes the forwarding connection through Kubernetes rather than requiring you to expose the Pod directly to your local network.

---

# 29. Does Port Forward Require a Service?

No.

You can directly forward to a Pod:

```bash
kubectl port-forward pod/my-pod 8000:8000
```

You can also forward to a Deployment:

```bash
kubectl port-forward deployment/my-api 8000:8000
```

Or Service:

```bash
kubectl port-forward svc/my-service 8000:8000
```

So:

```text
Pod          -> Yes
Deployment   -> Yes
Service      -> Yes
```

---

# 30. Does Port Forward Work Across Nodes?

Yes.

This is important in Kubernetes.

Suppose:

```text
Node 1                    Node 2

Pod A                     Pod B
                           |
                           |
                           |
                       ML application
```

Your `kubectl` is running on your laptop.

If the target Pod is on Node 2, you do not need SSH into Node 2 just to use port forwarding.

For example:

```bash
kubectl port-forward pod/ml-api-abc 8000:8000
```

Kubernetes handles the connection to the Pod.

Conceptually:

```text
Laptop
   |
   | kubectl
   v
Kubernetes API
   |
   | cluster networking
   v
Node 2
   |
   v
Pod B
```

---

# 31. What Happens if the Pod Dies?

This is one of the important limitations.

Suppose:

```text
localhost:8000
      |
      v
Pod A
```

Then Pod A crashes.

The Deployment creates:

```text
Pod B
```

Your existing port-forward connection may terminate because it was connected to the original Pod.

You generally need to establish the port-forward again.

This is another reason why port forwarding is not a production traffic-routing mechanism.

---

# 32. Why Service Port Forwarding is Convenient

Suppose:

```text
Deployment
   |
   +---- Pod A
   +---- Pod B
   +---- Pod C
```

Service:

```text
ml-service
```

You run:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

You don't need to know the Pod name.

This is especially useful because Pod names can change:

```text
ml-api-7d9f8d9c7c-x8abc
ml-api-7d9f8d9c7c-abcde
ml-api-7d9f8d9c7c-pqrst
```

Pods are ephemeral.

The Service provides a stable Kubernetes abstraction.

---

# 33. Typical Development Workflow

Suppose you deploy your ML API:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

Check:

```bash
kubectl get pods
```

Then:

```bash
kubectl get svc
```

Suppose:

```text
NAME         TYPE        CLUSTER-IP      PORT
ml-service   ClusterIP   10.96.120.10    8000
```

Run:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Test:

```bash
curl http://localhost:8000/health
```

Swagger:

```text
http://localhost:8000/docs
```

Test prediction:

```bash
curl -X POST http://localhost:8000/predict
```

---

# 34. Debugging with Port Forwarding

Port forwarding is extremely useful for debugging.

For example:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Then test:

```text
/health
/docs
/metrics
/predict
```

If the application fails:

```bash
kubectl logs <pod-name>
```

You can also inspect:

```bash
kubectl describe pod <pod-name>
```

---

# 35. Common Errors

## Error: Address already in use

Example:

```text
Unable to listen on port 8000:
address already in use
```

Another process is already using port 8000.

Use another local port:

```bash
kubectl port-forward svc/ml-service 9000:8000
```

---

## Error: Pod not found

```text
pods "my-pod" not found
```

Check:

```bash
kubectl get pods
```

If it is in another namespace:

```bash
kubectl get pods -n ml-prod
```

Then:

```bash
kubectl port-forward -n ml-prod pod/my-pod 8000:8000
```

---

## Error: Connection refused

Example:

```text
error forwarding port
connection refused
```

Possible reasons:

* Application isn't running.
* Wrong container port.
* Application listens on another port.
* Application is bound incorrectly.
* Pod is not ready.
* Service/target configuration is incorrect.

Check:

```bash
kubectl logs <pod>
```

and:

```bash
kubectl describe pod <pod>
```

---

# 36. Important Difference: containerPort

You may see:

```yaml
containers:
  - name: ml-api
    image: ml-api:1.0
    ports:
      - containerPort: 8000
```

`containerPort` is mainly declarative metadata.

It does not itself expose the application outside the Pod.

You can still port-forward to the actual listening port.

For example:

```bash
kubectl port-forward pod/ml-api 8000:8000
```

---

# 37. Complete ML Example

### Deployment

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
```

### Service

```yaml
apiVersion: v1
kind: Service

metadata:
  name: ml-service

spec:
  type: ClusterIP

  selector:
    app: ml-api

  ports:
    - port: 8000
      targetPort: 8000
```

Apply:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

Check:

```bash
kubectl get pods
```

```bash
kubectl get svc
```

Port forward:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

Access:

```text
http://localhost:8000
```

Swagger:

```text
http://localhost:8000/docs
```

---

# 38. Mental Model

The easiest way to remember port forwarding is:

```text
PORT FORWARDING

Local Port
    |
    v
kubectl
    |
    v
Kubernetes
    |
    v
Target Resource
    |
    +---- Pod
    |
    +---- Deployment
    |
    +---- Service
```

Examples:

```bash
# Pod
kubectl port-forward pod/my-pod 8000:8000

# Deployment
kubectl port-forward deployment/my-api 8000:8000

# Service
kubectl port-forward service/my-service 8000:8000
```

---

# 39. Interview Questions

## Q1. What is Kubernetes port forwarding?

Port forwarding creates a temporary connection from a local machine to a Pod or another Kubernetes resource, allowing developers to access an application without exposing it externally.

---

## Q2. Can we port-forward to a Pod?

Yes:

```bash
kubectl port-forward pod/my-pod 8000:8000
```

---

## Q3. Can we port-forward to a Deployment?

Yes:

```bash
kubectl port-forward deployment/my-api 8000:8000
```

Kubernetes selects a Pod associated with the Deployment.

---

## Q4. Can we port-forward to a Service?

Yes:

```bash
kubectl port-forward service/my-service 8000:8000
```

---

## Q5. Is port forwarding suitable for production?

Generally, no.

It is primarily intended for:

* Development
* Debugging
* Local testing
* Temporary access

Production applications normally use Services, Ingress/Gateway, LoadBalancers, or internal networking mechanisms.

---

## Q6. Does port forwarding require NodePort?

No.

```text
Port Forward
    |
    X
NodePort not required
```

---

## Q7. Does port forwarding require a public IP?

No.

You can access the application through:

```text
localhost
```

without exposing the application publicly.

---

## Q8. What happens if the Pod is deleted?

The existing connection can terminate because the forwarding connection was tied to the selected Pod.

A new forwarding connection may need to be established.

---

## Q9. Why use Service port forwarding instead of Pod port forwarding?

Service port forwarding provides a higher-level abstraction and avoids having to manually identify a specific Pod.

For example:

```bash
kubectl port-forward svc/ml-service 8000:8000
```

instead of:

```bash
kubectl port-forward pod/ml-api-7d9f8d9c7c-x8abc 8000:8000
```

---

# 40. Final Summary

### Three important commands

```bash
# Pod
kubectl port-forward pod/<pod-name> 8000:8000
```

```bash
# Deployment
kubectl port-forward deployment/<deployment-name> 8000:8000
```

```bash
# Service
kubectl port-forward service/<service-name> 8000:8000
```

### Remember

```text
Pod
 └── Direct access to a specific Pod

Deployment
 └── Kubernetes selects a Pod from the Deployment

Service
 └── Access through the Service abstraction
```

And:

```text
Port Forwarding
     ↓
Temporary
     ↓
Mostly development/debugging
     ↓
Does NOT permanently expose your application
```

For an ML service:

```text
                    Kubernetes

                  +-----------+
                  | Deployment|
                  +-----+-----+
                        |
              +---------+---------+
              |         |         |
              v         v         v
            Pod A     Pod B     Pod C
             ML        ML        ML
             :8000     :8000     :8000
              \         |         /
               \        |        /
                +-------+-------+
                        |
                    Service
                  ml-service:8000
                        ^
                        |
                 port-forward
                        ^
                        |
                  localhost:8000
                        ^
                        |
                    Developer
```

This is the core mental model to remember.
