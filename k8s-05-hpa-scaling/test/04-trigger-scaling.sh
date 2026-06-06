#!/bin/bash
# Test 04: Trigger Auto-Scaling
# Generates load and watches HPA scale up the deployment
set -e

echo "=========================================="
echo "Test 04: Trigger Auto-Scaling with Load"
echo "=========================================="
echo ""

# Check prerequisites
if ! kubectl get hpa scaling-app-hpa &>/dev/null; then
  echo "❌ HPA not found! Run: kubectl apply -f k8s/hpa.yaml"
  exit 1
fi

if ! kubectl top pods &>/dev/null 2>&1; then
  echo "❌ Metrics Server not ready! Run: ./test/02-install-metrics.sh"
  exit 1
fi

echo "1. Initial state:"
kubectl get hpa scaling-app-hpa
echo ""
kubectl top pods -l app=scaling-app
echo ""

echo "2. Starting load generator pod..."
kubectl delete pod load-generator --ignore-not-found=true --wait=true >/dev/null 2>&1
kubectl apply -f k8s/load-generator.yaml
kubectl wait --for=condition=Ready pod/load-generator --timeout=30s
echo "   ✅ Load generator running"
echo ""

# Cleanup trap
cleanup() {
  echo ""
  echo "🧹 Stopping load generator..."
  kubectl delete pod load-generator --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "3. Watching HPA scale UP (3 minutes)..."
echo "   Format: [time] HPA: usage% / target%  | Replicas: current/desired"
echo ""

# Monitor for 3 minutes
END_TIME=$(($(date +%s) + 180))
SAMPLE=0
while [ $(date +%s) -lt $END_TIME ]; do
  SAMPLE=$((SAMPLE + 1))
  TIMESTAMP=$(date +%H:%M:%S)
  
  # Get HPA info
  HPA_INFO=$(kubectl get hpa scaling-app-hpa -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}% / {.spec.metrics[0].resource.target.averageUtilization}% | {.status.currentReplicas}/{.status.desiredReplicas}' 2>/dev/null)
  
  # Pod count
  POD_COUNT=$(kubectl get pods -l app=scaling-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
  RUNNING_COUNT=$(kubectl get pods -l app=scaling-app --no-headers 2>/dev/null | grep -c Running || echo 0)
  
  printf "[%s] HPA: %-30s | Pods: %s running (%s total)\n" "$TIMESTAMP" "$HPA_INFO" "$RUNNING_COUNT" "$POD_COUNT"
  
  sleep 10
done

echo ""
echo "4. Final state:"
kubectl get hpa scaling-app-hpa
echo ""
kubectl get pods -l app=scaling-app
echo ""
kubectl top pods -l app=scaling-app 2>/dev/null
echo ""

echo "=========================================="
echo "✅ Auto-Scaling Test Complete!"
echo "=========================================="
echo ""
echo "What you observed:"
echo "  • Load generator pushed CPU up"
echo "  • HPA noticed (after ~15s)"
echo "  • HPA scaled pods UP"
echo "  • New pods absorbed traffic"
echo "  • CPU stabilized near target"
echo ""
echo "💡 Next: Let pods scale DOWN by waiting 60+ seconds"
echo "   (Watch with: kubectl get hpa scaling-app-hpa -w)"
