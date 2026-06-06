#!/bin/bash
# Step 4: Demonstrate the Recreate strategy — causes DOWNTIME
set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Project 06 — Step 4: Recreate Strategy"
echo "=========================================="
echo "🚨 This will demonstrate DOWNTIME during updates"
echo ""

echo "1. Deploying app with Recreate strategy..."
kubectl apply -f k8s/deployment-recreate.yaml
kubectl rollout status deployment/recreate-app --timeout=120s
echo ""

echo "2. Pods running:"
kubectl get pods -l app=recreate-app
echo ""

# Create a service for the recreate-app
kubectl get service recreate-service &>/dev/null || \
  kubectl expose deployment recreate-app \
    --name=recreate-service --port=8000 --target-port=8000 >/dev/null

# Make sure client pod exists
if ! kubectl get pod client &>/dev/null; then
  kubectl run client --image=curlimages/curl:latest --restart=Never --command -- sleep 3600 >/dev/null
  kubectl wait --for=condition=Ready pod/client --timeout=60s >/dev/null
fi

echo "3. Current version (before update):"
kubectl exec client -- curl -s http://recreate-service:8000/version 2>/dev/null
echo ""
echo ""

echo "4. 🚨 Triggering update — watch for downtime!"
echo "   Updating APP_VERSION env var (forces a pod restart)..."
kubectl set env deployment/recreate-app APP_VERSION=2.0.0-recreate

RESULTS_FILE=$(mktemp)
(
  SUCCESS=0
  FAILED=0
  TOTAL=0
  END_TIME=$((SECONDS + 30))
  echo ""
  echo "   Request stream (✅=success, ❌=failed):"
  printf "   "
  while [ $SECONDS -lt $END_TIME ]; do
    TOTAL=$((TOTAL + 1))
    if kubectl exec client -- curl -s --max-time 1 \
        http://recreate-service:8000/version >/dev/null 2>&1; then
      SUCCESS=$((SUCCESS + 1))
      printf "✅"
    else
      FAILED=$((FAILED + 1))
      printf "❌"
    fi
    sleep 0.5
  done
  echo ""
  echo "$SUCCESS $FAILED $TOTAL" > "$RESULTS_FILE"
) &
LOAD_PID=$!

kubectl rollout status deployment/recreate-app --timeout=120s
wait $LOAD_PID

read -r SUCCESS FAILED TOTAL < "$RESULTS_FILE"
rm -f "$RESULTS_FILE"

echo ""
echo "=========================================="
echo "📊 Recreate Strategy Results"
echo "=========================================="
echo "Total requests: $TOTAL"
echo "  ✅ Successful:  $SUCCESS"
echo "  ❌ Failed:      $FAILED"
DOWNTIME=$(awk "BEGIN { printf \"%.1f\", ($FAILED / $TOTAL) * 100 }")
echo "  📉 Downtime:    ${DOWNTIME}%"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo "🚨 DOWNTIME CONFIRMED!"
  echo "   This is why Recreate strategy is BAD for most apps."
  echo "   Use RollingUpdate for zero downtime."
else
  echo "⚠️  No failures detected (maybe restart was very fast)"
fi
echo ""

echo "💡 Cleanup recreate-app:"
echo "   kubectl delete deployment/recreate-app service/recreate-service"
echo ""

echo "✅ Step 4 complete!"
echo ""
echo "Next: ./test/05-failed-rollout.sh"
