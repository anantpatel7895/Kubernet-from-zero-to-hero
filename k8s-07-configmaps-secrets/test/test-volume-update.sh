#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets/test/test-volume-update.sh
# Test script to demonstrate auto-updating of volume-mounted ConfigMaps

set -e

echo "========================================="
echo "Volume-Mounted ConfigMap Auto-Update Test"
echo "========================================="
echo ""

SERVICE_URL="http://config-demo-service:8000"

echo "📸 Step 1: Capture CURRENT file contents from pod..."
echo "--- app.properties (first 5 lines) ---"
kubectl exec deployment/config-demo-app -- cat /etc/config/app.properties | head -5
echo ""
echo "--- features.json via API ---"
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq -r '.features_json' | jq '.features.new_ui'
echo ""

echo "⏳ Step 2: Applying UPDATED ConfigMap (file-based)..."
kubectl apply -f k8s/configmap-files-updated.yaml
echo ""

echo "⏰ Step 3: Waiting 10 seconds for Kubernetes to sync files to pods..."
echo "(Kubernetes syncs ConfigMap volumes every 60s by default, but often faster)"
for i in {10..1}; do
  echo -n "$i... "
  sleep 1
done
echo ""
echo ""

echo "🔍 Step 4: Check if files have been auto-updated (WITHOUT pod restart)..."
echo "--- app.properties (first 5 lines) ---"
kubectl exec deployment/config-demo-app -- cat /etc/config/app.properties | head -5
echo ""
echo "--- features.json via API ---"
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq -r '.features_json' | jq '.features.new_ui'
echo ""

echo "⏰ Step 5: If not updated yet, wait another 20 seconds..."
sleep 20
echo ""

echo "🔍 Step 6: Final check of file contents..."
echo "--- app.properties (first 5 lines) ---"
kubectl exec deployment/config-demo-app -- cat /etc/config/app.properties | head -5
echo ""
echo "--- Full API response ---"
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq '.'
echo ""

echo "========================================="
echo "✅ Volume-Mounted ConfigMap Update Test Complete!"
echo ""
echo "Key Takeaways:"
echo "1. ✅ Volume-mounted ConfigMaps ARE auto-updated"
echo "2. ⏱️  Sync happens every ~60s (kubelet sync period)"
echo "3. 🔄 No pod restart required for file-based config"
echo "4. 💡 Use volumes for dynamic config that changes often"
echo "5. 🔧 Use env vars for static config set at deployment time"
echo "========================================="
