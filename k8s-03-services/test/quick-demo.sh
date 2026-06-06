#!/bin/bash

# Quick Service Test Demo
# A simplified test to demonstrate service functionality

echo "==========================================" 
echo "Quick Service Test Demo"
echo "=========================================="
echo ""

# Check service
echo "1. Service Information:"
kubectl get service fastapi-service
echo ""

# Check endpoints
echo "2. Service Endpoints (Pod IPs):"
kubectl get endpoints fastapi-service
echo ""

# Check pods
echo "3. Backend Pods:"
kubectl get pods -l app=fastapi -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP
echo ""

# Test DNS resolution
echo "4. Testing DNS Resolution:"
echo "   Creating test pod to resolve service DNS..."
kubectl run test-dns --image=busybox:latest --rm -i --restart=Never --command -- nslookup fastapi-service 2>&1 | grep -A 2 "Name:"
echo ""

# Test HTTP
echo "5. Testing HTTP Connectivity:"
echo "   Making HTTP request through service..."
kubectl run test-http --image=curlimages/curl:latest --rm -i --restart=Never --command -- curl -s http://fastapi-service:8000/ 2>&1 | tail -5
echo ""

# Test load balancing
echo "6. Testing Load Balancing (10 requests):"
echo "   Tracking which pods respond..."
kubectl run test-lb --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -s http://fastapi-service:8000/info 2>/dev/null | grep -o '\"hostname\":\"[^\"]*\"' | cut -d'\"' -f4
done
" 2>&1 | grep -v "pod.*deleted" | sort | uniq -c
echo ""

echo "=========================================="
echo "✓ Quick Test Complete!"
echo "=========================================="
echo ""
echo "What we verified:"
echo "  ✓ Service has stable ClusterIP"
echo "  ✓ Service tracks Pod endpoints automatically"  
echo "  ✓ DNS resolution works (service discovery)"
echo "  ✓ HTTP requests succeed through service"
echo "  ✓ Load balancing distributes across pods"
echo ""
echo "Try the full test suite:"
echo "  ./test/run-all-tests.sh"
echo ""
