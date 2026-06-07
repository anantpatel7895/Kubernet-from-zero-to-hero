# Project 08 - Persistent Storage

## 📚 What You'll Learn

In this project, you'll master Kubernetes storage concepts:

1. **Persistent Volumes (PV)** - Cluster-level storage resources
2. **Persistent Volume Claims (PVC)** - Storage requests by pods
3. **Storage Classes** - Dynamic provisioning of storage
4. **StatefulSets** - Managing stateful applications
5. **Volume Types** - Different storage backends
6. **Data Persistence** - Surviving pod restarts and deletions

## 🎯 Key Concepts

### Why Persistent Storage?

**Problem with Container Storage:**
- Containers are ephemeral (temporary)
- When a pod is deleted, all data is lost
- Pod restarts lose all container data
- Cannot share data between pods

**Solution: Persistent Volumes**
- Data survives pod restarts
- Data survives pod deletions
- Can share data between pods
- Independent lifecycle from pods

### Storage Hierarchy

```
Storage Class (SC)
    ↓ (provisions)
Persistent Volume (PV)
    ↓ (binds to)
Persistent Volume Claim (PVC)
    ↓ (mounts into)
Pod
```

### Key Components

#### 1. Persistent Volume (PV)
- **Cluster-level resource** (not namespaced)
- Actual storage (like a USB drive)
- Created by cluster admin
- Has capacity, access modes, storage class

#### 2. Persistent Volume Claim (PVC)
- **Namespace-level resource**
- Request for storage (like asking for a USB drive)
- Created by developer
- Binds to a matching PV

#### 3. Storage Class (SC)
- **Template for dynamic PV creation**
- Defines storage type (SSD, HDD, cloud storage)
- Automatically creates PVs when PVC is created
- Simplifies storage management

### Access Modes

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| ReadWriteOnce | RWO | Mounted read-write by **one node** |
| ReadOnlyMany | ROX | Mounted read-only by **many nodes** |
| ReadWriteMany | RWX | Mounted read-write by **many nodes** |
| ReadWriteOncePod | RWOP | Mounted read-write by **one pod** |

### Reclaim Policies

| Policy | Description | Use Case |
|--------|-------------|----------|
| Retain | Keep data after PVC deletion | Production data |
| Delete | Delete data after PVC deletion | Temporary data |
| Recycle | Wipe data, reuse PV | Deprecated |

## 📁 Project Structure

```
k8s-08-persistent-storage/
├── app/
│   ├── main.py              # FastAPI app with file storage
│   └── requirements.txt
├── docker/
│   └── Dockerfile
├── k8s/
│   ├── storage-class.yaml          # StorageClass definition
│   ├── pv-manual.yaml              # Manual PV creation
│   ├── pvc-manual.yaml             # PVC for manual PV
│   ├── pvc-dynamic.yaml            # PVC for dynamic provisioning
│   ├── pod-with-pvc.yaml           # Single pod using PVC
│   ├── deployment-with-pvc.yaml    # Deployment using PVC
│   ├── statefulset.yaml            # StatefulSet with PVC
│   └── service.yaml
└── test/
    ├── 01-test-manual-pv.sh        # Test manual PV/PVC
    ├── 02-test-dynamic-pv.sh       # Test dynamic provisioning
    ├── 03-test-persistence.sh      # Test data survives deletion
    ├── 04-test-statefulset.sh      # Test StatefulSet storage
    └── README.md
```

## 🚀 Getting Started

### Step 1: Build the Application

```bash
# Build Docker image
cd k8s-08-persistent-storage
docker build -t storage-demo:v1 -f docker/Dockerfile .
```

### Step 2: Create Manual PV and PVC

```bash
# Create PersistentVolume
kubectl apply -f k8s/pv-manual.yaml

# Create PersistentVolumeClaim
kubectl apply -f k8s/pvc-manual.yaml

# Check PV and PVC status
kubectl get pv
kubectl get pvc
```

### Step 3: Deploy Pod with PVC

```bash
# Deploy pod that uses the PVC
kubectl apply -f k8s/pod-with-pvc.yaml

# Check pod status
kubectl get pods

# Test writing data
kubectl exec storage-pod -- sh -c "echo 'Hello from Pod' > /data/test.txt"

# Verify data
kubectl exec storage-pod -- cat /data/test.txt
```

### Step 4: Test Data Persistence

```bash
# Delete the pod
kubectl delete pod storage-pod

# Recreate the pod
kubectl apply -f k8s/pod-with-pvc.yaml

# Verify data still exists
kubectl exec storage-pod -- cat /data/test.txt
```

### Step 5: Dynamic Provisioning

```bash
# Create StorageClass (may already exist)
kubectl get storageclass

# Create PVC for dynamic provisioning
kubectl apply -f k8s/pvc-dynamic.yaml

# PV is automatically created!
kubectl get pv

# Deploy application
kubectl apply -f k8s/deployment-with-pvc.yaml
kubectl apply -f k8s/service.yaml
```

### Step 6: StatefulSet with Storage

```bash
# Deploy StatefulSet
kubectl apply -f k8s/statefulset.yaml

# Each pod gets its own PVC!
kubectl get pvc

# Check pods
kubectl get pods -l app=stateful-demo
```

## 🧪 Running Tests

### Manual Testing
```bash
# Test manual PV/PVC
./test/01-test-manual-pv.sh

# Test dynamic provisioning
./test/02-test-dynamic-pv.sh

# Test data persistence
./test/03-test-persistence.sh

# Test StatefulSet storage
./test/04-test-statefulset.sh
```

### Automated Testing
```bash
# Run all tests
cd test
./run-all-tests.sh
```

## 📊 Key Differences

### Deployment vs StatefulSet

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| **Pod Names** | Random (pod-abc123) | Ordered (pod-0, pod-1) |
| **Network Identity** | Random | Stable (pod-0.service) |
| **Storage** | Shared PVC | Unique PVC per pod |
| **Scaling** | Parallel | Sequential (ordered) |
| **Use Case** | Stateless apps | Databases, queues |

### EmptyDir vs PVC

| Feature | EmptyDir | PVC |
|---------|----------|-----|
| **Lifecycle** | Tied to pod | Independent |
| **Data Loss** | Lost on pod delete | Persists |
| **Sharing** | Between containers | Between pods |
| **Use Case** | Temp files, cache | Databases, uploads |

## 💡 Best Practices

1. **Use StorageClasses** for dynamic provisioning
2. **Set resource requests** to ensure storage availability
3. **Use StatefulSets** for databases and stateful apps
4. **Backup important data** regularly
5. **Set appropriate reclaim policies** (Retain for production)
6. **Monitor storage usage** to avoid running out of space
7. **Use ReadWriteOnce** unless you need shared storage

## 🔍 Troubleshooting

### PVC stuck in Pending
```bash
# Check PVC events
kubectl describe pvc my-pvc

# Common causes:
# 1. No matching PV available
# 2. No StorageClass available
# 3. Insufficient storage capacity
```

### Pod can't mount volume
```bash
# Check pod events
kubectl describe pod my-pod

# Common causes:
# 1. PVC not bound
# 2. Volume already mounted on another node (RWO)
# 3. Permission issues
```

### Data not persisting
```bash
# Verify PVC is bound
kubectl get pvc

# Check mount path in pod
kubectl exec my-pod -- ls -la /data

# Verify PV reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy
```

## 🎓 What You'll Build

1. **File Storage API** - REST API that stores files
2. **Manual PV Setup** - Create and bind PV/PVC manually
3. **Dynamic Provisioning** - Auto-create storage on demand
4. **StatefulSet Database** - Deploy a stateful app with persistent storage
5. **Data Persistence Tests** - Verify data survives pod deletions

## 📚 Additional Resources

- [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

---

**Next Steps:** 
1. Build the Docker image
2. Create manual PV and PVC
3. Test data persistence
4. Explore dynamic provisioning
5. Deploy StatefulSet

Let's start building! 🚀
