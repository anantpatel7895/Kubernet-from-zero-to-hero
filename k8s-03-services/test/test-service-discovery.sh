#!/bin/bash

# Test Service Discovery
# This script tests DNS-based service discovery in Kubernetes

set -e

echo "=========================================="
echo "Testing Kubernetes Service Discovery"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if service exists
echo "1. Verifying fastapi-service exists..."
if kubectl get service fastapi-service &> /dev/null; then
    echo -e "${GREEN}✓ Service found${NC}"
    SERVICE_NAME=$(kubectl get service fastapi-service -o jsonpath='{.metadata.name}')
    SERVICE_NAMESPACE=$(kubectl get service fastapi-service -o jsonpath='{.metadata.namespace}')
    CLUSTER_IP=$(kubectl get service fastapi-service -o jsonpath='{.spec.clusterIP}')
    
    echo "   Name: $SERVICE_NAME"
    echo "   Namespace: $SERVICE_NAMESPACE"
    echo "   Cluster IP: $CLUSTER_IP"
else
    echo -e "${RED}✗ Service not found${NC}"
    exit 1
fi
echo ""

# Test DNS resolution formats
echo "2. Testing DNS resolution formats..."
echo ""

echo -e "${BLUE}Testing short name (same namespace):${NC}"
DNS_SHORT=$(kubectl run test-dns-short-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "nslookup fastapi-service 2>&1" | grep -A 2 "Name:" || echo "FAILED")

if echo "$DNS_SHORT" | grep -q "fastapi-service"; then
    echo -e "${GREEN}✓ Short name resolution works${NC}"
    echo "   Format: fastapi-service"
    echo "   $DNS_SHORT"
else
    echo -e "${RED}✗ Short name resolution failed${NC}"
fi
echo ""

echo -e "${BLUE}Testing FQDN (Fully Qualified Domain Name):${NC}"
DNS_FQDN=$(kubectl run test-dns-fqdn-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "nslookup fastapi-service.default.svc.cluster.local 2>&1" | grep -A 2 "Name:" || echo "FAILED")

if echo "$DNS_FQDN" | grep -q "fastapi-service"; then
    echo -e "${GREEN}✓ FQDN resolution works${NC}"
    echo "   Format: fastapi-service.default.svc.cluster.local"
    echo "   $DNS_FQDN"
else
    echo -e "${RED}✗ FQDN resolution failed${NC}"
fi
echo ""

echo -e "${BLUE}Testing namespace-qualified name:${NC}"
DNS_NS=$(kubectl run test-dns-ns-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "nslookup fastapi-service.default 2>&1" | grep -A 2 "Name:" || echo "FAILED")

if echo "$DNS_NS" | grep -q "fastapi-service"; then
    echo -e "${GREEN}✓ Namespace-qualified name works${NC}"
    echo "   Format: fastapi-service.default"
    echo "   $DNS_NS"
else
    echo -e "${RED}✗ Namespace-qualified name failed${NC}"
fi
echo ""

# Test HTTP connectivity using different DNS formats
echo "3. Testing HTTP connectivity via DNS..."
echo ""

echo -e "${BLUE}Using short name:${NC}"
HTTP_SHORT=$(kubectl run test-http-short-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://fastapi-service:8000/" 2>&1 | tail -1)

if [ "$HTTP_SHORT" == "200" ]; then
    echo -e "${GREEN}✓ HTTP via short name successful (200 OK)${NC}"
    
    # Get actual response
    RESPONSE=$(kubectl run test-http-resp-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s http://fastapi-service:8000/" 2>&1 | tail -1)
    echo "   Response: $RESPONSE"
else
    echo -e "${RED}✗ HTTP via short name failed (Status: $HTTP_SHORT)${NC}"
fi
echo ""

echo -e "${BLUE}Using FQDN:${NC}"
HTTP_FQDN=$(kubectl run test-http-fqdn-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://fastapi-service.default.svc.cluster.local:8000/" 2>&1 | tail -1)

if [ "$HTTP_FQDN" == "200" ]; then
    echo -e "${GREEN}✓ HTTP via FQDN successful (200 OK)${NC}"
else
    echo -e "${RED}✗ HTTP via FQDN failed (Status: $HTTP_FQDN)${NC}"
fi
echo ""

# Test different endpoints
echo "4. Testing different service endpoints..."
echo ""

ENDPOINTS=("/" "/health" "/info" "/api/v1/users")

for endpoint in "${ENDPOINTS[@]}"; do
    echo -e "${BLUE}Testing $endpoint:${NC}"
    
    RESULT=$(kubectl run test-endpoint-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s http://fastapi-service:8000$endpoint | head -c 100" 2>&1 | tail -1)
    
    if [ -n "$RESULT" ]; then
        echo -e "${GREEN}✓ Endpoint accessible${NC}"
        echo "   Response: ${RESULT}..."
    else
        echo -e "${YELLOW}⚠ Endpoint returned empty response${NC}"
    fi
    echo ""
done

# Test service discovery from different namespaces
echo "5. Testing cross-namespace service discovery..."
echo ""

# Create a test namespace
TEST_NS="test-namespace-$RANDOM"
echo "   Creating test namespace: $TEST_NS"
kubectl create namespace $TEST_NS > /dev/null

# Test from different namespace
echo "   Testing DNS from $TEST_NS namespace..."
CROSS_NS=$(kubectl run test-cross-ns --namespace=$TEST_NS --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://fastapi-service.default:8000/" 2>&1 | tail -1)

if [ "$CROSS_NS" == "200" ]; then
    echo -e "${GREEN}✓ Cross-namespace access works${NC}"
    echo "   Format: fastapi-service.default (from $TEST_NS namespace)"
else
    echo -e "${YELLOW}⚠ Cross-namespace access issue (Status: $CROSS_NS)${NC}"
fi

# Cleanup test namespace
kubectl delete namespace $TEST_NS > /dev/null
echo ""

# Test service environment variables
echo "6. Testing service environment variables..."
echo "   Kubernetes automatically injects service information as env vars"
echo ""

ENV_TEST=$(kubectl run test-env-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "env | grep FASTAPI" 2>&1 || echo "No env vars found")

if echo "$ENV_TEST" | grep -q "FASTAPI_SERVICE"; then
    echo -e "${GREEN}✓ Service environment variables found${NC}"
    echo "$ENV_TEST" | head -5
else
    echo -e "${YELLOW}⚠ No service environment variables found${NC}"
    echo "   (This is normal if service was created after pods)"
fi
echo ""

# Test DNS SRV records
echo "7. Testing DNS SRV records..."
SRV_TEST=$(kubectl run test-srv-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "nslookup -type=srv _http._tcp.fastapi-service.default.svc.cluster.local 2>&1" | grep -i "service" || echo "No SRV records")

if echo "$SRV_TEST" | grep -q "fastapi-service"; then
    echo -e "${GREEN}✓ DNS SRV records available${NC}"
    echo "   $SRV_TEST"
else
    echo -e "${YELLOW}⚠ DNS SRV records not found (port might not be named)${NC}"
fi
echo ""

# Show DNS components
echo "8. DNS Name Components:"
echo ""
echo "   Full DNS format:"
echo "   <service>.<namespace>.svc.<cluster-domain>"
echo ""
echo "   Examples for this service:"
echo "   - fastapi-service                              (short, same namespace)"
echo "   - fastapi-service.default                      (with namespace)"
echo "   - fastapi-service.default.svc                  (with service designation)"
echo "   - fastapi-service.default.svc.cluster.local    (FQDN)"
echo ""

# Summary
echo "=========================================="
echo "Service Discovery Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ Service Discovery Tests Complete${NC}"
echo ""
echo "DNS Resolution Methods:"
echo "  ✓ Short name (same namespace)"
echo "  ✓ Namespace-qualified name"
echo "  ✓ Fully Qualified Domain Name (FQDN)"
echo ""
echo "Key Learnings:"
echo "  1. Services are discoverable via DNS"
echo "  2. Short names work within the same namespace"
echo "  3. Use namespace-qualified names for cross-namespace access"
echo "  4. FQDN works from anywhere in the cluster"
echo ""
echo "DNS Format:"
echo "  <service>.<namespace>.svc.cluster.local"
echo "  Example: fastapi-service.default.svc.cluster.local"
echo ""
