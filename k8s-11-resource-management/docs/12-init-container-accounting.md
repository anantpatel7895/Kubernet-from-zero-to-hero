# 12 - Init Container Accounting

---

# Learning Objectives

By the end of this module you will understand:

* What Init Containers are
* How Init Containers differ from normal containers
* Why Kubernetes calculates Init Container resources differently
* Effective Pod Request calculations
* Effective Pod Limit calculations
* Scheduler behavior with Init Containers
* Init Container resource accounting formulas
* Common production use cases
* Capacity planning implications
* Troubleshooting Init Container failures
* Advanced interview questions

---

# What Is An Init Container?

An Init Container is a special container that:

```text id="i1"
Runs Before

Application Containers
```

---

Workflow:

```text id="i2"
Init Container 1

↓

Init Container 2

↓

Init Container 3

↓

Application Starts
```

---

Important:

```text id="i3"
Init Containers

Run Sequentially
```

---

Regular containers:

```text id="i4"
Run Together
```

---

# Why Init Containers Exist

Common tasks:

```text id="i5"
Database Migration

Schema Validation

Configuration Generation

Secrets Preparation

Dependency Checks

Waiting For Services
```

---

Example:

```text id="i6"
Wait Until Database

Is Reachable
```

before application starts.

---

# Example Init Container

```yaml id="i7"
apiVersion: v1
kind: Pod

metadata:
  name: init-demo

spec:

  initContainers:
  - name: wait-for-db

    image: busybox

    command:
    - sh
    - -c
    - sleep 30

  containers:
  - name: app

    image: nginx
```

---

Deployment:

```bash id="i8"
kubectl apply -f init-demo.yaml
```

---

Observe:

```bash id="i9"
kubectl get pod init-demo -w
```

Expected:

```text id="i10"
Init:0/1

↓

Running
```

---

# Init Container Lifecycle

Important sequence:

```text id="i11"
Init Container

Starts

↓

Completes

↓

Stops

↓

Application Starts
```

---

Init container:

```text id="i12"
Does Not Stay Running
```

after startup.

---

# Resource Accounting Challenge

Question:

```text id="i13"
Application

Needs

100m CPU
```

---

Init container needs:

```text id="i14"
2 CPU
```

---

What should scheduler reserve?

```text id="i15"
100m ?

or

2 CPU ?
```

---

Answer:

```text id="i16"
2 CPU
```

---

Why?

Because Pod cannot start unless:

```text id="i17"
Init Container Can Run
```

---

# Most Important Formula

Normal containers:

```text id="i18"
Resources

Added Together
```

---

Init containers:

```text id="i19"
Resources

Maximum Value Used
```

---

Because:

```text id="i20"
Init Containers

Never Run Together
```

---

# Example 1

Init Container:

```yaml id="i21"
requests:
  cpu: "2"
  memory: "512Mi"
```

---

Application:

```yaml id="i22"
requests:
  cpu: "100m"
  memory: "128Mi"
```

---

Effective Pod Request:

```text id="i23"
CPU

max(2 , 100m)

=
2 CPU
```

---

Memory:

```text id="i24"
max(512Mi , 128Mi)

=
512Mi
```

---

Scheduler sees:

```text id="i25"
CPU

2

Memory

512Mi
```

---

Not:

```text id="i26"
100m
```

---

# Example 2

Two Init Containers

```yaml id="i27"
initContainers:

- cpu: 1

- cpu: 3
```

---

Application:

```yaml id="i28"
cpu: 500m
```

---

Effective Request:

```text id="i29"
max(1,3,500m)

=
3 CPU
```

---

# Why Not Sum Them?

Because:

```text id="i30"
Init Containers

Run Sequentially
```

---

Timeline:

```text id="i31"
Init-1

↓

Init-2

↓

Application
```

---

Never:

```text id="i32"
Run Simultaneously
```

---

# Full Example

```yaml id="i33"
apiVersion: v1
kind: Pod

metadata:
  name: resource-init-demo

spec:

  initContainers:

  - name: migration

    image: busybox

    command:
    - sh
    - -c
    - sleep 30

    resources:
      requests:
        cpu: "2"
        memory: "1Gi"

  containers:

  - name: app

    image: nginx

    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
```

---

Deploy:

```bash id="i34"
kubectl apply \
-f resource-init-demo.yaml
```

---

Question:

What request does scheduler use?

Answer:

```text id="i35"
CPU

2
```

---

Memory:

```text id="i36"
1Gi
```

---

# Scheduling Implications

Node:

```text id="i37"
CPU

1 Core
```

---

Application:

```text id="i38"
100m CPU
```

---

Init:

```text id="i39"
2 CPU
```

---

Can Pod Schedule?

Answer:

```text id="i40"
No
```

---

Reason:

```text id="i41"
Init Container

Cannot Fit
```

---

Pod becomes:

```text id="i42"
Pending
```

---

# Common Production Surprise

Application:

```text id="i43"
Uses

100m CPU
```

---

Engineers think:

```text id="i44"
Small Pod
```

---

Migration Init Container:

```text id="i45"
4 CPU
```

---

Scheduler sees:

```text id="i46"
4 CPU Pod
```

---

Result:

```text id="i47"
Pending
```

---

Confusing until Init accounting is understood.

---

# Effective Resource Formula

Pod CPU Request:

```text id="i48"
max(

largest init container request,

sum(application container requests)

)
```

---

Pod Memory Request:

```text id="i49"
max(

largest init memory request,

sum(application memory requests)

)
```

---

This is the formula Kubernetes uses.

---

# Multi-Container Application Example

Application:

```yaml id="i50"
containers:

- cpu: 100m

- cpu: 200m
```

---

Application total:

```text id="i51"
300m
```

---

Init:

```yaml id="i52"
cpu: 2
```

---

Effective request:

```text id="i53"
max(2,300m)

=
2 CPU
```

---

# Init Container Limits

Limits follow same principle.

Example:

```yaml id="i54"
init:
  limit:
    cpu: 4
```

---

Application:

```yaml id="i55"
limit:
  cpu: 1
```

---

Effective Pod Limit:

```text id="i56"
4 CPU
```

---

# Real Production Examples

---

## Database Migration

```text id="i57"
Run Schema Migration

Before Application Starts
```

---

Resources:

```text id="i58"
High CPU

High Memory
```

for short period.

---

## Cache Warmup

```text id="i59"
Download Data

Populate Cache
```

before serving traffic.

---

## ML Model Download

```text id="i60"
Download 10GB Model
```

during startup.

---

Requires:

```text id="i61"
Large CPU

Large Memory

Large Disk
```

briefly.

---

# Viewing Init Containers

Describe Pod:

```bash id="i62"
kubectl describe pod POD_NAME
```

---

Look for:

```text id="i63"
Init Containers
```

section.

---

Example:

```text id="i64"
State

Terminated

Reason

Completed
```

---

Normal behavior.

---

# Watching Startup

```bash id="i65"
kubectl get pod \
-w
```

---

States:

```text id="i66"
Init:0/1

Init:1/1

Running
```

---

# Troubleshooting

---

## Pod Stuck In Init

Check:

```bash id="i67"
kubectl logs POD_NAME \
-c INIT_CONTAINER_NAME
```

---

Common issue:

```text id="i68"
Database Not Reachable
```

---

## Pod Pending

Check:

```bash id="i69"
kubectl describe pod POD_NAME
```

---

Question:

```text id="i70"
Large Init Request?
```

---

Often overlooked.

---

## Startup Slow

Check:

```bash id="i71"
kubectl describe pod POD_NAME
```

and:

```bash id="i72"
kubectl logs POD_NAME \
-c INIT_CONTAINER_NAME
```

---

# Common Mistakes

---

## Ignoring Init Resources

Developers calculate:

```text id="i73"
Application Only
```

---

Scheduler calculates:

```text id="i74"
Init + Application
```

---

## Large Migration Containers

```yaml id="i75"
requests:
  cpu: "8"
```

---

Result:

```text id="i76"
Pods Cannot Schedule
```

---

## Infinite Wait Loops

Init:

```bash id="i77"
while true
```

---

Result:

```text id="i78"
Application Never Starts
```

---

## Forgetting Logs

Use:

```bash id="i79"
kubectl logs \
-c INIT_CONTAINER
```

---

Not:

```text id="i80"
Application Logs
```

---

# Production Recommendations

---

Use Init Containers For:

```text id="i81"
Setup Tasks

Validation

Migrations

Bootstrap Logic
```

---

Avoid:

```text id="i82"
Long Running Services
```

---

Keep Requests:

```text id="i83"
As Small As Possible
```

to avoid:

```text id="i84"
Scheduling Failures
```

---

# Interview Questions

---

## What Is An Init Container?

Answer:

```text id="i85"
Container That Runs

Before Application Containers
```

---

## Do Init Containers Run Concurrently?

Answer:

```text id="i86"
No

Sequentially
```

---

## How Are Init Requests Calculated?

Answer:

```text id="i87"
Maximum Request

Not Sum
```

---

## Why Not Sum Init Requests?

Answer:

```text id="i88"
Init Containers

Never Run Together
```

---

## Can Init Containers Affect Scheduling?

Answer:

```text id="i89"
Yes

Significantly
```

---

## Pod Uses 100m CPU

Init Uses 2 CPU

What Does Scheduler Use?

Answer:

```text id="i90"
2 CPU
```

---

## How Do You View Init Container Logs?

Answer:

```bash id="i91"
kubectl logs POD_NAME \
-c INIT_CONTAINER_NAME
```

---

## Common Status For Init Container?

Answer:

```text id="i92"
Completed
```

---

# Cleanup

```bash id="i93"
kubectl delete pod \
init-demo

kubectl delete pod \
resource-init-demo
```

---

# Key Takeaways

```text id="i94"
Init Containers

Run First

Run Sequentially

Do Not Stay Running

Resource Formula

max(

largest init request,

sum(app requests)

)

Scheduler

Uses Effective Pod Request

Large Init Containers

Can Cause Pending Pods
```

Understanding Init Container accounting is considered an advanced Kubernetes topic because many engineers incorrectly assume only application containers affect scheduling. In reality, a single oversized init container can make an otherwise tiny application impossible to schedule.
