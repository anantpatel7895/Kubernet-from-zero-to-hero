# Project 07 - ConfigMaps & Secrets

## 📚 What You'll Learn

In this project, you'll learn how to manage application configuration in Kubernetes:

1. **ConfigMaps** - Store non-sensitive configuration data
2. **Secrets** - Store sensitive data (passwords, API keys, tokens)
3. **Different mounting methods** - Environment variables vs volume mounts
4. **Configuration updates** - How to update running applications
5. **Security best practices** - How to handle secrets safely

## 🎯 Key Concepts

### ConfigMaps
- Store configuration data as key-value pairs or files
- Used for non-sensitive data (database URLs, feature flags, etc.)
- Can be consumed as environment variables or mounted as files
- Updates to volume-mounted ConfigMaps are auto-synced to pods

### Secrets
- Store sensitive data in base64-encoded format
- **Important**: Base64 is NOT encryption, just encoding
- Should never be committed to Git
- Access controlled via RBAC
- Used for passwords, API keys, certificates, etc.

### Mounting Methods

| Method | Use Case | Auto-Updates? |
|--------|----------|---------------|
| Environment Variables | Static config, simple key-value pairs | ❌ No (requires pod restart) |
| Volume Mounts | Dynamic config, configuration files | ✅ Yes (up to 60s delay) |

## 📁 Project Structure

```
k8s-07-configmaps-secrets/
├── app/
│   ├── main.py              # FastAPI app that reads config
│   └── requirements.txt
├── docker/
│   └── Dockerfile
├── k8s/
│   ├── configmap-env.yaml          # ConfigMap with env vars
│   ├── configmap-files.yaml        # ConfigMap with files
│   ├── configmap-env-updated.yaml  # Updated ConfigMap
│   ├── secret-env.yaml             # Secret with env vars
│   ├── secret-files.yaml           # Secret with files
│   ├── deployment.yaml             # App using ConfigMaps & Secrets
│   └── service.yaml
├── test/
│   ├── test-config.sh              # Test all endpoints
│   ├── test-update.sh              # Test env var updates
│   ├── test-volume-updates.sh      # Test volume mount updates
│   └── inspect-secrets.sh          # Demo secret encoding/decoding
└── README.md
```

## 🚀 Quick Start

### Step 1: Build the Docker Image

```bash
cd /Users/in04844/Personal\ Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets

# Build the image
docker build -t config-demo:v1 -f docker/Dockerfile .
```

### Step 2: Create ConfigMaps and Secrets

```bash
# Create ConfigMaps
kubectl apply -f k8s/configmap-env.yaml
kubectl apply -f k8s/configmap-files.yaml

# Create Secrets
kubectl apply -f k8s/secret-env.yaml
kubectl apply -f k8s/secret-files.yaml
```

### Step 3: Deploy the Application

```bash
# Deploy the app
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for pods to be ready
kubectl rollout status deployment config-demo-app

# Check the deployment
kubectl get pods -l app=config-demo
kubectl get configmaps
kubectl get secrets
```

### Step 4: Test the Configuration

```bash
# Make test scripts executable
chmod +x test/*.sh

# Run configuration tests
./test/test-config.sh
```

## 🧪 Experiments

### Experiment 1: View ConfigMaps and Secrets

```bash
# View ConfigMap
kubectl get configmap app-config -o yaml

# View Secret (base64 encoded)
kubectl get secret app-secrets -o yaml

# Decode a secret value
kubectl get secret app-secrets -o jsonpath='{.data.API_KEY}' | base64 -d
echo ""
```

### Experiment 2: Inspect Configuration in Pods

```bash
# Check environment variables in a pod
kubectl exec deployment/config-demo-app -- env | grep -E "APP_NAME|ENVIRONMENT|LOG_LEVEL|API_KEY|DB_PASSWORD"

# Check mounted config files
kubectl exec deployment/config-demo-app -- cat /etc/config/app.properties
kubectl exec deployment/config-demo-app -- cat /etc/config/features.json

# Check mounted secret files
kubectl exec deployment/config-demo-app -- cat /etc/secrets/api-key
kubectl exec deployment/config-demo-app -- cat /etc/secrets/db-password
```

### Experiment 3: Test Environment Variable Updates

```bash
# Run the update test
./test/test-update.sh
```

**What you'll see:**
1. Initial configuration values
2. ConfigMap gets updated
3. Values DON'T change (env vars are static)
4. Pods get restarted
5. Values NOW reflect the update

**Key Takeaway**: Environment variables are injected at pod startup and don't auto-update.

### Experiment 4: Test Volume Mount Auto-Updates

```bash
# Run the volume update test
./test/test-volume-updates.sh
```

**What you'll see:**
1. Initial config file content
2. ConfigMap gets updated
3. After ~60 seconds, file content changes WITHOUT pod restart
4. Application can reload config files to pick up changes

**Key Takeaway**: Volume-mounted ConfigMaps auto-sync to pods (with delay).

### Experiment 5: Inspect Secret Encoding

```bash
# Run the secrets inspection demo
./test/inspect-secrets.sh
```

**What you'll learn:**
- How secrets are base64-encoded
- How to decode secrets manually
- Different methods to create secrets
- Security best practices

## 📊 Testing the API

Once deployed, test the endpoints using the client pod:

```bash
# Basic info
kubectl exec client -- curl -s http://config-demo-service:8000/

# View config from environment variables
kubectl exec client -- curl -s http://config-demo-service:8000/config | jq '.'

# View secrets from environment variables (masked)
kubectl exec client -- curl -s http://config-demo-service:8000/secrets | jq '.'

# View config from files
kubectl exec client -- curl -s http://config-demo-service:8000/config/file | jq '.'

# View secrets from files (masked)
kubectl exec client -- curl -s http://config-demo-service:8000/secrets/file | jq '.'
```

## 🔐 Security Best Practices

### ❌ DON'T DO THIS

```yaml
# Never commit real secrets to Git!
apiVersion: v1
kind: Secret
metadata:
  name: bad-example
stringData:
  production-password: "my-real-password"  # ❌ BAD!
```

### ✅ DO THIS INSTEAD

**Option 1: Use External Secret Management**
```bash
# Use tools like:
# - Sealed Secrets (bitnami-labs/sealed-secrets)
# - External Secrets Operator
# - HashiCorp Vault
# - AWS Secrets Manager / Azure Key Vault / GCP Secret Manager
```

**Option 2: Create Secrets Imperatively**
```bash
# Create secrets from command line (not stored in Git)
kubectl create secret generic app-secrets \
  --from-literal=api-key=sk-prod-xxx \
  --from-literal=db-password=xxx
```

**Option 3: Use .gitignore**
```bash
# Create secret files locally and ignore them
echo "k8s/secret-*.yaml" >> .gitignore
```

**Option 4: RBAC Restrictions**
```yaml
# Limit who can view secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

## 📖 How It Works

### 1. ConfigMap as Environment Variables

```yaml
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config  # All keys become env vars
```

### 2. Secret as Environment Variables

```yaml
spec:
  containers:
  - name: app
    envFrom:
    - secretRef:
        name: app-secrets  # All keys become env vars
```

### 3. Individual Environment Variables

```yaml
spec:
  containers:
  - name: app
    env:
    - name: JWT_SECRET
      valueFrom:
        secretKeyRef:
          name: app-secrets-stringdata
          key: JWT_SECRET
```

### 4. ConfigMap as Volume Mount

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config-files
```

### 5. Secret as Volume Mount

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: secrets-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets-volume
    secret:
      secretName: app-secrets-files
      defaultMode: 0400  # Read-only permissions
```

## 🎓 Key Learnings

### When to Use ConfigMaps vs Secrets

| Scenario | Use |
|----------|-----|
| Database connection string (with password) | Secret |
| Database hostname only | ConfigMap |
| API keys / tokens | Secret |
| Feature flags | ConfigMap |
| TLS certificates | Secret (type: kubernetes.io/tls) |
| Application settings | ConfigMap |
| OAuth client secrets | Secret |
| Max connections, timeouts | ConfigMap |

### Environment Variables vs Volume Mounts

| Aspect | Environment Variables | Volume Mounts |
|--------|----------------------|---------------|
| **Update without restart** | ❌ No | ✅ Yes (with delay) |
| **Use case** | Static config | Dynamic config files |
| **Complexity** | Simple | More complex |
| **File formats** | Key-value only | Any format (JSON, YAML, properties, etc.) |
| **Best for** | 12-factor apps | Legacy apps with config files |

### ConfigMap/Secret Update Behavior

1. **Environment Variables**: Injected at pod startup, never auto-update
2. **Volume Mounts**: Auto-sync from Kubernetes (default: every 60 seconds)
3. **Application Reload**: Your app must watch/reload files to see changes

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/

# Or delete individually
kubectl delete deployment config-demo-app
kubectl delete service config-demo-service
kubectl delete configmap app-config app-config-files
kubectl delete secret app-secrets app-secrets-stringdata app-secrets-files tls-secret-example

# Verify cleanup
kubectl get all -l app=config-demo
kubectl get configmaps
kubectl get secrets
```

## 🎯 Next Steps

In **Project 08 - Persistent Storage**, you'll learn:
- How to persist data beyond pod lifecycle
- PersistentVolumes (PV) and PersistentVolumeClaims (PVC)
- Storage classes and dynamic provisioning
- StatefulSets for stateful applications
- Volume types and when to use them

## 📚 Additional Resources

- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [12-Factor App - Config](https://12factor.net/config)

---

**Remember**: 
- ConfigMaps for non-sensitive config
- Secrets for sensitive data (but use proper secret management in production!)
- Never commit secrets to Git
- Use RBAC to control access
- Consider external secret management tools for production
