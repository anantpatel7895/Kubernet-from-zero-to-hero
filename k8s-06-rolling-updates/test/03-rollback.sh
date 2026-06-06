#!/bin/bash
# Step 3: Rollback to previous version
set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Project 06 — Step 3: Rollback"
echo "=========================================="
echo ""

echo "1. Current state:"
kubectl get deployment rolling-app
echo ""
echo "   Current version response:"
kubectl exec client -- curl -s http://rolling-service:8000/version 2>/dev/null || echo "(client pod missing)"
echo ""
echo ""

echo "2. Rollout history:"
kubectl rollout history deployment/rolling-app
echo ""

echo "3. ⏪ Rolling back to PREVIOUS revision..."
kubectl rollout undo deployment/rolling-app
echo ""

echo "4. Waiting for rollback to complete..."
kubectl rollout status deployment/rolling-app --timeout=120s
echo ""

echo "5. After rollback:"
kubectl get pods -l app=rolling-app
echo ""
echo "   New version response:"
kubectl exec client -- curl -s http://rolling-service:8000/version 2>/dev/null || echo "(client pod missing)"
echo ""
echo ""

echo "6. Updated rollout history:"
kubectl rollout history deployment/rolling-app
echo ""

echo "💡 Notice: Revision numbers increment! Rolling back creates a NEW revision."
echo ""

echo "✅ Step 3 complete!"
echo ""
echo "Next: ./test/04-recreate-strategy.sh"
