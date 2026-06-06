#!/bin/bash
# Step 1: Deploy initial v1 of the rolling-app
set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Project 06 — Step 1: Initial Deploy (v1)"
echo "=========================================="
echo ""

echo "1. Applying deployment v1..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
echo ""

echo "2. Waiting for rollout to complete..."
kubectl rollout status deployment/rolling-app --timeout=120s
echo ""

echo "3. Verifying pods and service..."
kubectl get deployment rolling-app
echo ""
kubectl get pods -l app=rolling-app
echo ""

echo "4. Initial revision history:"
kubectl rollout history deployment/rolling-app
echo ""

echo "✅ v1 deployed successfully!"
echo ""
echo "Next: ./test/02-rolling-update.sh"
