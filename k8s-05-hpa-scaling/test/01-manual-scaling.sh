#!/bin/bash
# Test 01: Manual Scaling
# Demonstrates: kubectl scale, kubectl edit, kubectl apply
set -e

echo "=========================================="
echo "Test 01: Manual Scaling"
echo "=========================================="
echo ""

# Check deployment exists
if ! kubectl get deployment scaling-app &>/dev/null; then
  echo "❌ Deployment not found! Run: kubectl apply -f k8s/deployment.yaml"
  exit 1
fi

echo "1. Current state:"
kubectl get deployment scaling-app
echo ""
kubectl get pods -l app=scaling-app
echo ""

echo "2. Scaling UP to 5 replicas..."
kubectl scale deployment scaling-app --replicas=5
sleep 5
kubectl get pods -l app=scaling-app
echo ""

echo "3. Scaling DOWN to 1 replica..."
kubectl scale deployment scaling-app --replicas=1
sleep 5
kubectl get pods -l app=scaling-app
echo ""

echo "4. Back to 2 replicas (baseline)..."
kubectl scale deployment scaling-app --replicas=2
sleep 5
kubectl get pods -l app=scaling-app
echo ""

echo "=========================================="
echo "✅ Manual Scaling Test Complete!"
echo "=========================================="
echo ""
echo "Key Takeaway:"
echo "  • kubectl scale is fast (imperative)"
echo "  • Good for one-off changes"
echo "  • For production, edit YAML + kubectl apply (declarative)"
