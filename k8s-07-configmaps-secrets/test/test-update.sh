#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets/test/test-update.sh
# Test script to verify ConfigMap updates are reflected in pods

set -e

echo "========================================="
echo "ConfigMap Update Test"
echo "========================================="
echo ""

SERVICE_URL="http://config-demo-service:8000"

echo "📸 Capturing initial configuration..."
kubectl exec client -- curl -s $SERVICE_URL/config | jq '.'
echo ""

echo "⏳ Applying updated ConfigMap..."
kubectl apply -f k8s/configmap-env-updated.yaml
echo ""

echo "⏰ Waiting 5 seconds for Kubernetes to sync..."
sleep 5
echo ""

echo "🔄 Checking if configuration changed (without pod restart)..."
kubectl exec client -- curl -s $SERVICE_URL/config | jq '.'
echo ""

echo "ℹ️  NOTE: Environment variables from ConfigMaps are NOT automatically updated!"
echo "ℹ️  The old values are still showing because the pod hasn't restarted."
echo ""

echo "🔄 Restarting pods to pick up new configuration..."
kubectl rollout restart deployment config-demo-app
kubectl rollout status deployment config-demo-app
echo ""

echo "✅ Pods restarted. Checking new configuration..."
kubectl exec client -- curl -s $SERVICE_URL/config | jq '.'
echo ""

echo "========================================="
echo "Key Takeaways:"
echo "1. Environment variables are injected at pod startup"
echo "2. Updating ConfigMap doesn't update running pods"
echo "3. You must restart pods to pick up env var changes"
echo "4. Volume-mounted configs can be auto-updated (next test)"
echo "========================================="
