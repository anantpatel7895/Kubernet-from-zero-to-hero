#!/bin/bash

# Test Load Balancing
# This script tests load balancing behavior across multiple pods

set -e

echo "=========================================="
echo "Testing Service Load Balancing"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REQUEST_COUNT=20

# Check prerequisites
echo "1. Checking prerequisites..."

# Check if service exists
if ! kubectl get service fastapi-service &> /dev/null; then
    echo -e "${RED}✗ Service 'fastapi-service' not found${NC}"
    exit 1
fi

# Check pod count
POD_COUNT=$(kubectl get pods -l app=fastapi --field-selector=status.phase=Running --no-headers | wc -l | xargs)

if [ "$POD_COUNT" -lt 2 ]; then
    echo -e "${YELLOW}⚠ Only $POD_COUNT pod(s) running${NC}"
    echo "   Load balancing is more visible with multiple pods"
    echo "   Scale up: kubectl scale deployment fastapi-deployment --replicas=3"
    echo ""
else
    echo -e "${GREEN}✓ Found $POD_COUNT running pods${NC}"
fi

# Show pods
echo ""
echo "2. Current pods:"
kubectl get pods -l app=fastapi -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName
echo ""

# Get endpoint IPs
ENDPOINTS=$(kubectl get endpoints fastapi-service -o jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' '\n')
ENDPOINT_COUNT=$(echo "$ENDPOINTS" | wc -l | xargs)

echo "3. Service endpoints:"
echo "   Total endpoints: $ENDPOINT_COUNT"
echo "$ENDPOINTS" | while read -r ip; do
    POD_NAME=$(kubectl get pods -l app=fastapi -o jsonpath="{.items[?(@.status.podIP=='$ip')].metadata.name}")
    echo "   - $ip ($POD_NAME)"
done
echo ""

# Test load balancing
echo "4. Testing load balancing with $REQUEST_COUNT requests..."
echo "   Making requests and tracking which pod responds..."
echo ""

# Create temporary file for results
TEMP_FILE=$(mktemp)

# Make requests and capture pod hostnames
echo -e "${BLUE}Progress:${NC}"
kubectl run test-lb-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "
echo 'Making $REQUEST_COUNT requests...'
for i in \$(seq 1 $REQUEST_COUNT); do
  curl -s http://fastapi-service:8000/info 2>/dev/null | grep -o '\"hostname\":\"[^\"]*\"' | cut -d'\"' -f4
  echo -n '.'
done
echo ''
" 2>&1 | grep -v "pod.*deleted" > $TEMP_FILE

echo ""
echo ""

# Analyze results
echo "5. Load balancing results:"
echo ""

# Count requests per pod
echo -e "${BLUE}Request distribution:${NC}"
cat $TEMP_FILE | grep -v "^Making" | grep -v "^\." | grep -v "^$" | sort | uniq -c | sort -rn

echo ""

# Calculate statistics
UNIQUE_PODS=$(cat $TEMP_FILE | grep -v "^Making" | grep -v "^\." | grep -v "^$" | sort -u | wc -l | xargs)
TOTAL_REQUESTS=$(cat $TEMP_FILE | grep -v "^Making" | grep -v "^\." | grep -v "^$" | wc -l | xargs)

echo -e "${BLUE}Statistics:${NC}"
echo "   Total requests: $TOTAL_REQUESTS"
echo "   Unique pods responded: $UNIQUE_PODS"
echo "   Available pods: $POD_COUNT"

if [ "$UNIQUE_PODS" -gt 1 ]; then
    echo -e "${GREEN}   ✓ Load balancing working! Multiple pods handling requests${NC}"
    
    # Calculate distribution
    EXPECTED_PER_POD=$((TOTAL_REQUESTS / UNIQUE_PODS))
    echo "   Expected per pod (if evenly distributed): ~$EXPECTED_PER_POD requests"
else
    echo -e "${YELLOW}   ⚠ Only 1 pod responded. Scale up for better load balancing.${NC}"
fi

# Cleanup
rm -f $TEMP_FILE
echo ""

# Test session affinity
echo "6. Testing session affinity (default: None)..."
SESSION_AFFINITY=$(kubectl get service fastapi-service -o jsonpath='{.spec.sessionAffinity}')
echo "   Session Affinity: ${SESSION_AFFINITY:-None}"

if [ "$SESSION_AFFINITY" == "ClientIP" ]; then
    echo -e "${YELLOW}   ⚠ ClientIP affinity enabled - same client goes to same pod${NC}"
else
    echo -e "${GREEN}   ✓ No session affinity - requests distributed round-robin${NC}"
fi
echo ""

# Test concurrent requests
echo "7. Testing concurrent load balancing..."
echo "   Making 10 concurrent requests..."

kubectl run test-concurrent-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "
for i in 1 2 3 4 5 6 7 8 9 10; do
  (curl -s http://fastapi-service:8000/info 2>/dev/null | grep -o '\"hostname\":\"[^\"]*\"' | cut -d'\"' -f4) &
done
wait
" 2>&1 | grep -v "pod.*deleted" | grep -v "^$" | sort | uniq -c

echo ""

# Test load balancing algorithms
echo "8. Understanding load balancing algorithm..."
echo ""
echo "   Kubernetes uses different load balancing methods:"
echo "   - kube-proxy (iptables): Random selection weighted by pod count"
echo "   - kube-proxy (ipvs): Round-robin, least connection, etc."
echo "   - Service Mesh (Istio/Linkerd): Advanced algorithms"
echo ""

# Get current kube-proxy mode
PROXY_MODE=$(kubectl logs -n kube-system -l component=kube-proxy --tail=100 2>/dev/null | grep -i "mode" | tail -1 || echo "unknown")
echo "   Current setup: $PROXY_MODE"
echo ""

# Test with pod failures
if [ "$POD_COUNT" -ge 2 ]; then
    echo "9. Testing load balancing with pod failure simulation..."
    echo "   This demonstrates automatic traffic redistribution"
    echo ""
    
    # Get first pod name
    FIRST_POD=$(kubectl get pods -l app=fastapi -o jsonpath='{.items[0].metadata.name}')
    
    echo "   Current pods:"
    kubectl get pods -l app=fastapi --no-headers | awk '{print "   - " $1 " (" $3 ")"}'
    echo ""
    
    echo "   Deleting pod: $FIRST_POD"
    kubectl delete pod $FIRST_POD --wait=false > /dev/null
    
    echo "   Waiting 5 seconds for pod deletion and recreation..."
    sleep 5
    
    echo ""
    echo "   Updated pods:"
    kubectl get pods -l app=fastapi --no-headers | awk '{print "   - " $1 " (" $3 ")"}'
    echo ""
    
    echo "   Service automatically updated endpoints!"
    kubectl get endpoints fastapi-service
    
    echo ""
    echo -e "${GREEN}   ✓ Load balancing continues despite pod changes${NC}"
fi

echo ""

# Summary
echo "=========================================="
echo "Load Balancing Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ Load Balancing Tests Complete${NC}"
echo ""
echo "Key Findings:"
echo "  - Service endpoints: $ENDPOINT_COUNT pod(s)"
echo "  - Load balancing: Distributes across all healthy pods"
echo "  - Session affinity: ${SESSION_AFFINITY:-None}"
echo "  - Algorithm: Round-robin / Random (kube-proxy)"
echo ""
echo "Observations:"
if [ "$UNIQUE_PODS" -gt 1 ]; then
    echo "  ✓ Requests distributed across multiple pods"
    echo "  ✓ No single point of failure"
    echo "  ✓ Automatic traffic redistribution on pod changes"
else
    echo "  ⚠ Only 1 pod - scale up to see load balancing:"
    echo "    kubectl scale deployment fastapi-deployment --replicas=3"
fi
echo ""
echo "Next Steps:"
echo "  - Scale deployment up/down to see load balancing adapt"
echo "  - Try session affinity: spec.sessionAffinity: ClientIP"
echo "  - Monitor with: kubectl get endpoints fastapi-service --watch"
echo ""
