#!/bin/bash
# Test 03: Watch HPA Status
# Shows the HPA in action - useful to run in a separate terminal
set -e

echo "=========================================="
echo "Test 03: Watch HPA Status"
echo "=========================================="
echo ""

# Check HPA exists
if ! kubectl get hpa scaling-app-hpa &>/dev/null; then
  echo "❌ HPA not found! Run: kubectl apply -f k8s/hpa.yaml"
  exit 1
fi

echo "Current HPA status:"
kubectl get hpa scaling-app-hpa
echo ""

echo "HPA details:"
kubectl describe hpa scaling-app-hpa | head -40
echo ""

echo "Current pods:"
kubectl get pods -l app=scaling-app
echo ""

echo "Current CPU usage:"
kubectl top pods -l app=scaling-app 2>/dev/null || echo "   (Metrics not available yet)"
echo ""

echo "=========================================="
echo "Now watching HPA in real-time (Ctrl+C to stop)..."
echo "=========================================="
echo ""
echo "TARGETS column shows: current_usage / target"
echo "REPLICAS column shows: current pod count"
echo ""

kubectl get hpa scaling-app-hpa -w
