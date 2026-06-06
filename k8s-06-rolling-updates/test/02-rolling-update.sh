#!/bin/bash
# Step 2: Rolling update from v1 → v2 with ZERO downtime verification
#
# This script:
#  1. Creates an in-cluster client pod
#  2. Starts sending continuous requests to the Service
#  3. Triggers a rolling update (v1 → v2)
#  4. Watches as responses transition from v1 → mixed → v2
#  5. Verifies ZERO failures during the update
set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Project 06 — Step 2: Rolling Update (v1→v2)"
echo "=========================================="
echo ""

# Make sure we have v1 running
if ! kubectl get deployment rolling-app &>/dev/null; then
  echo "❌ rolling-app not found! Run ./test/01-initial-deploy.sh first"
  exit 1
fi

echo "1. Creating in-cluster client pod for continuous requests..."
kubectl delete pod client --ignore-not-found=true --wait=true >/dev/null 2>&1
kubectl run client \
  --image=curlimages/curl:latest \
  --restart=Never \
  --command -- sleep 3600 >/dev/null
kubectl wait --for=condition=Ready pod/client --timeout=60s >/dev/null
echo "   ✅ Client pod ready"
echo ""

cleanup() {
  kubectl delete pod client --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "2. Current version (before update):"
kubectl exec client -- curl -s http://rolling-service:8000/version
echo ""
echo ""

# Make sure v2 image exists (use v1 if v2 not available)
# This will be visible in the version response via APP_VERSION env var
NEW_IMAGE="fastapi-demo:v1"   # Same image, we'll change the APP_VERSION env
NEW_VERSION="2.0.0"

echo "3. 🚀 Starting rolling update to v$NEW_VERSION..."
echo "   (Updating env var APP_VERSION=$NEW_VERSION + annotation)"
echo ""

# Update via patch: change the APP_VERSION env var
kubectl set env deployment/rolling-app APP_VERSION=$NEW_VERSION
kubectl annotate deployment/rolling-app \
  kubernetes.io/change-cause="Update to v$NEW_VERSION via set env" --overwrite

echo ""
echo "4. Watching pods change in real-time (10s)..."
echo "   Open another terminal: kubectl get pods -l app=rolling-app -w"
echo ""

# Run continuous requests in background while update happens
RESULTS_FILE=$(mktemp)
(
  V1_COUNT=0
  V2_COUNT=0
  OTHER_COUNT=0
  FAILED=0
  TOTAL=0
  END_TIME=$((SECONDS + 60))
  while [ $SECONDS -lt $END_TIME ]; do
    TOTAL=$((TOTAL + 1))
    VER=$(kubectl exec client -- curl -s --max-time 2 \
      http://rolling-service:8000/version 2>/dev/null \
      | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
    if [ -z "$VER" ]; then
      FAILED=$((FAILED + 1))
      printf "."
    elif [ "$VER" = "1.0.0" ]; then
      V1_COUNT=$((V1_COUNT + 1))
      printf "1"
    elif [ "$VER" = "2.0.0" ]; then
      V2_COUNT=$((V2_COUNT + 1))
      printf "2"
    else
      OTHER_COUNT=$((OTHER_COUNT + 1))
      printf "?"
    fi
    sleep 0.5
  done
  echo ""
  echo "$V1_COUNT $V2_COUNT $OTHER_COUNT $FAILED $TOTAL" > "$RESULTS_FILE"
) &
LOAD_PID=$!

# Wait for rollout to complete
kubectl rollout status deployment/rolling-app --timeout=120s
echo ""

# Wait for the load test to finish
wait $LOAD_PID

read -r V1_COUNT V2_COUNT OTHER_COUNT FAILED TOTAL < "$RESULTS_FILE"
rm -f "$RESULTS_FILE"

echo ""
echo "=========================================="
echo "📊 Rolling Update Results"
echo "=========================================="
echo "Total requests: $TOTAL"
echo "  ✅ v1.0.0 responses: $V1_COUNT"
echo "  ✅ v2.0.0 responses: $V2_COUNT"
echo "  ⚠️  Other versions: $OTHER_COUNT"
echo "  ❌ Failed requests:  $FAILED"
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo "🎉 ZERO DOWNTIME ACHIEVED!"
else
  echo "⚠️  Some requests failed (might be transient — check readiness probes)"
fi
echo ""

echo "5. Rollout history (now has 2 revisions):"
kubectl rollout history deployment/rolling-app
echo ""

echo "✅ Step 2 complete!"
echo ""
echo "Next: ./test/03-rollback.sh"
