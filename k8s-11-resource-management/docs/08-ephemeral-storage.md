# 08 - Ephemeral Storage

---

# Learning Objectives

By the end of this lab you will understand:

* What ephemeral storage is
* Why Kubernetes tracks ephemeral storage
* Ephemeral storage requests and limits
* How emptyDir works
* How container logs consume disk
* How writable container layers consume disk
* DiskPressure
* Storage-based evictions
* How to troubleshoot disk-related outages
* Production storage best practices
* Interview questions related to ephemeral storage

---

# What Is Ephemeral Storage?

Ephemeral means:

```text id="1cjlwm"
Temporary
```

Ephemeral storage is:

```text id="4f3ahf"
Node Local Storage

Used By Pods

While They Are Running
```

---

Unlike:

```text id="1mzj4j"
Persistent Volumes
```

Ephemeral storage:

```text id="oow4zn"
Disappears

When Pod Is Removed
```

---

# Examples Of Ephemeral Storage

A container uses ephemeral storage for:

```text id="ivmrl5"
Logs

Temporary Files

Cache Files

Writable Layer

emptyDir Volumes
```

---

Example:

```text id="w40k5h"
/tmp

/var/log

Application Cache

Downloaded Files
```

All consume:

```text id="sjrckr"
Ephemeral Storage
```

---

# Persistent vs Ephemeral

Persistent Volume:

```text id="ab0wwq"
Survives Pod Restart
```

---

Ephemeral Storage:

```text id="zn34sl"
Destroyed With Pod
```

---

Example:

```text id="cg7hjj"
Database Data
```

Should use:

```text id="1djw4u"
Persistent Volume
```

---

Example:

```text id="p7e9mv"
Temporary Cache
```

Can use:

```text id="dzxbgu"
Ephemeral Storage
```

---

# Why Kubernetes Tracks Disk Usage

Node:

```text id="h51qob"
Disk = 100Gi
```

---

Pods:

```text id="pg0p45"
Pod A

40Gi
```

```text id="n1t65n"
Pod B

30Gi
```

```text id="j4swwq"
Pod C

35Gi
```

---

Total:

```text id="4mvgrs"
105Gi
```

Problem:

```text id="3m1zk0"
Node Disk Full
```

---

Consequences:

```text id="shh4pz"
Container Creation Fails

Image Pulls Fail

Logs Stop Writing

Node Becomes Unstable
```

---

# Kubernetes Solution

Kubernetes allows:

```yaml id="me0m07"
ephemeral-storage
```

requests and limits.

---

Example

```yaml id="i6vm93"
resources:
  requests:
    ephemeral-storage: "256Mi"

  limits:
    ephemeral-storage: "512Mi"
```

Meaning:

```text id="2l7hfp"
Reserve

256Mi
```

Maximum:

```text id="w80uz7"
512Mi
```

---

# Current Project Configuration

Your deployment already includes:

```yaml id="d6vgqz"
resources:
  requests:
    ephemeral-storage: "256Mi"

  limits:
    ephemeral-storage: "512Mi"
```

This is excellent because most tutorials completely ignore ephemeral storage.

---

# Where Storage Is Consumed

Container storage comes from:

---

## Writable Layer

Every container has:

```text id="m1xk1u"
Read Only Image
```

plus:

```text id="v0plkj"
Writable Layer
```

---

When application writes:

```text id="k8drgq"
/tmp/file.txt
```

it uses:

```text id="tx3d2z"
Ephemeral Storage
```

---

## Logs

Container logs consume disk.

Example:

```text id="p3rwrm"
Application Writes

100MB Logs Per Minute
```

After:

```text id="9e2fxn"
10 Minutes
```

Disk usage:

```text id="yzg41f"
1Gi
```

---

Many production outages are caused by:

```text id="yqclw9"
Log Growth
```

not application code.

---

## emptyDir Volumes

Example:

```yaml id="e0jb0j"
volumes:
- name: cache

  emptyDir: {}
```

---

Mounted:

```yaml id="wuw6nt"
volumeMounts:
- mountPath: /cache
```

---

Storage written to:

```text id="76qg0m"
/cache
```

uses:

```text id="r85lfy"
Node Disk
```

---

# How emptyDir Works

Create:

```yaml id="v6efji"
apiVersion: v1
kind: Pod

metadata:
  name: emptydir-demo

spec:
  containers:
  - name: app

    image: busybox

    command:
    - sh
    - -c
    - sleep 3600

    volumeMounts:
    - name: cache
      mountPath: /cache

  volumes:
  - name: cache
    emptyDir: {}
```

---

Deploy:

```bash id="0x4df8"
kubectl apply -f emptydir-demo.yaml
```

---

Write data:

```bash id="7y4prv"
kubectl exec \
emptydir-demo \
-- sh
```

Inside:

```bash id="zv7vny"
dd if=/dev/zero \
of=/cache/test.bin \
bs=1M \
count=100
```

---

Check:

```bash id="gm4vkl"
du -sh /cache
```

Expected:

```text id="f44hzj"
100M
```

---

Delete Pod:

```bash id="94hvk6"
kubectl delete pod emptydir-demo
```

Data disappears.

---

# Adding Disk Consumption Endpoint

Earlier we added:

```text id="s4h7b8"
/write-disk
```

endpoint.

---

Example:

```bash id="8a61yl"
curl \
"http://localhost:8080/write-disk?mb=100"
```

Creates:

```text id="nk09az"
100MB Temporary File
```

---

Run repeatedly:

```bash id="jpr7q2"
curl \
"http://localhost:8080/write-disk?mb=100"
```

---

Eventually:

```text id="m8gqg5"
Ephemeral Storage Limit
```

is exceeded.

---

# Storage-Based Eviction

Pod:

```yaml id="i4sxh8"
resources:
  limits:
    ephemeral-storage: "200Mi"
```

---

Application writes:

```text id="z7nqte"
300Mi
```

---

Result:

```text id="v7g4b0"
Pod Evicted
```

Not:

```text id="0l6nhs"
OOMKilled
```

---

Important distinction.

---

# Verify Eviction

Describe Pod:

```bash id="xy52y8"
kubectl describe pod POD_NAME
```

Look for:

```text id="ylx0np"
Reason:

Evicted
```

---

Message may contain:

```text id="1v6hcr"
Ephemeral Storage Usage Exceeded
```

---

# DiskPressure

Node:

```text id="8mbzhk"
100Gi Disk
```

Usage:

```text id="b5jv7t"
98Gi
```

---

Node condition:

```text id="y1dx4s"
DiskPressure=True
```

---

Check:

```bash id="t2fd9j"
kubectl describe node NODE_NAME
```

Look for:

```text id="g8thdi"
DiskPressure
```

---

Example:

```text id="sqv1vt"
DiskPressure

True
```

---

# Node Filesystem Layout

Common locations:

```text id="y4hqez"
/var/lib/containerd

/var/lib/docker

/var/log

/var/lib/kubelet
```

---

These directories often cause:

```text id="s1r8f7"
DiskPressure
```

when unmanaged.

---

# View Node Disk Usage

Node shell:

```bash id="n4m8mn"
df -h
```

---

Check largest directories:

```bash id="p9p3bc"
du -sh /*
```

---

Find heavy usage:

```bash id="6e7p8f"
du -sh /var/log/*
```

---

# Common Production Causes

---

## Log Explosion

Application writes:

```text id="y5bh8p"
Millions Of Log Lines
```

Disk fills.

---

## Temporary File Leak

Application creates:

```text id="0g3mk4"
/tmp Files
```

Never deletes them.

---

## Large Cache

Application stores:

```text id="tgn29p"
Gigabytes Of Cache
```

locally.

---

## Image Accumulation

Node stores:

```text id="rj36rn"
Unused Images
```

for months.

---

# Production Monitoring

Monitor:

```text id="3rxtkh"
Node Disk Usage

Container Disk Usage

Log Growth
```

---

Tools:

```text id="pdqhy9"
Prometheus

Grafana

Datadog

New Relic
```

---

# Troubleshooting Workflow

Pod disappeared?

Step 1

```bash id="b3b2vd"
kubectl describe pod POD_NAME
```

---

Look for:

```text id="sv7sul"
Evicted
```

---

Step 2

Check node:

```bash id="u66cxy"
kubectl describe node NODE_NAME
```

---

Look for:

```text id="06vjlwm"
DiskPressure
```

---

Step 3

Check events:

```bash id="dxyg9k"
kubectl get events \
--sort-by=.metadata.creationTimestamp
```

---

Step 4

Check storage usage:

```bash id="fxg20d"
kubectl top node
```

and node filesystem.

---

# Common Mistakes

---

## Ignoring Ephemeral Storage

Many engineers configure:

```yaml id="8a5r8n"
CPU

Memory
```

but ignore:

```yaml id="6b7d2u"
ephemeral-storage
```

---

Result:

```text id="sihbgk"
DiskPressure
```

incidents.

---

## Using emptyDir For Databases

Wrong:

```text id="98d6q8"
Database Data
```

inside:

```yaml id="85z0jp"
emptyDir
```

---

Result:

```text id="jlwmze"
Data Loss
```

when Pod restarts.

---

## Unlimited Logging

Problem:

```text id="n6c6wq"
Logs Fill Disk
```

---

## Huge Temporary Files

Problem:

```text id="k5eclu"
Storage Evictions
```

---

# Interview Questions

---

## What Is Ephemeral Storage?

Answer:

```text id="a3m0c2"
Temporary Node Storage

Used By Pods
```

---

## Does Ephemeral Storage Survive Pod Deletion?

Answer:

```text id="1i77xn"
No
```

---

## What Consumes Ephemeral Storage?

Answer:

```text id="4e7t4o"
Logs

Writable Layer

emptyDir

Temporary Files
```

---

## What Is emptyDir?

Answer:

```text id="7h3ylx"
Temporary Volume

Deleted With Pod
```

---

## What Happens When Ephemeral Storage Limit Is Exceeded?

Answer:

```text id="u8hpxd"
Pod May Be Evicted
```

---

## What Node Condition Indicates Disk Problems?

Answer:

```text id="2vnmce"
DiskPressure
```

---

## Is Ephemeral Storage Persistent?

Answer:

```text id="hf3y1w"
No
```

---

## Should Databases Use emptyDir?

Answer:

```text id="zbdm2f"
No

Use Persistent Volumes
```

---

# Cleanup

Delete demo pod:

```bash id="v4zkwg"
kubectl delete pod emptydir-demo
```

---

Remove temporary files:

```bash id="z5i7np"
curl \
"http://localhost:8080/cleanup-disk"
```

---

# Key Takeaways

```text id="7t2v0u"
Ephemeral Storage
=
Temporary Storage

emptyDir
=
Deleted With Pod

Logs
=
Consume Disk

Writable Layer
=
Consumes Disk

DiskPressure
=
Node Running Low On Disk

Storage Limit Exceeded
=
Possible Eviction

Database Data
=
Use Persistent Volumes
```

Ephemeral storage is one of the most overlooked Kubernetes resources, yet it is responsible for many real-world outages caused by log growth, temporary file leaks, and full node filesystems.
