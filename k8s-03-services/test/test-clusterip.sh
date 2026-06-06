#!/bin/bash

# Test ClusterIP Service
# This script tests the ClusterIP service which provides internal cluster access only

set -e

echo "=========================================="
echo "Testing ClusterIP Service"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if service exists
echo "1. Checking if service exists..."
if kubectl get service fastapi-service &> /dev/null; then
    echo -e "${GREEN}✓ Service 'fastapi-service' exists${NC}"
else
    echo -e "${RED}✗ Service 'fastapi-service' not found${NC}"
    echo "Please run: kubectl apply -f k8s/service-clusterip.yaml"
    exit 1
fi
echo ""

# Check service type wheater it's ClusterIP, NodePort or LoadBalancer
echo "2. Verifying service type is ClusterIP..."
SERVICE_TYPE=$(kubectl get service fastapi-service -o jsonpath='{.spec.type}')
if [ "$SERVICE_TYPE" == "ClusterIP" ]; then
    echo -e "${GREEN}✓ Service type is ClusterIP${NC}"
else
    echo -e "${YELLOW}⚠ Service type is $SERVICE_TYPE (expected ClusterIP)${NC}"
fi
echo ""

# Get service details
echo "3. Service Details: "
CLUSTER_IP=$(kubectl get service fastapi-service -o jsonpath='{.spec.clusterIP}')
PORT=$(kubectl get service fastapi-service -o jsonpath='{.spec.ports[0].port}')
TARGET_PORT=$(kubectl get service fastapi-service -o jsonpath='{.spec.ports[0].targetPort}')
SELECTOR=$(kubectl get service fastapi-service -o jsonpath='{.spec.selector}')

echo "   Cluster IP or Service IP: $CLUSTER_IP"
echo "   Service Port: $PORT"
echo "   Target Port: $TARGET_PORT"
echo "   Selector: $SELECTOR"
echo ""

# Check endpoints
echo "4. Checking endpoints (Pod IPs)..."
ENDPOINTS=$(kubectl get endpoints fastapi-service -o jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' '\n')
ENDPOINT_COUNT=$(echo "$ENDPOINTS" | wc -l | xargs)

if [ -n "$ENDPOINTS" ]; then
    echo -e "${GREEN}✓ Found $ENDPOINT_COUNT endpoint(s):${NC}"
    echo "$ENDPOINTS" | while read -r ip; do
        echo "   - $ip"
    done
else
    echo -e "${RED}✗ No endpoints found. Check if pods are running.${NC}"
    exit 1
fi
echo ""

# Check if pods are running
echo "5. Checking backend pods..."
POD_COUNT=$(kubectl get pods -l app=fastapi --field-selector=status.phase=Running --no-headers | wc -l | xargs)
echo -e "${GREEN}✓ Found $POD_COUNT running pod(s) with label app=fastapi${NC}"
kubectl get pods -l app=fastapi --no-headers
echo ""

# Test DNS resolution from within cluster
echo "6. Testing DNS resolution from within cluster..."
echo "   Creating temporary test pod..."

DNS_TEST=$(kubectl run test-dns-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "nslookup fastapi-service" 2>&1 || true)

if echo "$DNS_TEST" | grep -q "Name:.*fastapi-service"; then
    echo -e "${GREEN}✓ DNS resolution successful${NC}"
    echo "   Service DNS: fastapi-service.default.svc.cluster.local"
else
    echo -e "${YELLOW}⚠ DNS resolution test had issues (but service may still work)${NC}"
fi
echo ""

# Test HTTP connectivity from within cluster
echo "7. Testing HTTP connectivity from within cluster..."
echo "   Creating temporary test pod and making HTTP request..."

HTTP_TEST=$(kubectl run test-http-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://fastapi-service:8000/" 2>&1 | tail -1 || echo "failed")

if [ "$HTTP_TEST" == "200" ]; then
    echo -e "${GREEN}✓ HTTP request successful (Status: 200)${NC}"
else
    echo -e "${YELLOW}⚠ HTTP request status: $HTTP_TEST${NC}"
fi
echo ""

# Test access to /health endpoint
echo "8. Testing /health endpoint..."
HEALTH_TEST=$(kubectl run test-health-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s http://fastapi-service:8000/health" 2>&1 | tail -1 || true)

if echo "$HEALTH_TEST" | grep -q "status"; then
    echo -e "${GREEN}✓ Health endpoint accessible${NC}"
    echo "   Response: $HEALTH_TEST"
else
    echo -e "${YELLOW}⚠ Health endpoint response: $HEALTH_TEST${NC}"
fi
echo ""

# Port forwarding test
echo "9. Testing port-forward capability..."
echo "   Starting port-forward in background..."
kubectl port-forward service/fastapi-service 8888:8000 &> /dev/null &
PF_PID=$!
sleep 3

if curl -s http://localhost:8888 &> /dev/null; then
    echo -e "${GREEN}✓ Port-forward working${NC}"
    echo "   Access via: http://localhost:8888"
    
    # Test the API
    RESPONSE=$(curl -s http://localhost:8888/info | head -c 100)
    echo "   Sample response: ${RESPONSE}..."
else
    echo -e "${YELLOW}⚠ Port-forward not accessible${NC}"
fi

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true
echo ""

# Test load balancing
echo "10. Testing load balancing (multiple requests)..."
echo "    Making 10 requests to see if different pods respond..."
kubectl run test-lb-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -s http://fastapi-service:8000/info | grep -o '\"hostname\":\"[^\"]*\"'
done
" 2>&1 | grep hostname | sort | uniq -c

echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ ClusterIP Service Tests Complete${NC}"
echo ""
echo "Key Findings:"
echo "  - Service Type: ClusterIP"
echo "  - Cluster IP: $CLUSTER_IP"
echo "  - Endpoints: $ENDPOINT_COUNT pod(s)"
echo "  - Pod Count: $POD_COUNT"
echo ""
echo "Access Methods:"
echo "  - From within cluster: http://fastapi-service:8000"
echo "  - From your machine: kubectl port-forward service/fastapi-service 8000:8000"
echo ""
echo "Next Steps:"
echo "  - Try NodePort service: kubectl apply -f k8s/service-nodeport.yaml"
echo "  - Run NodePort tests: ./test/test-nodeport.sh"
echo ""
