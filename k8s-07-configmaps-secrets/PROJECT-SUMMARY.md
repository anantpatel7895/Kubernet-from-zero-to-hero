# Project 07 - ConfigMaps & Secrets - Summary

## ✅ What We Accomplished

In this project, we successfully demonstrated:

1. ✅ Creating and using **ConfigMaps** for non-sensitive configuration
2. ✅ Creating and using **Secrets** for sensitive data
3. ✅ **Two mounting methods**: Environment variables and volume mounts
4. ✅ **ConfigMap updates**: Environment variables vs volume-mounted files
5. ✅ **Secret encoding/decoding** and security best practices

---

## 🎓 Key Learnings

### 1. ConfigMaps vs Secrets

| Feature | ConfigMap | Secret |
|---------|-----------|--------|
| **Purpose** | Non-sensitive config | Sensitive data |
| **Encoding** | Plain text | Base64 (NOT encryption!) |
| **Use Cases** | Feature flags, URLs, settings | Passwords, API keys, certificates |
| **Security** | Less restrictive | RBAC controlled, encrypted at rest (optional) |

### 2. Mounting Methods Comparison

| Method | Auto-Updates? | Use Case | Restart Required? |
|--------|---------------|----------|-------------------|
| **Environment Variables** | ❌ No | Static config at startup | ✅ Yes |
| **Volume Mounts** | ✅ Yes (~60s delay) | Dynamic config files | ❌ No |

### 3. Critical Discovery: Volume-Mounted ConfigMaps Auto-Update!

**Environment Variables** (from ConfigMaps):
```bash
# ❌ Does NOT auto-update - requires pod restart
envFrom:
- configMapRef:
    name: app-config
```

**Volume Mounts** (from ConfigMaps):
```bash
# ✅ DOES auto-update - no restart needed!
volumeMounts:
- name: config-volume
  mountPath: /etc/config
volumes:
- name: config-volume
  configMap:
    name: app-config-files
```

**Test Results:**
- Updated `app-config-files` ConfigMap
- Waited ~70 seconds
- Files in `/etc/config/` automatically updated
- **No pod restart required!**
- Application read new config immediately

---

## 📊 Resources Created

### ConfigMaps
```bash
kubectl get configmaps -l app=config-demo
```
- `app-config` - 5 environment variables
- `app-config-files` - 2 configuration files (app.properties, features.json)

### Secrets
```bash
kubectl get secrets -l app=config-demo
```
- `app-secrets` - 2 secrets (API_KEY, DB_PASSWORD) - base64 encoded
- `app-secrets-stringdata` - 2 secrets - using stringData (auto-encoded)
- `app-secrets-files` - 2 secret files mounted as volumes
- `tls-secret-example` - TLS certificate example (type: kubernetes.io/tls)

### Deployment
```bash
kubectl get deployment config-demo-app
```
- 2 replicas
- Uses ALL ConfigMaps and Secrets
- Demonstrates both env vars and volume mounts

---

## 🧪 Tests Performed

### Test 1: Initial Configuration Verification
```bash
./test/test-config.sh
```
**Result:** ✅ All ConfigMaps and Secrets correctly mounted
- Environment variables from ConfigMap: ✅
- Environment variables from Secrets: ✅ (masked)
- Volume-mounted config files: ✅
- Volume-mounted secret files: ✅

### Test 2: Environment Variable Update
```bash
./test/test-update.sh
```
**Steps:**
1. Captured initial config values
2. Applied updated ConfigMap (`app-config`)
3. Checked pods - **values NOT updated** ❌
4. Restarted deployment
5. Checked pods - **values updated** ✅

**Key Learning:** Environment variables are injected at pod startup and do NOT auto-update

### Test 3: Volume Mount Auto-Update
```bash
./test/test-volume-update.sh
```
**Steps:**
1. Captured initial file contents
2. Applied updated ConfigMap (`app-config-files`)
3. Waited 70 seconds for kubelet sync
4. Checked files - **auto-updated WITHOUT pod restart!** ✅

**Key Learning:** Volume-mounted ConfigMaps sync automatically (~60s delay)

### Test 4: Secret Inspection
```bash
./test/inspect-secrets.sh
```
**Demonstrated:**
- Viewing base64-encoded secrets
- Decoding secrets: `echo <encoded> | base64 -d`
- Creating secrets manually (4 methods)
- Security warnings about base64 encoding

---

## 🔑 Important Security Insights

### Base64 is NOT Encryption!
```bash
# Anyone with kubectl access can decode secrets:
kubectl get secret app-secrets -o jsonpath='{.data.API_KEY}' | base64 -d
# Output: sk-demo-1234567890abcdef
```

### Best Practices

1. **Never commit secrets to Git**
   - Use `.gitignore` for secret files
   - Use placeholders in version control

2. **Use RBAC to restrict access**
   ```bash
   # Limit who can read secrets
   kubectl create role secret-reader --verb=get --resource=secrets
   ```

3. **Production Secret Management**
   - **Sealed Secrets** (Bitnami) - Encrypt secrets in Git
   - **External Secrets Operator** - Sync from external vaults
   - **HashiCorp Vault** - Centralized secret management
   - **Cloud Provider Secrets** - AWS Secrets Manager, Azure Key Vault, GCP Secret Manager

4. **Secret Rotation**
   - Regularly rotate passwords and API keys
   - Automate rotation where possible

5. **Limit Secret Scope**
   - Use different secrets per namespace
   - Don't share secrets across applications

---

## 📈 Real-World Use Cases

### ConfigMaps
- **Feature Flags**: Enable/disable features without redeployment
- **Environment-specific Config**: Different settings for dev/staging/prod
- **Application Settings**: Database URLs, cache endpoints, log levels
- **Configuration Files**: nginx.conf, prometheus.yml, etc.

### Secrets
- **Database Credentials**: Usernames, passwords
- **API Keys**: Third-party service keys
- **OAuth Tokens**: GitHub tokens, Google OAuth secrets
- **TLS Certificates**: HTTPS certificates and keys
- **SSH Keys**: Git repository access

### Volume Mounts (Auto-Update)
- **Feature Flag Systems**: Change flags without restarts
- **A/B Testing**: Adjust rollout percentages dynamically
- **Configuration Tuning**: Adjust cache TTLs, rate limits
- **Log Level Changes**: Increase verbosity for debugging

---

## 🎯 When to Use What?

| Scenario | Solution | Why? |
|----------|----------|------|
| Database password | Secret (env var) | Sensitive, static |
| API base URL | ConfigMap (env var) | Non-sensitive, static |
| Feature flags | ConfigMap (volume) | Need dynamic updates |
| nginx.conf | ConfigMap (volume) | Configuration file, may change |
| TLS certificate | Secret (volume) | Sensitive, file format required |
| Log level | ConfigMap (env or volume) | May need runtime changes |

---

## 🚀 What's Next?

### Project 08: Persistent Storage
- Learn about **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)**
- Deploy stateful applications (databases)
- Understand storage classes
- Handle data persistence across pod restarts

### Future Advanced Topics
- **GitOps**: Manage configuration in Git (ArgoCD)
- **Helm**: Template and package configurations
- **Policy Enforcement**: OPA/Gatekeeper for config validation
- **Encryption at Rest**: Enable etcd encryption for secrets

---

## 📝 Cleanup Commands

```bash
# Delete all resources from this project
kubectl delete deployment config-demo-app
kubectl delete service config-demo-service
kubectl delete configmap app-config app-config-files
kubectl delete secret app-secrets app-secrets-stringdata app-secrets-files tls-secret-example

# Or delete by label
kubectl delete all,configmap,secret -l app=config-demo
```

---

## 💡 Pro Tips

1. **Use descriptive names** for ConfigMaps/Secrets
2. **Version your ConfigMaps** (e.g., `app-config-v1`, `app-config-v2`) to enable rollbacks
3. **Document your config** - Add comments in YAML
4. **Validate before applying** - Use `kubectl apply --dry-run=client`
5. **Monitor config changes** - Set up alerts for ConfigMap/Secret modifications
6. **Use init containers** to validate config before starting main container
7. **Combine methods** - Use env vars for static, volumes for dynamic config

---

**Project Status:** ✅ COMPLETED

**Time to Complete:** ~45 minutes

**Difficulty:** ⭐⭐⭐ (3/5)

---

*Next: [Project 08 - Persistent Storage →](../k8s-08-persistent-storage/README.md)*
