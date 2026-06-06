✅ Concepts Covered in Project 03

# 1 . Load Balancing ✅ COVERED
What we did:

- Created ClusterIP service that load balances across 3 pods
- Verified traffic distribution using load balancing test:
```text
Pod 7gzgg: 5 requests
Pod qp92c: 3 requests  
Pod vxsvd: 2 requests
```
- Built test-load-balancing.sh to demonstrate round-robin distribution
- Documented LoadBalancer service type for cloud providers

### Files:

- k8s/service-clusterip.yaml - Internal load balancing
- k8s/service-loadbalancer.yaml - External load balancing
- test/test-load-balancing.sh - Verification script

# 2. Networking ✅ COVERED
What we did:

- Understood Pod IPs vs Service IPs (stable vs ephemeral)
- Learned about ClusterIP (10.97.71.170) - cluster-internal network
- Learned about NodePort (port 30080) - external network access
- Configured port mappings (port 8000 → targetPort 8000)
- Used kubectl port-forward to bridge local & cluster network

### Files:

- All 3 service YAMLs (ClusterIP, NodePort, LoadBalancer)
- Networking concepts in README.md

# 3. Service Discovery ✅ COVERED
What we did:

- Learned DNS-based service discovery in Kubernetes
- Tested 3 DNS patterns:
  - Short: fastapi-service
  - Namespace-qualified: fastapi-service.default
  - FQDN: fastapi-service.default.svc.cluster.local
- Created test-dns pod to test DNS resolution interactively
- Built test-service-discovery.sh for automated DNS testing
- Verified kubectl get endpoints tracks pod IPs automatically

### Files:

-  test/test-service-discovery.sh
-  test/k8s/dns-resolution-testing-pod.yaml

🎯 Bonus Things You Learned
- Endpoints - How services track pod IPs
- Labels & Selectors - How services find pods
- 3 Service Types - ClusterIP, NodePort, LoadBalancer
- Self-healing integration - Services auto-update when pods restart

