# 13 - PriorityClass and Preemption

---

# Learning Objectives

By the end of this module you will understand:

* What PriorityClass is
* Why PriorityClass exists
* How Kubernetes schedules high-priority workloads
* What preemption is
* How scheduler victim selection works
* PriorityClass vs QoS
* Critical system workloads
* Production outage scenarios
* Cluster resource starvation
* How to troubleshoot preemption events
* Best practices for workload prioritization

---

# Real Production Problem

Imagine a cluster:

```text id="p1"
CPU: 100

Memory: 200Gi
```

Current usage:

```text id="p2"
CPU: 99

Memory: 190Gi
```

Cluster almost full.

---

Suddenly:

```text id="p3"
Payment Service
```

needs deployment.

---

But cluster capacity:

```text id="p4"
Not Available
```

---

Question:

Should Kubernetes reject:

```text id="p5"
Payment Service
```

or remove:

```text id="p6"
Low Priority Batch Jobs
```

?

---

Production answer:

```text id="p7"
Remove Less Important Workloads
```

---

This is why:

```text id="p8"
PriorityClass
```

exists.

---

# What Is PriorityClass?

PriorityClass assigns:

```text id="p9"
Business Importance
```

to workloads.

---

Examples:

```text id="p10"
Critical Database

High Priority
```

```text id="p11"
Frontend API

High Priority
```

```text id="p12"
Analytics Job

Medium Priority
```

```text id="p13"
Temporary Batch Job

Low Priority
```

---

# Priority Values

PriorityClass uses:

```text id="p14"
Integer Values
```

Higher value:

```text id="p15"
Higher Priority
```

---

Example:

```yaml id="p16"
value: 1000
```

Higher than:

```yaml id="p17"
value: 100
```

---

# Create Priority Classes

Low Priority:

```yaml id="p18"
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass

metadata:
  name: low-priority

value: 100

globalDefault: false

description: Low priority workloads
```

---

High Priority:

```yaml id="p19"
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass

metadata:
  name: high-priority

value: 1000

globalDefault: false

description: Critical workloads
```

---

Deploy:

```bash id="p20"
kubectl apply \
-f low-priority.yaml

kubectl apply \
-f high-priority.yaml
```

---

Verify:

```bash id="p21"
kubectl get priorityclass
```

Expected:

```text id="p22"
low-priority

high-priority
```

---

# Assigning Priority

Pod:

```yaml id="p23"
spec:
  priorityClassName: high-priority
```

---

Example:

```yaml id="p24"
apiVersion: v1
kind: Pod

metadata:
  name: payment-service

spec:

  priorityClassName: high-priority

  containers:
  - name: app
    image: busybox

    command:
    - sh
    - -c
    - sleep 3600
```

---

# Verify Priority

Deploy Pod.

Check:

```bash id="p25"
kubectl get pod payment-service \
-o yaml
```

Look for:

```yaml id="p26"
priority: 1000
```

Automatically assigned.

---

# What Is Preemption?

Preemption means:

```text id="p27"
Remove Lower Priority Pods

To Schedule

Higher Priority Pods
```

---

Think of:

```text id="p28"
Emergency Vehicle
```

on a crowded road.

---

Traffic:

```text id="p29"
Moves Aside
```

for:

```text id="p30"
Ambulance
```

---

Same concept.

---

# Preemption Workflow

Cluster:

```text id="p31"
Full
```

---

New Pod:

```text id="p32"
High Priority
```

---

Scheduler:

```text id="p33"
No Capacity
```

---

Scheduler searches:

```text id="p34"
Lower Priority Victims
```

---

Victims removed:

```text id="p35"
Evicted
```

---

High-priority Pod:

```text id="p36"
Scheduled
```

---

# Preemption Demo

Node:

```text id="p37"
1 CPU
```

---

Low Priority Pod:

```yaml id="p38"
apiVersion: v1
kind: Pod

metadata:
  name: low-priority

spec:

  priorityClassName: low-priority

  containers:
  - name: app

    image: busybox

    command:
    - sh
    - -c
    - sleep 3600

    resources:
      requests:
        cpu: "900m"
        memory: "256Mi"
```

---

Deploy:

```bash id="p39"
kubectl apply \
-f low-priority-pod.yaml
```

---

Node nearly full.

---

Create:

```yaml id="p40"
apiVersion: v1
kind: Pod

metadata:
  name: high-priority

spec:

  priorityClassName: high-priority

  containers:
  - name: app

    image: busybox

    command:
    - sh
    - -c
    - sleep 3600

    resources:
      requests:
        cpu: "900m"
        memory: "256Mi"
```

---

Deploy:

```bash id="p41"
kubectl apply \
-f high-priority-pod.yaml
```

---

Expected:

```text id="p42"
Low Priority Pod

Preempted
```

---

High-priority pod:

```text id="p43"
Scheduled
```

---

# Viewing Preemption Events

Check:

```bash id="p44"
kubectl describe pod high-priority
```

---

Events:

```text id="p45"
Preempted

Lower Priority Pods
```

---

May show:

```text id="p46"
Preemption Victims
```

---

# Victim Selection

Scheduler chooses victims that:

```text id="p47"
Free Enough Resources
```

while minimizing disruption.

---

Example:

Need:

```text id="p48"
1 CPU
```

---

Candidates:

```text id="p49"
Pod A

100m
```

```text id="p50"
Pod B

200m
```

```text id="p51"
Pod C

900m
```

---

Scheduler often selects:

```text id="p52"
Pod C
```

because:

```text id="p53"
Single Victim
```

may be sufficient.

---

# PriorityClass vs QoS

Extremely important.

---

QoS:

```text id="p54"
Resource Protection
```

---

PriorityClass:

```text id="p55"
Business Importance
```

---

QoS Example:

```text id="p56"
Guaranteed

Burstable

BestEffort
```

---

Priority Example:

```text id="p57"
100

1000

10000
```

---

Completely different systems.

---

# Common Interview Question

Which wins?

```text id="p58"
Guaranteed

Low Priority
```

vs

```text id="p59"
Burstable

High Priority
```

---

Answer:

```text id="p60"
Depends On Context

Priority Often Dominates

Scheduling Decisions
```

---

# System-Critical Priority Classes

Kubernetes ships with:

```text id="p61"
system-node-critical
```

and:

```text id="p62"
system-cluster-critical
```

---

Used by:

```text id="p63"
DNS

Networking

Control Plane Components
```

---

View:

```bash id="p64"
kubectl get priorityclass
```

---

Example:

```text id="p65"
system-cluster-critical
```

---

Do NOT use:

```text id="p66"
system-critical

For Application Pods
```

unless absolutely necessary.

---

# Production Example

Cluster:

```text id="p67"
E-Commerce
```

---

Critical:

```text id="p68"
Checkout

Payment

Authentication
```

Priority:

```text id="p69"
1000
```

---

Normal:

```text id="p70"
Product Search
```

Priority:

```text id="p71"
500
```

---

Batch:

```text id="p72"
Analytics
```

Priority:

```text id="p73"
100
```

---

Resource shortage:

```text id="p74"
Analytics

Gets Preempted
```

---

Business continues.

---

# Production Strategy

High Priority:

```text id="p75"
Revenue Generating Services
```

---

Medium Priority:

```text id="p76"
Customer Facing APIs
```

---

Low Priority:

```text id="p77"
Batch Jobs

Reporting

ETL
```

---

# PodDisruptionBudget Interaction

PDB:

```text id="p78"
Attempts To Protect Pods
```

---

Preemption:

```text id="p79"
May Still Occur
```

depending on scheduling requirements.

---

Do not assume:

```text id="p80"
PDB

Prevents

All Preemption
```

---

# Troubleshooting

---

## Pod Pending

Check:

```bash id="p81"
kubectl describe pod POD_NAME
```

---

Question:

```text id="p82"
Could Preemption Help?
```

---

Look for:

```text id="p83"
Preemption Candidates
```

---

## Pod Suddenly Missing

Check:

```bash id="p84"
kubectl get events \
--sort-by=.metadata.creationTimestamp
```

---

Look for:

```text id="p85"
Preempted
```

---

## High Priority Not Scheduling

Check:

```bash id="p86"
kubectl describe pod POD_NAME
```

---

Possible reasons:

```text id="p87"
No Suitable Victims

Affinity Rules

Taints

Quota Limits
```

---

# Common Mistakes

---

## Everything High Priority

Bad practice.

Example:

```text id="p88"
All Pods

Priority 1000
```

---

Then:

```text id="p89"
Priority Loses Meaning
```

---

## Critical Batch Jobs

Incorrect classification.

---

Batch workloads usually:

```text id="p90"
Lowest Priority
```

---

## Ignoring Side Effects

Preemption causes:

```text id="p91"
Workload Disruption
```

Use carefully.

---

## Confusing QoS And Priority

Very common interview mistake.

---

QoS:

```text id="p92"
Resource Behavior
```

Priority:

```text id="p93"
Business Importance
```

---

# Advanced Scenario

Cluster:

```text id="p94"
100% Full
```

---

New payment service:

```text id="p95"
Priority 10000
```

---

Analytics jobs:

```text id="p96"
Priority 100
```

---

Scheduler:

```text id="p97"
Removes Analytics

Schedules Payment
```

---

Exactly as intended.

---

# Interview Questions

---

## What Is PriorityClass?

Answer:

```text id="p98"
Scheduling Importance Level
```

---

## What Is Preemption?

Answer:

```text id="p99"
Removing Lower Priority Pods

To Schedule Higher Priority Pods
```

---

## Higher Value Means?

Answer:

```text id="p100"
Higher Priority
```

---

## Does PriorityClass Affect QoS?

Answer:

```text id="p101"
No
```

---

## Does QoS Affect Priority?

Answer:

```text id="p102"
No
```

---

## How Do You View Priority Classes?

Answer:

```bash id="p103"
kubectl get priorityclass
```

---

## What Built-In Priority Classes Exist?

Answer:

```text id="p104"
system-node-critical

system-cluster-critical
```

---

## Why Use PriorityClass?

Answer:

```text id="p105"
Protect Important Workloads
```

---

## Can Preemption Remove Running Pods?

Answer:

```text id="p106"
Yes
```

---

# Cleanup

```bash id="p107"
kubectl delete pod low-priority

kubectl delete pod high-priority
```

---

Delete PriorityClasses:

```bash id="p108"
kubectl delete priorityclass low-priority

kubectl delete priorityclass high-priority
```

---

# Key Takeaways

```text id="p109"
PriorityClass
=
Business Importance

Higher Value
=
Higher Priority

Preemption
=
Remove Lower Priority Pods

QoS
=
Resource Behavior

PriorityClass
=
Scheduling Importance

Critical Services
=
High Priority

Batch Jobs
=
Low Priority
```

PriorityClass and preemption allow Kubernetes to make business-aware scheduling decisions, ensuring that critical workloads continue running even when the cluster is under severe resource pressure.
