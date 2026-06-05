#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets/test/test-config.sh
# Test script to verify ConfigMaps and Secrets are properly mounted

set -e

echo "========================================="
echo "ConfigMaps & Secrets Test Suite"
echo "========================================="
echo ""

# Get service URL
SERVICE_URL="http://config-demo-service:8000"

echo "🔍 Testing configuration endpoints..."
echo ""

# Test 1: Basic endpoint
echo "1️⃣ Testing basic endpoint..."
kubectl exec client -- curl -s $SERVICE_URL/ | jq '.'
echo ""

# Test 2: ConfigMap environment variables
echo "2️⃣ Testing ConfigMap environment variables..."
kubectl exec client -- curl -s $SERVICE_URL/config | jq '.'
echo ""

# Test 3: Secret environment variables
echo "3️⃣ Testing Secret environment variables (masked)..."
kubectl exec client -- curl -s $SERVICE_URL/secrets | jq '.'
echo ""

# Test 4: ConfigMap files
echo "4️⃣ Testing ConfigMap files..."
kubectl exec client -- curl -s $SERVICE_URL/config/file | jq '.'
echo ""

# Test 5: Secret files
echo "5️⃣ Testing Secret files (masked)..."
kubectl exec client -- curl -s $SERVICE_URL/secrets/file | jq '.'
echo ""

echo "========================================="
echo "✅ All tests completed!"
echo "========================================="
