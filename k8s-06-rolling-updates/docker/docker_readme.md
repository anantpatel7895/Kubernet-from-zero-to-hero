### Build the FastAPI Application

First, let's build the Docker image:

```bash
# Build the Docker image from project root
docker build -f docker/Dockerfile -t fastapi-demo:v1 .

# Test locally (optional)
docker run -p 8000:8000 fastapi-demo:v1
# Visit http://localhost:8000
```

**For Minikube users:**
```bash
# Use minikube's Docker daemon
eval $(minikube docker-env)
docker build -f docker/Dockerfile -t fastapi-demo:v1 .
```

**For Kind users:**
```bash
# Build and load into kind cluster
docker build -f docker/Dockerfile -t fastapi-demo:v1 .
kind load docker-image fastapi-demo:v1
```