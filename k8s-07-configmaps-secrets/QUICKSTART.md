# ConfigMaps & Secrets - Quick Reference

## 🚀 Quick Commands

### ConfigMaps

```bash
# Create ConfigMap from literal values
kubectl create configmap my-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2

# Create ConfigMap from file
kubectl create configmap my-config --from-file=config.yaml

# Create ConfigMap from directory
kubectl create configmap my-config --from-file=config-dir/

# View ConfigMap
kubectl get configmap my-config -o yaml
kubectl describe configmap my-config

# Edit ConfigMap
kubectl edit configmap my-config

# Delete ConfigMap
kubectl delete configmap my-config
```

### Secrets

```bash
# Create Secret from literal values
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Create Secret from file
kubectl create secret generic my-secret --from-file=ssh-key=~/.ssh/id_rsa

# Create TLS Secret
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key

# View Secret (base64 encoded)
kubectl get secret my-secret -o yaml

# Decode Secret
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# Delete Secret
kubectl delete secret my-secret
```

---

## 📋 YAML Examples

### ConfigMap - Environment Variables

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_URL: "postgres://db:5432/myapp"
  LOG_LEVEL: "info"
  CACHE_ENABLED: "true"
```

**Usage in Pod:**
```yaml
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config
```

### ConfigMap - Files

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-files
data:
  nginx.conf: |
    server {
      listen 80;
      server_name example.com;
    }
  app.properties: |
    db.host=localhost
    db.port=5432
```

**Usage in Pod:**
```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: app-config-files
```

### Secret - Environment Variables

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Base64 encoded values
  username: YWRtaW4=     # "admin"
  password: c2VjcmV0MTIz  # "secret123"
```

**Using stringData (auto-encodes):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  username: admin
  password: secret123
```

**Usage in Pod:**
```yaml
spec:
  containers:
  - name: app
    envFrom:
    - secretRef:
        name: app-secrets
```

### Secret - Individual Keys

```yaml
spec:
  containers:
  - name: app
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: password
```

### Secret - Volume Mount

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
      defaultMode: 0400  # Read-only for owner
```

---

## 🔄 Update Strategies

### Environment Variables (Requires Restart)

```bash
# 1. Update ConfigMap/Secret
kubectl edit configmap my-config

# 2. Restart deployment to pick up changes
kubectl rollout restart deployment my-app

# Or recreate pods
kubectl delete pod -l app=my-app
```

### Volume Mounts (Auto-Update)

```bash
# 1. Update ConfigMap/Secret
kubectl edit configmap my-config

# 2. Wait ~60 seconds for kubelet to sync
# Files automatically updated in pods!

# Check update status
kubectl exec my-pod -- cat /etc/config/file.conf
```

---

## 🛡️ Security Best Practices

### Encoding Secrets

```bash
# Encode
echo -n "my-secret-value" | base64
# Output: bXktc2VjcmV0LXZhbHVl

# Decode
echo "bXktc2VjcmV0LXZhbHVl" | base64 -d
# Output: my-secret-value
```

### RBAC for Secrets

```yaml
# Role that can only read secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

### Immutable ConfigMaps/Secrets

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  key: value
immutable: true  # Cannot be updated!
```

**Benefits:**
- Prevents accidental updates
- Improves cluster performance
- Forces versioning strategy

---

## 🎯 Common Patterns

### Multi-Environment Config

```bash
# Development
kubectl create configmap app-config \
  --from-literal=ENV=dev \
  --from-literal=DB_HOST=localhost \
  -n development

# Production
kubectl create configmap app-config \
  --from-literal=ENV=prod \
  --from-literal=DB_HOST=prod-db.example.com \
  -n production
```

### Versioned ConfigMaps

```bash
# Create versioned ConfigMaps
kubectl create configmap app-config-v1 --from-file=config-v1.yaml
kubectl create configmap app-config-v2 --from-file=config-v2.yaml

# Deployment uses specific version
# To rollback, just change configMapRef name
```

### Combined Config

```yaml
spec:
  containers:
  - name: app
    # Method 1: Load all keys from ConfigMap
    envFrom:
    - configMapRef:
        name: app-config
    
    # Method 2: Load specific keys
    env:
    - name: SPECIAL_KEY
      valueFrom:
        configMapKeyRef:
          name: another-config
          key: special-key
    
    # Method 3: Hardcoded env var
    - name: APP_NAME
      value: "My Application"
    
    # Method 4: Volume mount
    volumeMounts:
    - name: config-files
      mountPath: /etc/config
  
  volumes:
  - name: config-files
    configMap:
      name: app-config-files
```

---

## 🐛 Troubleshooting

### ConfigMap/Secret Not Found

```bash
# Check if it exists
kubectl get configmap my-config
kubectl get secret my-secret

# Check namespace
kubectl get configmap -A | grep my-config

# Describe to see events
kubectl describe configmap my-config
```

### Values Not Updating

```bash
# For env vars: Restart deployment
kubectl rollout restart deployment my-app

# For volume mounts: Check file directly
kubectl exec my-pod -- cat /etc/config/file

# Check ConfigMap content
kubectl get configmap my-config -o yaml
```

### Permission Denied

```bash
# Check RBAC
kubectl auth can-i get secrets --as=system:serviceaccount:default:my-sa

# Check pod's service account
kubectl get pod my-pod -o jsonpath='{.spec.serviceAccountName}'

# View service account permissions
kubectl describe serviceaccount my-sa
```

### Base64 Encoding Issues

```bash
# Correct way (without newline)
echo -n "value" | base64

# Wrong way (includes newline)
echo "value" | base64  # ❌

# Decode to verify
echo "dmFsdWU=" | base64 -d
```

---

## 📊 Comparison Table

| Feature | ConfigMap | Secret | When to Use |
|---------|-----------|--------|-------------|
| **Data Type** | Non-sensitive | Sensitive | Based on data sensitivity |
| **Encoding** | Plain text | Base64 | N/A |
| **Size Limit** | 1 MB | 1 MB | Split large configs |
| **Auto-Update (Volume)** | ✅ Yes | ✅ Yes | Dynamic configs |
| **Auto-Update (Env)** | ❌ No | ❌ No | Static configs |
| **Encryption** | No | Optional (at rest) | Enable for production |
| **RBAC** | Less strict | Strict | Based on sensitivity |
| **Versioning** | Manual | Manual | Use names like `-v1` |
| **Immutable** | Optional | Optional | For production stability |

---

## 💡 Pro Tips

1. **Always use `stringData` for secrets** - easier to read and maintain
2. **Version your ConfigMaps** - enables easy rollbacks
3. **Use labels** to organize configs: `env=prod`, `app=myapp`
4. **Document your configs** - add comments explaining each key
5. **Validate before applying** - use `--dry-run=client`
6. **Use init containers** to validate config before starting app
7. **Combine methods** - env vars for static, volumes for dynamic
8. **Monitor changes** - audit who modified secrets
9. **Rotate secrets regularly** - especially in production
10. **Never commit real secrets to Git** - use placeholder values

---

## 🔗 Related Concepts

- **kustomize**: Manage ConfigMaps across environments
- **Helm**: Template ConfigMaps and Secrets
- **Sealed Secrets**: Encrypt secrets for Git storage
- **External Secrets Operator**: Sync from external vaults
- **ArgoCD**: GitOps with config management

---

*For full examples, see [README.md](README.md) and [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md)*
