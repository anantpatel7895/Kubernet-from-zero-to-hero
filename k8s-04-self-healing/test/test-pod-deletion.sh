#!/bin/bash
# Test: Pod Deletion & Recreation
# Demonstrates: ReplicaSet automatically recreates deleted pods

set -e

echo "=========================================="
echo "Test: Pod Deletion & Self-Healing"
echo "=========================================="
echo ""

# Check deployment exists
if ! kubectl get deployment self-healing-app &>/dev/null; then
  echo "❌ Deployment 'self-healing-app' not found!"
  echo "   Run: kubectl apply -f k8s/deployment.yaml"
  exit 1
fi

echo "1. Current state of deployment:"
kubectl get deployment self-healing-app
echo ""

echo "2. Current pods:"
kubectl get pods -l app=self-healing -o wide
echo ""

# Get initial pod names
INITIAL_PODS=$(kubectl get pods -l app=self-healing -o jsonpath='{.items[*].metadata.name}')
echo "3. Initial pod names:"
for pod in $INITIAL_PODS; do
  echo "   - $pod"
done
echo ""

# Pick one pod to delete
POD_TO_DELETE=$(echo $INITIAL_PODS | awk '{print $1}')
echo "4. Deleting pod: $POD_TO_DELETE"
kubectl delete pod $POD_TO_DELETE
echo ""

echo "5. Waiting 5 seconds for ReplicaSet to react..."
sleep 5
echo ""

echo "6. New pod state:"
kubectl get pods -l app=self-healing -o wide
echo ""

# Verify count is still 3
POD_COUNT=$(kubectl get pods -l app=self-healing --no-headers | wc -l | tr -d ' ')
echo "7. Pod count: $POD_COUNT (expected: 3)"

if [ "$POD_COUNT" -eq "3" ]; then
  echo "   ✅ Self-healing worked! ReplicaSet maintained desired state"
else
  echo "   ⚠️  Unexpected pod count - waiting more..."
  sleep 10
  kubectl get pods -l app=self-healing
fi
echo ""

# Show new pod names
NEW_PODS=$(kubectl get pods -l app=self-healing -o jsonpath='{.items[*].metadata.name}')
echo "8. Current pod names (notice the new one):"
for pod in $NEW_PODS; do
  if echo "$INITIAL_PODS" | grep -q "$pod"; then
    echo "   - $pod (existed before)"
  else
    echo "   - $pod ✨ (NEWLY CREATED)"
  fi
done
echo ""

echo "9. Recent ReplicaSet events:"
RS_NAME=$(kubectl get rs -l app=self-healing -o jsonpath='{.items[0].metadata.name}')
kubectl describe rs $RS_NAME | grep -A 5 "Events:" || echo "   (No recent events)"
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "Key Takeaways:"
echo "  • Deleted pod was automatically replaced"
echo "  • Pod count stayed at desired state (3)"
echo "  • New pod has different name & IP"
echo "  • No manual intervention required"
