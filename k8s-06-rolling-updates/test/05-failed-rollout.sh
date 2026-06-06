#!/bin/bash
# Step 5: Simulate a FAILED rollout (broken image) and recover with rollback
set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Project 06 — Step 5: Failed Rollout + Recovery"
echo "=========================================="
echo "💥 We'll deploy a BROKEN version, watch it fail, then rollback"
echo ""

if ! kubectl get deployment rolling-app &>/dev/null; then
  echo "❌ rolling-app not found! Run ./test/01-initial-deploy.sh first"
  exit 1
fi

echo "1. Current healthy state:"
kubectl get deployment rolling-app
kubectl get pods -l app=rolling-app
echo ""

echo "2. 💥 Applying BROKEN deployment (image doesn't exist)..."
kubectl apply -f k8s/deployment-broken.yaml
echo ""

echo "3. Watching pods (you'll see ImagePullBackOff)..."
sleep 15
kubectl get pods -l app=rolling-app
echo ""

echo "4. Trying to wait for rollout (will timeout — that's OK!):"
kubectl rollout status deployment/rolling-app --timeout=30s || true
echo ""

echo "5. Diagnosis:"
echo "   New pods stuck:"
kubectl get pods -l app=rolling-app | grep -v Running || echo "   (none)"
echo ""

echo "   But our OLD pods are still serving traffic! ✅"
kubectl exec client -- curl -s http://rolling-service:8000/version 2>/dev/null || echo "   (client pod missing)"
echo ""
echo ""

echo "6. 🚨 SAVE THE DAY — Rollback to previous version!"
kubectl rollout undo deployment/rolling-app
echo ""

echo "7. Waiting for rollback..."
kubectl rollout status deployment/rolling-app --timeout=120s
echo ""

echo "8. After rollback:"
kubectl get pods -l app=rolling-app
echo ""
echo "   Version check:"
kubectl exec client -- curl -s http://rolling-service:8000/version 2>/dev/null
echo ""
echo ""

echo "9. Full rollout history:"
kubectl rollout history deployment/rolling-app
echo ""

echo "💡 Key insight: maxUnavailable=0 SAVED YOU."
echo "   Because we required ALL pods to stay available,"
echo "   the broken pods couldn't replace the working ones."
echo "   Your users never saw the bug. 🎉"
echo ""

echo "✅ Step 5 complete! All scenarios tested."
