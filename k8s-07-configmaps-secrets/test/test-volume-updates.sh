#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets/test/test-volume-updates.sh
# Test to show that volume-mounted ConfigMaps CAN be auto-updated

set -e

echo "========================================="
echo "Volume Mount Auto-Update Test"
echo "========================================="
echo ""

SERVICE_URL="http://config-demo-service:8000"

echo "📸 Reading initial config files..."
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq -r '.app_properties'
echo ""

echo "📝 Creating updated ConfigMap with new file content..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-files
  namespace: default
  labels:
    app: config-demo
data:
  app.properties: |
    # Application Properties - UPDATED VERSION
    app.name=ConfigMap Demo - UPDATED!
    app.version=2.0.0
    app.description=This config was updated without pod restart!
    
    # Database Configuration
    db.host=postgres-service-new
    db.port=5432
    db.name=myapp_v2
    db.pool.min=10
    db.pool.max=50
    
    # Cache Configuration
    cache.enabled=true
    cache.ttl=7200
    cache.provider=redis-cluster
    
    updated_at=$(date)
  
  features.json: |
    {
      "features": {
        "new_ui": {
          "enabled": true,
          "rollout_percentage": 100
        },
        "beta_api": {
          "enabled": true,
          "rollout_percentage": 25
        },
        "advanced_analytics": {
          "enabled": true,
          "rollout_percentage": 100
        }
      },
      "limits": {
        "max_requests_per_minute": 2000,
        "max_concurrent_connections": 1000
      }
    }
EOF
echo ""

echo "⏰ Waiting for Kubernetes to sync the update to pods..."
echo "ℹ️  This can take up to 60 seconds (default sync period)..."
for i in {1..12}; do
    echo -n "."
    sleep 5
done
echo ""
echo ""

echo "📖 Reading updated config files (without pod restart)..."
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq -r '.app_properties'
echo ""

echo "========================================="
echo "Key Takeaways:"
echo "========================================="
echo "1. ✅ Volume-mounted ConfigMaps ARE auto-updated"
echo "2. ⏱️  Updates can take up to 60 seconds to sync"
echo "3. 🔄 Application must reload files to see changes"
echo "4. ❌ Environment variables are NOT auto-updated"
echo ""
echo "Best Practice:"
echo "- Use volume mounts for frequently changing config"
echo "- Use env vars for static configuration"
echo "- Implement config reload in your app (SIGHUP, watch files, etc.)"
echo "========================================="
