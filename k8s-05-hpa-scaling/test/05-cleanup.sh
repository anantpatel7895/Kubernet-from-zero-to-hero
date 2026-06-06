#!/bin/bash
# Test 05: Cleanup
# Removes all resources created by this project
set -e

echo "=========================================="
echo "Test 05: Cleanup"
echo "=========================================="
echo ""

echo "1. Removing load generator (if running)..."
kubectl delete pod load-generator --ignore-not-found=true --wait=false
echo ""

echo "2. Removing HPA..."
kubectl delete -f k8s/hpa.yaml --ignore-not-found=true
echo ""

echo "3. Removing service..."
kubectl delete -f k8s/service.yaml --ignore-not-found=true
echo ""

echo "4. Removing deployment..."
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
echo ""

echo "5. Verifying cleanup..."
kubectl get all -l project=k8s-05
echo ""

echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "Note: Metrics Server is NOT removed (other projects may use it)"
echo "To remove it manually:"
echo "  kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
