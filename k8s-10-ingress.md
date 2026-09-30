# k8s-10-ingress

## Directory structure

```text
k8s-10-ingress/
├── app/
│   ├── admin/
│   │   ├── Dockerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   └── frontend/
│       ├── Dockerfile
│       ├── main.py
│       └── requirements.txt
├── k8s/
│   ├── admin-deployment.yaml
│   ├── admin-service.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── ingress-host.yaml
│   ├── ingress-path.yaml
│   └── ingress-tls.yaml
├── test/
└── README.md
```

## Files

### `k8s-10-ingress/app/admin/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -r requirements.txt

COPY . .

CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```

### `k8s-10-ingress/app/admin/main.py`

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {
        "service": "admin",
        "message": "Admin Dashboard"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }

@app.get("/users/{user_id}")
def get_user_info(user_id: int):
    user_data = [{
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com"
    },
    {
        "id": 2,
        "name": "Bob",
        "email": "bob@example.com"
    }]

    try:
        user = next(user for user in user_data if user["id"] == user_id)
        return user
    except StopIteration:
        return None
```

### `k8s-10-ingress/app/admin/requirements.txt`

```text
fastapi
uvicorn
```

### `k8s-10-ingress/app/backend/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -r requirements.txt

COPY . .

CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```

### `k8s-10-ingress/app/backend/main.py`

```python
from fastapi import FastAPI
import requests

app = FastAPI(root_path="/api")

@app.get("/")
def home():
    return {
        "service": "backend",
        "message": "Backend Root"
    }

@app.get("/users")
def users():
    return {
        "users": [
            "John",
            "Alice",
            "Bob"
        ]
    }

@app.get("/admin-health")
def admin_health():
    
    try:
        response = requests.get("http://admin-service-ingress/health")
        if response.status_code == 200:
            return {
                "admin_status": response.json()
            }
        else:
            return {
                "admin_status": "unhealthy"
            }
    except Exception as e:
        return {
            "admin_status": "unhealthy",
            "error": str(e)
        }
```

### `k8s-10-ingress/app/backend/requirements.txt`

```text
fastapi
uvicorn
requests
```

### `k8s-10-ingress/app/frontend/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -r requirements.txt

COPY . .

CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```

### `k8s-10-ingress/app/frontend/main.py`

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {
        "service": "frontend",
        "message": "Welcome to Frontend"
    }

@app.get("/health")
def health():
    return {
        "app_name": "frontend",
        "status": "healthy"
    }
```

### `k8s-10-ingress/app/frontend/requirements.txt`

```text
fastapi
uvicorn
```

### `k8s-10-ingress/k8s/admin-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: admin-ingress

spec:
  replicas: 1

  selector:
    matchLabels:
      app: admin

  template:
    metadata:
      labels:
        app: admin

    spec:
      containers:
      - name: admin

        image: admin:v1

        ports:
        - containerPort: 8000
```

### `k8s-10-ingress/k8s/admin-service.yaml`

```yaml
apiVersion: v1
kind: Service

metadata:
  name: admin-service-ingress

spec:
  selector:
    app: admin

  ports:
  - port: 80
    targetPort: 8000

  type: ClusterIP
```

### `k8s-10-ingress/k8s/backend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: backend

spec:
  replicas: 2

  selector:
    matchLabels:
      app: backend

  template:
    metadata:
      labels:
        app: backend

    spec:
      containers:
      - name: backend

        image: backend:v2

        ports:
        - containerPort: 8000
```

### `k8s-10-ingress/k8s/backend-service.yaml`

```yaml
apiVersion: v1
kind: Service

metadata:
  name: backend-service

spec:
  selector:
    app: backend

  ports:
  - port: 80
    targetPort: 8000

  type: ClusterIP
```

### `k8s-10-ingress/k8s/frontend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-ingress
  labels:
    app: frontend

spec:
  replicas: 3

  selector:
    matchLabels:
      app: frontend

  template:
    metadata:
      labels:
        app: frontend

    spec:
      containers:
      - name: frontend

        image: frontend:v1

        imagePullPolicy: IfNotPresent

        ports:
        - containerPort: 8000

        resources:
          requests:
            cpu: 100m
            memory: 128Mi

          limits:
            cpu: 200m
            memory: 256Mi
```

### `k8s-10-ingress/k8s/frontend-service.yaml`

```yaml
apiVersion: v1
kind: Service

metadata:
  name: frontend-service-ingress

spec:
  selector:
    app: frontend

  ports:
  - port: 80
    targetPort: 8000

  type: ClusterIP
```

### `k8s-10-ingress/k8s/ingress-host.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: host-routing

spec:
  ingressClassName: nginx
  rules:
  - host: api.company.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 80
  - host: admin.company.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
  - host: shop.company.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

### `k8s-10-ingress/k8s/ingress-path.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: app-ingress

spec:
  ingressClassName: nginx   # 👈 THIS IS MISSING
  rules:
  - host: company.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service-ingress
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 80
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-service-ingress
            port:
              number: 80
```

### `k8s-10-ingress/k8s/ingress-tls.yaml`

```yaml

```

### `k8s-10-ingress/README.md`

```markdown
# Project 10 - Ingress & Traffic Routing

## Project Name

```text
k8s-10-ingress
```

---

# 🎯 Goal

Learn how to expose multiple applications through a **single entry point** using Kubernetes Ingress.

Instead of exposing every application separately, you'll use an Ingress Controller to intelligently route traffic based on:

- Host names (`api.local`, `admin.local`)
- URL paths (`/api`, `/admin`)

---

# 📚 What You'll Learn

By the end of this project, you'll understand:

- What problem Ingress solves
- Why Services alone are not enough
- How Ingress Controllers work
- Path-based routing
- Host-based routing
- Load balancing
- Traffic management
- TLS / HTTPS termination
- Real-world production architecture

---

# 🚨 The Problem

Imagine you're building a web application consisting of:

```text
Frontend UI
Backend API
Admin Dashboard
```

Each application runs in Kubernetes.

---

## Option 1: Expose Everything Using NodePort

```text
Frontend -> NodePort 30001
Backend  -> NodePort 30002
Admin    -> NodePort 30003
```

Users must remember different ports:

```text
http://server:30001
http://server:30002
http://server:30003
```

Problems:

- Hard to manage
- Not user-friendly
- Difficult to scale
- Difficult to secure
- Requires multiple exposed ports

---

## Option 2: Separate LoadBalancers

```text
Frontend -> LoadBalancer
Backend  -> LoadBalancer
Admin    -> LoadBalancer
```

Problems:

- Expensive
- Multiple public IPs
- More DNS management
- More operational overhead

---

# 💡 The Solution: Ingress

Ingress provides a **single entry point** for all applications.

Instead of:

```text
frontend.company.com
backend.company.com
admin.company.com
```

or

```text
server:30001
server:30002
server:30003
```

You can expose everything through:

```text
company.com
```

and route requests intelligently.

---

# 🏗 Architecture

Without Ingress:

```text
             Internet

      ┌────────┼────────┐
      │        │        │

      ▼        ▼        ▼

Frontend   Backend   Admin
Service    Service   Service

NodePort   NodePort  NodePort
```

---

With Ingress:

```text
                 Internet
                      │
                      ▼

          Ingress Controller

            │     │      │

            ▼     ▼      ▼

      Frontend  Backend  Admin
       Service  Service  Service
```

Single entry point.

Smarter routing.

Cleaner architecture.

---

# 🧠 Kubernetes Networking Hierarchy

```text
Pod
 ↓
Service
 ↓
Ingress
 ↓
Internet
```

---

# Project Structure

```text
k8s-10-ingress/
├── app/
│   ├── frontend/
│   ├── backend/
│   └── admin/
│
├── k8s/
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── admin-deployment.yaml
│   ├── admin-service.yaml
│   ├── ingress-host.yaml
│   ├── ingress-path.yaml
│   └── ingress-tls.yaml
│
└── test/
```

---

# 📦 Step 1 - Deploy Applications

We'll deploy three applications:

```text
Frontend
Backend
Admin
```

---

## First Create Docker images

```bash
docker build -t frontend:v1 ./app/frontend
```

and

```bash
docker build -t backend:v1 ./app/backend
```

and

```bash
docker build -t admin:v1 ./app/admin
```

---

## Deploy Frontend

```bash
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
```

Verify:

```bash
kubectl get pods
kubectl get svc
```

---

## Deploy Backend

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
```

Verify:

```bash
kubectl get pods
kubectl get svc
```

---

## Deploy Admin

```bash
kubectl apply -f k8s/admin-deployment.yaml
kubectl apply -f k8s/admin-service.yaml
```

Verify:

```bash
kubectl get pods
kubectl get svc
```

---

# 🔍 Verify Services

You should see:

```bash
kubectl get svc
```

Example:

```text
frontend-service
backend-service
admin-service
```

At this point services are only accessible inside the cluster.

---

# 🚀 Step 2 - Install Ingress Controller

Ingress resources do nothing by themselves.

You must install an Ingress Controller.

---

## Minikube

Enable Ingress:

```bash
minikube addons enable ingress
```

---

Verify:

```bash
kubectl get pods -n ingress-nginx
```

Expected:

```text
ingress-nginx-controller
```

---

## Kind

Install NGINX Ingress:

```bash
kubectl apply -f \
https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## docker desktop

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

Verify:

```bash
kubectl get pods -n ingress-nginx
```

Wait until:

```text
Running
```

---

# 📌 Step 3 - Path-Based Routing

This is the most common Ingress pattern.

Users access:

```text
company.local/
company.local/api
company.local/admin
```

---

## Routing Rules

```text
/        -> frontend-service
/api     -> backend-service
/admin   -> admin-service
```

---

Apply:

```bash
kubectl apply -f k8s/ingress-path.yaml
```

Verify:

```bash
kubectl get ingress
```

Expected:

```text
NAME           CLASS   HOSTS
app-ingress    nginx   company.local
```

---

# 🧪 Test Path Routing

Add hosts entry:

Linux/macOS:

```bash
sudo vim /etc/hosts
```

Add:

```text
127.0.0.1 company.local
```

---

Test:

```bash
curl http://company.local/
```

Should return:

```text
Frontend Response
```

---

Test:

```bash
curl http://company.local/api
```

Should return:

```text
Backend Response
```

---

Test:

```bash
curl http://company.local/admin
```

Should return:

```text
Admin Response
```

---

# 🌐 Step 4 - Host-Based Routing

Now route based on hostname.

---

## Desired Behavior

```text
api.local    -> backend-service

admin.local  -> admin-service

shop.local   -> frontend-service
```

---

Apply:

```bash
kubectl apply -f k8s/ingress-host.yaml
```

Verify:

```bash
kubectl get ingress
```

---

Update hosts:

```bash
sudo vim /etc/hosts
```

Add:

```text
127.0.0.1 api.local
127.0.0.1 admin.local
127.0.0.1 shop.local
```

---

Test:

```bash
curl http://api.local
```

Should reach backend.

---

Test:

```bash
curl http://admin.local
```

Should reach admin.

---

Test:

```bash
curl http://shop.local
```

Should reach frontend.

---

# 🔄 Request Flow

Example:

```text
http://api.local/users
```

Flow:

```text
Browser
   ↓
Ingress Controller
   ↓
Ingress Rule Match
   ↓
backend-service
   ↓
backend-pod
```

---

# ⚖ Load Balancing

Suppose frontend has:

```text
frontend-pod-1
frontend-pod-2
frontend-pod-3
```

Traffic:

```text
Request 1 → pod-1
Request 2 → pod-2
Request 3 → pod-3
```

The Service balances traffic among pods.

Ingress routes traffic to the Service.

---

# 🔒 Step 5 - TLS / HTTPS

Production systems should use HTTPS.

---

Create TLS Secret:

```bash
kubectl create secret tls app-tls \
  --cert=tls.crt \
  --key=tls.key
```

---

Apply:

```bash
kubectl apply -f k8s/ingress-tls.yaml
```

Verify:

```bash
kubectl describe ingress
```

You should see:

```text
TLS:
  app-tls
```

---

# 🧪 Useful Commands

---

## View Pods

```bash
kubectl get pods
```

---

## View Services

```bash
kubectl get svc
```

---

## View Ingress

```bash
kubectl get ingress
```

---

## Describe Ingress

```bash
kubectl describe ingress
```

---

## Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
```

---

## View Events

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

# 🆚 Service vs Ingress

| Feature | Service | Ingress |
|----------|----------|----------|
| Exposes Pods | ✅ | ❌ |
| Exposes Services | ❌ | ✅ |
| Layer 4 | ✅ | ❌ |
| Layer 7 | ❌ | ✅ |
| Path Routing | ❌ | ✅ |
| Host Routing | ❌ | ✅ |
| TLS Termination | ❌ | ✅ |
| Single Entry Point | ❌ | ✅ |

---

# 🎓 What You've Learned

By completing this project you've learned:

✅ Why exposing every service separately is problematic

✅ How Ingress provides a single entry point

✅ How Ingress Controllers work

✅ Path-based routing

✅ Host-based routing

✅ Service discovery

✅ Load balancing

✅ TLS termination

✅ Production-grade traffic management

---

# 🧠 Final Mental Model

```text
Internet
    │
    ▼

Ingress Controller
    │
    ▼

Ingress Rules
    │
    ▼

Services
    │
    ▼

Pods
```

Think of it as:

```text
Pods      = Shops
Services  = Shop Addresses
Ingress   = City Traffic Controller
```

The traffic controller decides where every incoming request should go.
```
