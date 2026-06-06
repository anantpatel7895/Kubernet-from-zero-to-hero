#!/bin/bash

# Test NodePort Service
# This script tests the NodePort service which provides external access via node ports

set -e

echo "=========================================="
echo "Testing NodePort Service"
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
    echo "Please run: kubectl apply -f k8s/service-nodeport.yaml"
    exit 1
fi
echo ""

# Check service type
echo "2. Verifying service type is NodePort..."
SERVICE_TYPE=$(kubectl get service fastapi-service -o jsonpath='{.spec.type}')
if [ "$SERVICE_TYPE" == "NodePort" ]; then
    echo -e "${GREEN}✓ Service type is NodePort${NC}"
else
    echo -e "${RED}✗ Service type is $SERVICE_TYPE (expected NodePort)${NC}"
    echo "Please run: kubectl apply -f k8s/service-nodeport.yaml"
    exit 1
fi
echo ""

# Get service details
echo "3. Service Details:"
CLUSTER_IP=$(kubectl get service fastapi-service -o jsonpath='{.spec.clusterIP}')
PORT=$(kubectl get service fastapi-service -o jsonpath='{.spec.ports[0].port}')
TARGET_PORT=$(kubectl get service fastapi-service -o jsonpath='{.spec.ports[0].targetPort}')
NODE_PORT=$(kubectl get service fastapi-service -o jsonpath='{.spec.ports[0].nodePort}')

echo "   Cluster IP: $CLUSTER_IP"
echo "   Service Port: $PORT"
echo "   Target Port: $TARGET_PORT"
echo "   Node Port: $NODE_PORT"
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

# Detect Kubernetes environment
echo "5. Detecting Kubernetes environment..."
if kubectl config current-context | grep -q "docker-desktop"; then
    K8S_ENV="docker-desktop"
    NODE_IP="localhost"
    echo -e "${GREEN}✓ Detected: Docker Desktop${NC}"
elif kubectl config current-context | grep -q "minikube"; then
    K8S_ENV="minikube"
    NODE_IP=$(minikube ip 2>/dev/null || echo "")
    echo -e "${GREEN}✓ Detected: Minikube${NC}"
    echo "   Minikube IP: $NODE_IP"
elif kubectl config current-context | grep -q "kind"; then
    K8S_ENV="kind"
    NODE_IP="localhost"
    echo -e "${GREEN}✓ Detected: Kind${NC}"
    echo -e "${YELLOW}   Note: Kind requires port mapping configuration${NC}"
else
    K8S_ENV="unknown"
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo -e "${YELLOW}⚠ Unknown environment${NC}"
    echo "   Using first node IP: $NODE_IP"
fi
echo ""

# Test NodePort access
echo "6. Testing NodePort access..."

if [ "$K8S_ENV" == "docker-desktop" ]; then
    echo "   Testing http://localhost:$NODE_PORT"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$NODE_PORT | grep -q "200"; then
        echo -e "${GREEN}✓ NodePort accessible via localhost:$NODE_PORT${NC}"
        
        # Get sample response
        RESPONSE=$(curl -s http://localhost:$NODE_PORT/)
        echo "   Response: $RESPONSE"
    else
        echo -e "${RED}✗ Cannot access NodePort via localhost${NC}"
    fi

elif [ "$K8S_ENV" == "minikube" ]; then
    if [ -n "$NODE_IP" ]; then
        echo "   Testing http://$NODE_IP:$NODE_PORT"
        if curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:$NODE_PORT | grep -q "200"; then
            echo -e "${GREEN}✓ NodePort accessible via $NODE_IP:$NODE_PORT${NC}"
            
            # Get sample response
            RESPONSE=$(curl -s http://$NODE_IP:$NODE_PORT/)
            echo "   Response: $RESPONSE"
        else
            echo -e "${YELLOW}⚠ Cannot access NodePort directly${NC}"
            echo "   Try: minikube service fastapi-service --url"
        fi
    fi

elif [ "$K8S_ENV" == "kind" ]; then
    echo -e "${YELLOW}⚠ Kind requires extra port mapping configuration${NC}"
    echo "   For Kind, use port-forward instead:"
    echo "   kubectl port-forward service/fastapi-service 8000:8000"

else
    if [ -n "$NODE_IP" ]; then
        echo "   Testing http://$NODE_IP:$NODE_PORT"
        if curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:$NODE_PORT --max-time 5 | grep -q "200"; then
            echo -e "${GREEN}✓ NodePort accessible via $NODE_IP:$NODE_PORT${NC}"
        else
            echo -e "${YELLOW}⚠ Cannot access NodePort (may require firewall rules)${NC}"
        fi
    fi
fi
echo ""

# Test multiple endpoints
if [ "$K8S_ENV" == "docker-desktop" ]; then
    echo "7. Testing different API endpoints..."
    
    # Test root endpoint
    echo "   Testing / endpoint..."
    ROOT_RESPONSE=$(curl -s http://localhost:$NODE_PORT/)
    if [ -n "$ROOT_RESPONSE" ]; then
        echo -e "${GREEN}   ✓ Root endpoint: $ROOT_RESPONSE${NC}"
    fi
    
    # Test health endpoint
    echo "   Testing /health endpoint..."
    HEALTH_RESPONSE=$(curl -s http://localhost:$NODE_PORT/health)
    if echo "$HEALTH_RESPONSE" | grep -q "status"; then
        echo -e "${GREEN}   ✓ Health endpoint: $HEALTH_RESPONSE${NC}"
    fi
    
    # Test info endpoint
    echo "   Testing /info endpoint..."
    INFO_RESPONSE=$(curl -s http://localhost:$NODE_PORT/info | head -c 200)
    if [ -n "$INFO_RESPONSE" ]; then
        echo -e "${GREEN}   ✓ Info endpoint responding${NC}"
    fi
    echo ""
    
    # Test load balancing
    echo "8. Testing load balancing across pods..."
    echo "   Making 10 requests to see different pods..."
    
    for i in {1..10}; do
        curl -s http://localhost:$NODE_PORT/info | grep -o '"hostname":"[^"]*"' || true
    done | sort | uniq -c
    echo ""
fi

# Test internal cluster access (NodePort includes ClusterIP)
echo "9. Testing internal cluster access (ClusterIP functionality)..."
INTERNAL_TEST=$(kubectl run test-internal-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://fastapi-service:8000/" 2>&1 | tail -1)

if [ "$INTERNAL_TEST" == "200" ]; then
    echo -e "${GREEN}✓ Internal cluster access working (ClusterIP: $CLUSTER_IP)${NC}"
else
    echo -e "${YELLOW}⚠ Internal cluster access issue${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ NodePort Service Tests Complete${NC}"
echo ""
echo "Key Findings:"
echo "  - Service Type: NodePort"
echo "  - Node Port: $NODE_PORT"
echo "  - Cluster IP: $CLUSTER_IP (for internal access)"
echo "  - Endpoints: $ENDPOINT_COUNT pod(s)"
echo "  - Environment: $K8S_ENV"
echo ""

if [ "$K8S_ENV" == "docker-desktop" ]; then
    echo "Access Methods:"
    echo "  - External: http://localhost:$NODE_PORT"
    echo "  - Internal: http://fastapi-service:8000"
    echo "  - Docs: http://localhost:$NODE_PORT/docs"
elif [ "$K8S_ENV" == "minikube" ]; then
    echo "Access Methods:"
    echo "  - External: http://$NODE_IP:$NODE_PORT"
    echo "  - Or use: minikube service fastapi-service --url"
    echo "  - Internal: http://fastapi-service:8000"
elif [ "$K8S_ENV" == "kind" ]; then
    echo "Access Methods (Kind):"
    echo "  - Use port-forward: kubectl port-forward service/fastapi-service 8000:8000"
    echo "  - Internal: http://fastapi-service:8000"
else
    echo "Access Methods:"
    echo "  - External: http://$NODE_IP:$NODE_PORT (check firewall)"
    echo "  - Internal: http://fastapi-service:8000"
fi

echo ""
echo "Next Steps:"
echo "  - Try LoadBalancer service: kubectl apply -f k8s/service-loadbalancer.yaml"
echo "  - Test service discovery: ./test/test-service-discovery.sh"
echo ""
