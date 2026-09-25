# 16 - Cluster Autoscaler (CA)

---

# Learning Objectives

By the end of this module you will understand:

* What Cluster Autoscaler is
* Why Cluster Autoscaler exists
* Cluster Autoscaler architecture
* Node Groups
* Scale-Up behavior
* Scale-Down behavior
* Unschedulable Pods
* Pending Pods
* Bin Packing
* HPA + CA interaction
* Cost Optimization
* Cloud Provider Integrations
* Production Troubleshooting
* Interview Questions

---

# The Autoscaling Trilogy

By now you've learned:

---

HPA:

```text id="ca1"
More Pods
```

---

VPA:

```text id="ca2"
Bigger Pods
```

---

Cluster Autoscaler:

```text id="ca3"
More Nodes
```

---

Together:

```text id="ca4"
Application

↓

Pods

↓

Nodes
```

scale automatically.

---

# Real Production Problem

Cluster:

```text id="ca5"
3 Nodes

4 CPU Each
```

---

Total Capacity:

```text id="ca6"
12 CPU
```

---

Current Usage:

```text id="ca7"
11 CPU
```

---

HPA decides:

```text id="ca8"
Scale

10 Pods

↓

20 Pods
```

---

New Pods require:

```text id="ca9"
5 CPU
```

---

Available:

```text id="ca10"
1 CPU
```

---

Result:

```text id="ca11"
Pods Remain Pending
```

---

Question:

Should engineers manually add nodes?

---

Answer:

```text id="ca12"
No

Cluster Autoscaler
```

---

# What Is Cluster Autoscaler?

Cluster Autoscaler (CA):

```text id="ca13"
Automatically Adds

Or Removes

Worker Nodes
```

based on:

```text id="ca14"
Scheduling Demand
```

---

When Pods cannot fit:

```text id="ca15"
Add Nodes
```

---

When Nodes become empty:

```text id="ca16"
Remove Nodes
```

---

# HPA Alone Is Not Enough

Without CA:

```text id="ca17"
HPA Creates Pods
```

---

But:

```text id="ca18"
No Node Capacity
```

---

Result:

```text id="ca19"
Pending Pods
```

---

HPA scales:

```text id="ca20"
Pods
```

---

CA scales:

```text id="ca21"
Infrastructure
```

---

# Cluster Autoscaler Architecture

```text id="ca22"
Pending Pod

↓

Scheduler Fails

↓

Cluster Autoscaler Detects

↓

Cloud Provider API

↓

New Node Created

↓

Node Joins Cluster

↓

Pod Scheduled
```

---

# Supported Providers

Cluster Autoscaler commonly works with:

```text id="ca23"
AWS EKS

Google GKE

Azure AKS

OpenShift

Cluster API
```

---

# Node Groups

Cluster Autoscaler scales:

```text id="ca24"
Node Groups
```

not individual arbitrary nodes.

---

Example:

```text id="ca25"
Node Group A

t3.medium
```

---

```text id="ca26"
Node Group B

m5.large
```

---

Each group has:

```text id="ca27"
Minimum Nodes

Maximum Nodes
```

---

# Example Node Group

```text id="ca28"
Min = 2

Max = 10
```

---

Current:

```text id="ca29"
3 Nodes
```

---

CA may increase:

```text id="ca30"
4

5

6

...
```

until:

```text id="ca31"
10
```

---

# Scale-Up Process

Pod:

```yaml id="ca32"
requests:
  cpu: "2"
  memory: "4Gi"
```

---

Scheduler attempts placement.

---

Result:

```text id="ca33"
No Node Fits
```

---

Pod status:

```text id="ca34"
Pending
```

---

Scheduler event:

```text id="ca35"
Insufficient CPU
```

---

CA detects:

```text id="ca36"
Unschedulable Pod
```

---

CA adds:

```text id="ca37"
New Node
```

---

Pod becomes:

```text id="ca38"
Running
```

---

# Detecting Pending Pods

Check:

```bash id="ca39"
kubectl get pods
```

---

Example:

```text id="ca40"
Pending
```

---

Describe:

```bash id="ca41"
kubectl describe pod POD_NAME
```

---

Look for:

```text id="ca42"
Insufficient CPU

Insufficient Memory
```

---

These are common CA triggers.

---

# Scale-Up Example

Cluster:

```text id="ca43"
2 Nodes

4 CPU Each
```

---

Capacity:

```text id="ca44"
8 CPU
```

---

Workload:

```text id="ca45"
7.8 CPU
```

---

New Pod:

```text id="ca46"
1 CPU
```

---

Cannot fit.

---

Result:

```text id="ca47"
Scale Up
```

---

New node added:

```text id="ca48"
4 CPU
```

---

Pod schedules successfully.

---

# Scale-Down Process

Now traffic drops.

---

HPA scales:

```text id="ca49"
20 Pods

↓

2 Pods
```

---

Several nodes become:

```text id="ca50"
Empty
```

or

```text id="ca51"
Underutilized
```

---

CA detects:

```text id="ca52"
Unused Capacity
```

---

Nodes removed.

---

Result:

```text id="ca53"
Lower Cloud Cost
```

---

# Scale-Down Safety

CA does NOT immediately remove nodes.

---

Checks include:

```text id="ca54"
Pod Disruption Constraints

Node Utilization

Eviction Safety
```

---

Prevents:

```text id="ca55"
Accidental Outages
```

---

# Bin Packing

Cluster Autoscaler tries to:

```text id="ca56"
Pack Workloads Efficiently
```

---

Example:

Nodes:

```text id="ca57"
Node A

10% Used
```

```text id="ca58"
Node B

15% Used
```

---

Pods may be consolidated.

---

Result:

```text id="ca59"
Remove One Node
```

---

Cost savings.

---

# Most Important Dependency

Cluster Autoscaler depends on:

```text id="ca60"
Requests
```

---

Not:

```text id="ca61"
Actual Usage
```

---

Example:

```yaml id="ca62"
requests:
  cpu: "4"
```

---

Actual:

```text id="ca63"
100m
```

---

Scheduler sees:

```text id="ca64"
4 CPU
```

---

CA sees:

```text id="ca65"
4 CPU
```

---

Result:

```text id="ca66"
Extra Nodes
```

may be created unnecessarily.

---

# Why Requests Matter Again

Bad requests cause:

```text id="ca67"
Bad Scheduling
```

---

Bad scheduling causes:

```text id="ca68"
Bad Autoscaling
```

---

Bad autoscaling causes:

```text id="ca69"
High Cloud Costs
```

---

Everything starts with:

```text id="ca70"
Accurate Requests
```

---

# HPA + CA Interaction

Most common production architecture.

---

Traffic spike:

```text id="ca71"
More Requests
```

---

HPA:

```text id="ca72"
Creates Pods
```

---

Cluster full:

```text id="ca73"
Pending Pods
```

---

CA:

```text id="ca74"
Adds Nodes
```

---

Pods schedule.

---

Traffic handled.

---

Visual:

```text id="ca75"
Traffic

↓

HPA

↓

More Pods

↓

CA

↓

More Nodes
```

---

# HPA Without CA

Traffic spike:

```text id="ca76"
More Pods Needed
```

---

HPA creates:

```text id="ca77"
Pods
```

---

Cluster:

```text id="ca78"
No Capacity
```

---

Result:

```text id="ca79"
Pending Pods
```

---

Service suffers.

---

# CA Without HPA

Cluster can add nodes.

---

But:

```text id="ca80"
No New Pods Created
```

---

Result:

```text id="ca81"
Unused Infrastructure
```

---

Usually both are needed.

---

# Viewing Cluster Autoscaler

Provider-specific.

---

Common namespace:

```bash id="ca82"
kubectl get pods \
-n kube-system
```

---

Look for:

```text id="ca83"
cluster-autoscaler
```

---

Logs:

```bash id="ca84"
kubectl logs \
-n kube-system \
deployment/cluster-autoscaler
```

---

Useful for troubleshooting.

---

# Scale-Up Troubleshooting

Pod Pending?

---

Describe:

```bash id="ca85"
kubectl describe pod POD_NAME
```

---

Look for:

```text id="ca86"
Insufficient CPU

Insufficient Memory
```

---

Check CA logs:

```bash id="ca87"
kubectl logs \
-n kube-system \
deployment/cluster-autoscaler
```

---

Question:

```text id="ca88"
Did CA Detect Pod?
```

---

# Scale-Down Troubleshooting

Nodes not removed?

---

Possible reasons:

```text id="ca89"
DaemonSets

Local Storage

PDB

Recent Activity
```

---

Check logs:

```bash id="ca90"
kubectl logs \
-n kube-system \
deployment/cluster-autoscaler
```

---

# Common Production Issues

---

## Requests Too Large

Example:

```yaml id="ca91"
requests:
  cpu: "8"
```

---

Actual:

```text id="ca92"
100m
```

---

Result:

```text id="ca93"
Excess Nodes
```

---

Very expensive.

---

## Requests Too Small

Example:

```yaml id="ca94"
requests:
  cpu: "10m"
```

---

Actual:

```text id="ca95"
2 CPU
```

---

Result:

```text id="ca96"
Node Saturation
```

---

CA may not scale properly.

---

## Max Node Limit Reached

Node Group:

```text id="ca97"
Max = 10
```

---

Already:

```text id="ca98"
10 Nodes
```

---

CA cannot scale further.

---

Pods remain:

```text id="ca99"
Pending
```

---

# Production Best Practices

---

Use:

```text id="ca100"
HPA + CA
```

together.

---

Configure:

```text id="ca101"
Reasonable Requests
```

---

Monitor:

```text id="ca102"
Pending Pods
```

---

Monitor:

```text id="ca103"
Node Utilization
```

---

Review:

```text id="ca104"
Node Group Limits
```

regularly.

---

# Cost Optimization

Cluster Autoscaler is one of the biggest cloud cost optimizers.

---

Without CA:

```text id="ca105"
20 Nodes

24 Hours/Day
```

---

With CA:

```text id="ca106"
20 Nodes Peak

3 Nodes Overnight
```

---

Savings:

```text id="ca107"
Significant
```

---

# Useful Commands

Pending Pods:

```bash id="ca108"
kubectl get pods
```

---

Describe:

```bash id="ca109"
kubectl describe pod POD_NAME
```

---

Nodes:

```bash id="ca110"
kubectl get nodes
```

---

Node usage:

```bash id="ca111"
kubectl top node
```

---

Autoscaler logs:

```bash id="ca112"
kubectl logs \
-n kube-system \
deployment/cluster-autoscaler
```

---

# Interview Questions

---

## What Does Cluster Autoscaler Scale?

Answer:

```text id="ca113"
Nodes
```

---

## What Does HPA Scale?

Answer:

```text id="ca114"
Pods
```

---

## What Does VPA Scale?

Answer:

```text id="ca115"
Requests And Limits
```

---

## What Triggers Cluster Autoscaler Scale-Up?

Answer:

```text id="ca116"
Unschedulable Pods
```

---

## Does CA Use Actual Usage?

Answer:

```text id="ca117"
No

Uses Scheduling Requirements
```

---

## Why Are Requests Important For CA?

Answer:

```text id="ca118"
Scheduler Uses Requests
```

---

## What Happens If Node Group Max Is Reached?

Answer:

```text id="ca119"
Pods Remain Pending
```

---

## Most Common Production Pattern?

Answer:

```text id="ca120"
HPA + Cluster Autoscaler
```

---

# Cleanup

No cleanup required.

If demo workloads were created:

```bash id="ca121"
kubectl delete deployment loadtest
```

---

# Key Takeaways

```text id="ca122"
HPA
=
More Pods

VPA
=
Bigger Pods

CA
=
More Nodes

Scale-Up
=
Pending Pods

Scale-Down
=
Unused Nodes

CA Uses
=
Requests

Accurate Requests
=
Accurate Autoscaling

Production
=
HPA + CA
```

Cluster Autoscaler completes Kubernetes autoscaling by ensuring that infrastructure grows and shrinks automatically based on workload demand. Together with HPA and VPA, it enables fully automated, cost-efficient, and scalable Kubernetes platforms.
