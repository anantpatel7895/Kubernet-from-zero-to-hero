#!/bin/bash

# Run All Service Tests
# This script runs all service tests in sequence

set -e

echo "=========================================="
echo "Kubernetes Service Testing Suite"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if service exists
if ! kubectl get service fastapi-service &> /dev/null; then
    echo -e "${RED}✗ Service 'fastapi-service' not found${NC}"
    echo ""
    echo "Please create a service first:"
    echo "  kubectl apply -f k8s/service-clusterip.yaml"
    echo "  OR"
    echo "  kubectl apply -f k8s/service-nodeport.yaml"
    exit 1
fi

# Get service type
SERVICE_TYPE=$(kubectl get service fastapi-service -o jsonpath='{.spec.type}')
echo -e "${BLUE}Service Type: $SERVICE_TYPE${NC}"
echo ""

# Make scripts executable
chmod +x test/*.sh 2>/dev/null || true

# Array to track test results
declare -a RESULTS

# Function to run test and track result
run_test() {
    local test_name=$1
    local test_script=$2
    
    echo ""
    echo "=========================================="
    echo "Running: $test_name"
    echo "=========================================="
    echo ""
    
    if [ -f "$test_script" ]; then
        if bash "$test_script"; then
            RESULTS+=("✓ $test_name")
            return 0
        else
            RESULTS+=("✗ $test_name")
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Test script not found: $test_script${NC}"
        RESULTS+=("⚠ $test_name (not found)")
        return 1
    fi
}

# Run tests based on service type
if [ "$SERVICE_TYPE" == "ClusterIP" ]; then
    run_test "ClusterIP Service Test" "test/test-clusterip.sh"
elif [ "$SERVICE_TYPE" == "NodePort" ]; then
    run_test "NodePort Service Test" "test/test-nodeport.sh"
elif [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
    echo -e "${YELLOW}LoadBalancer detected. Running NodePort tests (LoadBalancer includes NodePort)${NC}"
    run_test "NodePort Service Test" "test/test-nodeport.sh"
fi

# Run common tests (work with all service types)
run_test "Service Discovery Test" "test/test-service-discovery.sh"
run_test "Load Balancing Test" "test/test-load-balancing.sh"

# Summary
echo ""
echo ""
echo "=========================================="
echo "Test Suite Summary"
echo "=========================================="
echo ""

for result in "${RESULTS[@]}"; do
    if [[ $result == ✓* ]]; then
        echo -e "${GREEN}$result${NC}"
    elif [[ $result == ✗* ]]; then
        echo -e "${RED}$result${NC}"
    else
        echo -e "${YELLOW}$result${NC}"
    fi
done

echo ""

# Count results
TOTAL=${#RESULTS[@]}
PASSED=$(printf '%s\n' "${RESULTS[@]}" | grep -c "✓" || true)
FAILED=$(printf '%s\n' "${RESULTS[@]}" | grep -c "✗" || true)

echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi

echo ""
echo "=========================================="
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Review output above.${NC}"
    exit 1
fi
