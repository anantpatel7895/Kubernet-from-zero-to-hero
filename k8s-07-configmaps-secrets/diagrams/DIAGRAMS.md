# ConfigMaps & Secrets - Visual Guide

## 🎨 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                               │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                         Deployment                                  │ │
│  │                     config-demo-app (2 replicas)                   │ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐ │ │
│  │  │         Pod 1               │  │         Pod 2               │ │ │
│  │  │                             │  │                             │ │ │
│  │  │  ┌───────────────────────┐  │  │  ┌───────────────────────┐  │ │ │
│  │  │  │   FastAPI Container   │  │  │  │   FastAPI Container   │  │ │ │
│  │  │  │                       │  │  │  │                       │  │ │ │
│  │  │  │  Environment Vars:    │  │  │  │  Environment Vars:    │  │ │ │
│  │  │  │  ├─ APP_NAME (CM) ──┐ │  │  │  │  ├─ APP_NAME (CM)     │  │ │ │
│  │  │  │  ├─ ENVIRONMENT (CM)│ │  │  │  │  ├─ ENVIRONMENT (CM)  │  │ │ │
│  │  │  │  ├─ LOG_LEVEL (CM)  │ │  │  │  │  ├─ LOG_LEVEL (CM)    │  │ │ │
│  │  │  │  ├─ API_KEY (Secret)│ │  │  │  │  ├─ API_KEY (Secret)  │  │ │ │
│  │  │  │  └─ DB_PASSWORD (S) │ │  │  │  │  └─ DB_PASSWORD (S)   │  │ │ │
│  │  │  │                       │  │  │  │                       │  │ │ │
│  │  │  │  Volumes:             │  │  │  │  Volumes:             │  │ │ │
│  │  │  │  /etc/config/         │  │  │  │  /etc/config/         │  │ │ │
│  │  │  │    ├─ app.properties ─┼──┼──┼──┼──► app.properties     │  │ │ │
│  │  │  │    └─ features.json ──┼──┼──┼──┼──► features.json      │  │ │ │
│  │  │  │                       │  │  │  │                       │  │ │ │
│  │  │  │  /etc/secrets/        │  │  │  │  /etc/secrets/        │  │ │ │
│  │  │  │    ├─ api-key ────────┼──┼──┼──┼──► api-key            │  │ │ │
│  │  │  │    └─ db-password ────┼──┼──┼──┼──► db-password        │  │ │ │
│  │  │  │                       │  │  │  │                       │  │ │ │
│  │  │  └───────────────────────┘  │  │  └───────────────────────┘  │ │ │
│  │  └─────────────────────────────┘  └─────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────────── │ │
│                                  ▲                  ▲                   │
│                                  │                  │                   │
│  ┌───────────────────────────────┴──────────────────┴────────────────┐ │
│  │                       Service: config-demo-service                 │ │
│  │                       Type: ClusterIP                              │ │
│  │                       Port: 8000                                   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                         ConfigMaps                                  │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐          ┌─────────────────────────────┐ │ │
│  │  │   app-config         │          │   app-config-files          │ │ │
│  │  │  (Env Variables)     │          │   (File Mounts)             │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  APP_NAME            │          │  app.properties (config)    │ │ │
│  │  │  ENVIRONMENT         │          │  features.json (flags)      │ │ │
│  │  │  LOG_LEVEL           │          │                             │ │ │
│  │  │  MAX_CONNECTIONS     │          │  ✅ Auto-updates (~60s)     │ │ │
│  │  │  ENABLE_FEATURE_X    │          │  ✅ No restart needed       │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  ❌ No auto-update    │          └─────────────────────────────┘ │ │
│  │  │  ✅ Restart required  │                                          │ │
│  │  └──────────────────────┘                                          │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                           Secrets                                   │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐          ┌─────────────────────────────┐ │ │
│  │  │   app-secrets        │          │   app-secrets-files         │ │ │
│  │  │  (Env Variables)     │          │   (File Mounts)             │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  API_KEY (base64)    │          │  api-key (file)             │ │ │
│  │  │  DB_PASSWORD (b64)   │          │  db-password (file)         │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  🔒 Base64 encoded    │          │  🔒 Base64 encoded          │ │ │
│  │  │  ❌ No auto-update    │          │  ✅ Auto-updates (~60s)     │ │ │
│  │  └──────────────────────┘          └─────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐          ┌─────────────────────────────┐ │ │
│  │  │ app-secrets-         │          │   tls-secret-example        │ │ │
│  │  │   stringdata         │          │   (TLS Certificate)         │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  JWT_SECRET          │          │  tls.crt                    │ │ │
│  │  │  OAUTH_CLIENT_SECRET │          │  tls.key                    │ │ │
│  │  │                      │          │                             │ │ │
│  │  │  📝 stringData used   │          │  Type: kubernetes.io/tls    │ │ │
│  │  │  (auto-encodes)      │          │                             │ │ │
│  │  └──────────────────────┘          └─────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Configuration Flow Diagram

### Environment Variables (Static)

```
┌──────────────┐
│  ConfigMap   │
│  or Secret   │
└──────┬───────┘
       │
       │ kubectl apply
       │
       ▼
┌──────────────┐
│   etcd       │  ← Configuration stored
│  (K8s DB)    │
└──────┬───────┘
       │
       │ Pod creation
       │
       ▼
┌──────────────────────────────────┐
│  Pod Spec                         │
│  env:                             │
│  - name: APP_NAME                 │
│    valueFrom:                     │
│      configMapKeyRef:             │
│        name: app-config           │
│        key: APP_NAME              │
└──────┬────────────────────────────┘
       │
       │ Injected at startup
       │
       ▼
┌──────────────────────────────────┐
│  Container Process               │
│  Environment:                    │
│  APP_NAME=ConfigMap Demo App     │
│  ENVIRONMENT=production          │
│  API_KEY=sk-demo-1234...         │
└──────────────────────────────────┘
       │
       │ ConfigMap updated?
       │
       ▼
┌──────────────────────────────────┐
│  ❌ NO CHANGE                     │
│  Must restart pod to pick up     │
│  kubectl rollout restart deploy  │
└──────────────────────────────────┘
```

### Volume Mounts (Dynamic)

```
┌──────────────┐
│  ConfigMap   │
│  or Secret   │
└──────┬───────┘
       │
       │ kubectl apply
       │
       ▼
┌──────────────┐
│   etcd       │  ← Configuration stored
│  (K8s DB)    │
└──────┬───────┘
       │
       │ Mounted as volume
       │
       ▼
┌──────────────────────────────────┐
│  Pod Volume Mount                │
│  volumeMounts:                    │
│  - name: config                   │
│    mountPath: /etc/config         │
│  volumes:                         │
│  - name: config                   │
│    configMap:                     │
│      name: app-config-files       │
└──────┬────────────────────────────┘
       │
       │ Kubelet creates symlinks
       │
       ▼
┌──────────────────────────────────┐
│  Container Filesystem            │
│  /etc/config/                    │
│    ├─ app.properties (symlink)   │
│    └─ features.json (symlink)    │
└──────┬────────────────────────────┘
       │
       │ Application reads files
       │
       ▼
┌──────────────────────────────────┐
│  Application                     │
│  with open('/etc/config/...'):   │
│    config = f.read()             │
└──────┬────────────────────────────┘
       │
       │ ConfigMap updated?
       │
       ▼
┌──────────────────────────────────┐
│  ✅ AUTO-SYNCED!                  │
│  Kubelet updates symlinks        │
│  ~60 seconds delay               │
│  No pod restart needed           │
└──────────────────────────────────┘
```

---

## 📊 Data Flow

### Creating and Using ConfigMap

```
Developer              Kubernetes API          etcd              Kubelet               Pod
    │                       │                    │                  │                   │
    │  kubectl apply        │                    │                  │                   │
    │─────────────────────> │                    │                  │                   │
    │                       │  Store ConfigMap   │                  │                   │
    │                       │──────────────────> │                  │                   │
    │                       │                    │                  │                   │
    │  kubectl apply        │                    │                  │                   │
    │  deployment.yaml      │                    │                  │                   │
    │─────────────────────> │                    │                  │                   │
    │                       │   Create Pod       │                  │                   │
    │                       │────────────────────────────────────── │                   │
    │                       │                    │                  │  Pull ConfigMap   │
    │                       │                    │                  │<───────────────── │
    │                       │                    │<──────────────── │                   │
    │                       │                    │                  │  Create Pod       │
    │                       │                    │                  │──────────────────>│
    │                       │                    │                  │                   │
    │                       │                    │                  │  Mount Volumes    │
    │                       │                    │                  │  Inject Env Vars  │
    │                       │                    │                  │                   │
    │                       │                    │                  │ Pod Running       │
    │                       │                    │                  │<──────────────────│
```

### Updating ConfigMap (Volume Mount)

```
Developer              Kubernetes API          etcd              Kubelet               Pod
    │                       │                    │                  │                   │
    │  kubectl edit         │                    │                  │                   │
    │  configmap            │                    │                  │                   │
    │─────────────────────> │                    │                  │                   │
    │                       │  Update ConfigMap  │                  │                   │
    │                       │──────────────────> │                  │                   │
    │                       │                    │                  │                   │
    │                       │                    │  Watch for       │                   │
    │                       │                    │  changes         │                   │
    │                       │                    │<──────────────── │                   │
    │                       │                    │                  │                   │
    │                       │                    │  Detect change   │                   │
    │                       │                    │  (~60s later)    │                   │
    │                       │                    │──────────────────>│                   │
    │                       │                    │                  │  Update symlinks  │
    │                       │                    │                  │  in volume        │
    │                       │                    │                  │──────────────────>│
    │                       │                    │                  │                   │
    │                       │                    │                  │  App reads new    │
    │                       │                    │                  │  config (next     │
    │                       │                    │                  │  file read)       │
    │                       │                    │                  │<──────────────────│
```

---

## 🔐 Security Flow

### Secret Creation and Access

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Secret Creation Flow                             │
└─────────────────────────────────────────────────────────────────────┘

1. Developer creates Secret YAML
   ┌────────────────────────────────┐
   │ secret.yaml                    │
   │ data:                          │
   │   password: c3VwZXJzZWNyZXQ=  │  ← Base64 encoded
   └────────────────────────────────┘
                  │
                  │ kubectl apply
                  ▼
   ┌────────────────────────────────┐
   │ Kubernetes API Server          │
   │ - Validates RBAC               │
   │ - Checks permissions           │
   └────────────────────────────────┘
                  │
                  │ Stored
                  ▼
   ┌────────────────────────────────┐
   │ etcd (Kubernetes Database)     │
   │ - Plain base64 (default)       │
   │ - OR encrypted at rest         │
   │   (if enabled)                 │
   └────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Secret Access Flow                               │
└─────────────────────────────────────────────────────────────────────┘

2. Pod requests Secret
   ┌────────────────────────────────┐
   │ Pod Spec                       │
   │ envFrom:                       │
   │ - secretRef:                   │
   │     name: app-secrets          │
   └────────────────────────────────┘
                  │
                  │ Kubelet requests
                  ▼
   ┌────────────────────────────────┐
   │ Kubernetes API Server          │
   │ - Checks ServiceAccount RBAC   │
   │ - Verifies permissions         │
   └────────────────────────────────┘
                  │
                  │ If authorized
                  ▼
   ┌────────────────────────────────┐
   │ etcd                           │
   │ - Retrieves Secret             │
   │ - Decrypts (if encrypted)      │
   └────────────────────────────────┘
                  │
                  │ Base64 decoded
                  ▼
   ┌────────────────────────────────┐
   │ Container Process              │
   │ PASSWORD=supersecret           │  ← Injected as plain text
   └────────────────────────────────┘
```

---

## 🎯 Decision Tree

```
Need to configure your application?
                │
                ▼
         Is it sensitive?
                │
        ┌───────┴───────┐
        │               │
       YES             NO
        │               │
        │               ▼
        │        Use ConfigMap
        │               │
        ▼               │
   Use Secret           │
        │               │
        └───────┬───────┘
                │
                ▼
    Will it change frequently?
                │
        ┌───────┴───────┐
        │               │
       YES             NO
        │               │
        │               ▼
        │        Use Environment
        │        Variables
        │        (envFrom)
        │
        ▼
   Use Volume Mount
   (volumeMounts)
        │
        ▼
   ✅ Configuration
      Strategy Chosen!
```

---

## 📈 Update Comparison

```
┌─────────────────────────────────────────────────────────────────────┐
│              Environment Variables vs Volume Mounts                  │
└─────────────────────────────────────────────────────────────────────┘

Environment Variables (envFrom):
────────────────────────────────
Time 0:     ConfigMap created
            └─> Pod starts with values

Time 10m:   ConfigMap updated
            └─> Pod STILL has old values ❌

Time 15m:   kubectl rollout restart deployment
            └─> New pods created with new values ✅
            └─> Old pods terminated

Downtime:   Possible (depends on strategy)
Use Case:   Static config that rarely changes


Volume Mounts (volumeMounts):
──────────────────────────────
Time 0:     ConfigMap created
            └─> Pod mounts volume with files

Time 10m:   ConfigMap updated
            └─> Kubelet watches for changes

Time 11m:   Kubelet syncs new content (~60s delay)
            └─> Symlinks updated automatically ✅
            └─> App reads new config on next file access

Downtime:   None! Zero-downtime updates
Use Case:   Dynamic config, feature flags


Best Practice:
──────────────
Mix both approaches:
- Environment variables: Database URLs, static config
- Volume mounts: Feature flags, dynamic settings
```

---

*For more details, see [PROJECT-SUMMARY.md](../PROJECT-SUMMARY.md)*
