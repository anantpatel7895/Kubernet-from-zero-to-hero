# Ingress Controller Installation

When an Ingress Controller (e.g., NGINX Ingress Controller) is installed, Kubernetes resources are created for it automatically by the installation manifest or Helm chart.

## Resources Created During Installation

### Deployment

The Deployment manages the lifecycle of the Ingress Controller pods.

```yaml
kind: Deployment
metadata:
  name: ingress-nginx-controller
```

Responsibilities:

* Creates Ingress Controller pods
* Restarts failed pods
* Supports scaling and rolling updates

### Pods

The actual Ingress Controller runs inside pods.

```text
ingress-nginx-controller-abc123
ingress-nginx-controller-def456
```

Responsibilities:

* Watch Ingress resources
* Generate NGINX configuration
* Route incoming HTTP/HTTPS traffic

### Service

A Service exposes the Ingress Controller pods.

```yaml
kind: Service
metadata:
  name: ingress-nginx-controller
spec:
  type: LoadBalancer
```

or

```yaml
spec:
  type: NodePort
```

Responsibilities:

* Provides a stable endpoint for the Ingress Controller
* Receives traffic from the external Load Balancer
* Forwards traffic to Ingress Controller pods

## Installation Flow

```text
Install ingress-nginx
        │
        ▼
Deployment created
        │
        ▼
Pods created
        │
        ▼
Service created
        │
        ▼
Ingress Controller ready
```

At this point, the Ingress Controller is running and waiting for Ingress resources (routing rules) to be created.

# Understanding Ingress Through NGINX Configuration

One of the easiest ways to understand Kubernetes Ingress is to compare it with traditional NGINX.

---

# Traditional NGINX Setup

Suppose you have a VM running:

* NGINX
* Frontend application
* API application

You install NGINX and manually configure routing.

Example:

```nginx
server {
    server_name myapp.com;

    location / {
        proxy_pass http://frontend;
    }
}
```

## Explanation

### server block

```nginx
server {
```

A server block represents a virtual host.

Example:

```text
myapp.com
api.myapp.com
admin.myapp.com
```

Each domain can have its own server block.

---

### server_name

```nginx
server_name myapp.com;
```

Defines which domain this configuration should handle.

When a request arrives:

```text
https://myapp.com
```

NGINX selects this server block.

---

### location

```nginx
location /
```

Matches the URL path.

Examples:

```text
/          → homepage
/about     → about page
/contact   → contact page
```

Since `/` is the root path, all requests match.

---

### proxy_pass

```nginx
proxy_pass http://frontend;
```

Forwards requests to another application.

Example:

```text
Browser
   ↓
NGINX
   ↓
Frontend App
```

The user never talks directly to the frontend application.

NGINX acts as a reverse proxy.

---

# More Advanced Example

```nginx
server {
    server_name myapp.com;

    location / {
        proxy_pass http://frontend;
    }

    location /api {
        proxy_pass http://api;
    }

    location /admin {
        proxy_pass http://admin;
    }
}
```

Routing behavior:

```text
myapp.com/         → frontend
myapp.com/api      → api
myapp.com/admin    → admin
```

NGINX decides where to send traffic based on the URL path.

---

# Kubernetes Equivalent

Instead of writing NGINX configuration manually:

```nginx
server {
    server_name myapp.com;

    location / {
        proxy_pass http://frontend;
    }

    location /api {
        proxy_pass http://api;
    }
}
```

We create an Ingress resource.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress

spec:
  rules:
  - host: myapp.com
    http:
      paths:

      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80

      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

---

# Mapping NGINX to Kubernetes

| NGINX                      | Kubernetes                             |
| -------------------------- | -------------------------------------- |
| server_name myapp.com      | host: myapp.com                        |
| location /                 | path: /                                |
| location /api              | path: /api                             |
| proxy_pass http://frontend | backend.service.name: frontend-service |
| proxy_pass http://api      | backend.service.name: api-service      |
| nginx.conf                 | Ingress Resource                       |

---

# What Actually Happens Internally

When you create:

```yaml
kind: Ingress
metadata:
  name: my-app-ingress
```

Kubernetes stores the object in **etcd**.

The Ingress Controller continuously watches for:

```text
Ingress
Service
Endpoint
Secret
```

changes.

When it detects:

```yaml
path: /
backend:
  service:
    name: frontend-service
```

it automatically generates NGINX configuration.

Conceptually:

```nginx
server {
    server_name myapp.com;

    location / {
        proxy_pass http://frontend-service;
    }
}
```

You never write this file yourself.

The Ingress Controller generates and reloads it automatically.

---

# Traditional NGINX vs Kubernetes Ingress

## Traditional

You manually edit:

```text
/etc/nginx/nginx.conf
```

Then run:

```bash
sudo nginx -s reload
```

Flow:

```text
Developer
    ↓
Edit nginx.conf
    ↓
Reload NGINX
    ↓
Traffic routed
```

---

## Kubernetes

You apply:

```bash
kubectl apply -f ingress.yaml
```

Flow:

```text
Developer
    ↓
Create Ingress Resource
    ↓
Ingress Controller detects change
    ↓
Generates NGINX configuration
    ↓
Reloads internally
    ↓
Traffic routed
```

No manual NGINX configuration is required.

---

# Complete Production Flow

```text
Internet
   │
   ▼
Cloud Load Balancer
   │
   ▼
Ingress Controller Service
   │
   ▼
Ingress Controller Pod (NGINX)
   │
   ▼
Reads Ingress Rules
   │
   ├── /      → frontend-service
   ├── /api   → api-service
   └── /admin → admin-service
   │
   ▼
Kubernetes Services
   │
   ▼
Application Pods
```

# Key Takeaway

The Ingress Controller is essentially a dynamically managed NGINX (or Traefik/HAProxy) running inside Kubernetes.

* **Ingress Controller** = The actual reverse proxy handling traffic.
* **Ingress Resource** = The routing rules.
* **Service** = Stable endpoint for a group of pods.
* **Pod** = The application instance handling the request.

The Ingress Controller reads Ingress resources and automatically generates the equivalent NGINX configuration, removing the need to manually edit `nginx.conf`.

