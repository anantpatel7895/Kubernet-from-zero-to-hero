#!/bin/bash
# Test: Container Crash Recovery
# Demonstrates: Kubelet restarts crashed containers (CrashLoopBackOff)

set -e

echo "=========================================="
echo "Test: Container Crash Recovery"
echo "=========================================="
echo ""

# Clean up any existing crashing pod
echo "1. Cleaning up any existing crashing-pod..."
kubectl delete pod crashing-pod --ignore-not-found=true --wait=true
echo ""

echo "2. Deploying intentionally crashing pod..."
kubectl apply -f k8s/crashing-pod.yaml
echo ""

echo "3. Waiting for pod to start..."
sleep 5

echo "4. Initial pod state:"
kubectl get pod crashing-pod
echo ""

echo "5. Watching pod restart over 60 seconds..."
echo "   (The container exits after 10 seconds, K8s restarts it)"
echo ""

for i in 1 2 3 4 5 6; do
  sleep 10
  RESTARTS=$(kubectl get pod crashing-pod -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
  STATUS=$(kubectl get pod crashing-pod -o jsonpath='{.status.containerStatuses[0].state}' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys())[0])" 2>/dev/null || echo "unknown")
  PHASE=$(kubectl get pod crashing-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  echo "   [${i}0s] Phase: $PHASE | State: $STATUS | Restarts: $RESTARTS"
done
echo ""

echo "6. Final pod state:"
kubectl get pod crashing-pod
echo ""

echo "7. Pod details (notice restart count):"
kubectl describe pod crashing-pod | grep -E "(State|Reason|Restart Count|Last State|Exit Code)" | head -20
echo ""

echo "8. Logs from current container:"
kubectl logs crashing-pod 2>/dev/null | tail -5 || echo "   (Logs not available yet)"
echo ""

echo "9. Logs from previous (crashed) container:"
kubectl logs crashing-pod --previous 2>/dev/null | tail -5 || echo "   (No previous logs)"
echo ""

echo "10. Recent events for this pod:"
kubectl get events --field-selector involvedObject.name=crashing-pod --sort-by='.lastTimestamp' | tail -10
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "Key Takeaways:"
echo "  • Container exits → Kubelet restarts it (SAME pod)"
echo "  • Restart count increases with each crash"
echo "  • Backoff time grows: 10s, 20s, 40s, 80s..."
echo "  • Status becomes CrashLoopBackOff (>5 crashes)"
echo "  • Pod is NOT recreated, only the container restarts"
echo ""
echo "Cleanup:"
echo "  kubectl delete pod crashing-pod"
