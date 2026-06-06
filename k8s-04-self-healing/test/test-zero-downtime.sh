#!/bin/bash
# Test: Zero-Downtime During Pod Failures
# Demonstrates: Service load balances to healthy pods while others recover
#
# 🔍 IMPORTANT: This test runs requests from INSIDE the cluster using a
# client pod. We do NOT use `kubectl port-forward` because port-forward
# tunnels to ONE specific pod (no load balancing) and breaks when that
# pod dies. The REAL Service load balancing only happens when traffic
# goes through the Service from inside the cluster (or via NodePort/
# LoadBalancer/Ingress from outside).
# See: docs/why_port_forward_failed.md

set -e

echo "=========================================="
echo "Test: Zero-Downtime Resilience"
echo "=========================================="
echo ""

# Check deployment and service exist
if ! kubectl get deployment self-healing-app &>/dev/null; then
  echo "❌ Deployment not found! Run: kubectl apply -f k8s/deployment.yaml"
  exit 1
fi

if ! kubectl get service self-healing-service &>/dev/null; then
  echo "❌ Service not found! Run: kubectl apply -f k8s/service.yaml"
  exit 1
fi

echo "1. Setup: Ensuring 3 replicas are running..."
kubectl scale deployment self-healing-app --replicas=3 >/dev/null
kubectl rollout status deployment self-healing-app --timeout=60s
echo ""

echo "2. Creating in-cluster load-tester pod..."
kubectl delete pod load-tester --ignore-not-found=true --wait=true >/dev/null 2>&1
kubectl run load-tester \
  --image=curlimages/curl:latest \
  --restart=Never \
  --command -- sleep 3600 >/dev/null

# Wait for the load-tester pod to be ready
echo "   Waiting for load-tester pod to be ready..."
kubectl wait --for=condition=Ready pod/load-tester --timeout=60s >/dev/null
echo "   ✅ Load-tester pod ready"
echo ""

# Cleanup trap
cleanup() {
  kubectl delete pod load-tester --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "3. Baseline: Making 5 requests via Service to verify it works..."
SUCCESS=0
FAILED=0
for i in 1 2 3 4 5; do
  if kubectl exec load-tester -- curl -s --max-time 2 \
      http://self-healing-service:8000/info >/dev/null 2>&1; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done
echo "   Success: $SUCCESS/5, Failed: $FAILED/5"
echo ""

echo "4. Now starting load test (30 requests) WHILE deleting pods..."
echo "   📡 Traffic goes through Service (real load balancing!)"
echo ""

RESULTS_FILE=$(mktemp)

# Start making requests in background, from INSIDE the cluster
(
  TOTAL=0
  SUCCESS=0
  FAILED=0
  for i in $(seq 1 30); do
    TOTAL=$((TOTAL + 1))
    RESPONSE=$(kubectl exec load-tester -- curl -s --max-time 2 \
      http://self-healing-service:8000/info 2>/dev/null || echo "")
    if [ -n "$RESPONSE" ]; then
      # Extract hostname using sed (works in any shell, no python needed)
      HOSTNAME=$(echo "$RESPONSE" | sed -n 's/.*"hostname":"\([^"]*\)".*/\1/p')
      [ -z "$HOSTNAME" ] && HOSTNAME="(unknown)"
      SUCCESS=$((SUCCESS + 1))
      printf "   [%02d/30] ✅ Served by: %s\n" "$i" "$HOSTNAME"
    else
      FAILED=$((FAILED + 1))
      printf "   [%02d/30] ❌ Request failed\n" "$i"
    fi
    sleep 0.5
  done
  echo ""
  echo "   📊 Results: $SUCCESS/$TOTAL successful, $FAILED/$TOTAL failed"
  echo "$SUCCESS $FAILED $TOTAL" > "$RESULTS_FILE"
) &
LOAD_PID=$!

# Wait a bit, then delete a pod
sleep 5
POD1=$(kubectl get pods -l app=self-healing -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "   🗑️  DELETING POD: $POD1"
kubectl delete pod "$POD1" --wait=false >/dev/null 2>&1
echo ""

# Wait more, delete another
sleep 5
POD2=$(kubectl get pods -l app=self-healing \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "   🗑️  DELETING ANOTHER POD: $POD2"
kubectl delete pod "$POD2" --wait=false >/dev/null 2>&1
echo ""

# Wait for load test to complete
wait $LOAD_PID

# Read results
read -r SUCCESS FAILED TOTAL < "$RESULTS_FILE"
rm -f "$RESULTS_FILE"
UPTIME_PERCENT=$(awk "BEGIN { printf \"%.1f\", ($SUCCESS / $TOTAL) * 100 }")

echo ""
echo "5. Final state of pods (after self-healing):"
kubectl get pods -l app=self-healing
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "📊 Final Score:"
echo "   ✅ Successful: $SUCCESS / $TOTAL"
echo "   ❌ Failed:     $FAILED / $TOTAL"
echo "   📈 Uptime:     ${UPTIME_PERCENT}%"
echo ""
echo "Key Takeaways:"
echo "  • Service kept routing during pod deletions"
echo "  • Healthy pods absorbed the traffic"
echo "  • ReplicaSet recreated deleted pods automatically"
echo "  • Multiple replicas = high availability"
echo "  • Brief blips may occur (kube-proxy endpoint updates)"
echo ""
echo "💡 Why this works (and port-forward doesn't):"
echo "   port-forward          = tunnel to ONE pod (no load balancing)"
echo "   in-cluster via Service = REAL load balancing across all pods"
