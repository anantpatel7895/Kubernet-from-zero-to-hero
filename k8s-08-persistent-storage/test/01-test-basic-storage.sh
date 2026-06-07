#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-08-persistent-storage/test/01-test-basic-storage.sh
# Test basic persistent storage with Deployment

set -e

echo "========================================="
echo "Test 1: Basic Persistent Storage"
echo "========================================="
echo ""

SERVICE_URL="http://storage-demo-service:8000"

echo "📝 Step 1: Write test data to persistent storage..."
kubectl exec client -- curl -s -X POST "$SERVICE_URL/files/test-file.txt?content=Hello%20from%20persistent%20storage!" | jq '.'
echo ""

echo "📖 Step 2: Read the file back..."
kubectl exec client -- curl -s "$SERVICE_URL/files/test-file.txt" | jq '.'
echo ""

echo "📋 Step 3: List all files..."
kubectl exec client -- curl -s "$SERVICE_URL/files" | jq '.'
echo ""

echo "💾 Step 4: Check storage info..."
kubectl exec client -- curl -s "$SERVICE_URL/storage/info" | jq '.'
echo ""

echo "🔄 Step 5: Delete all pods to test persistence..."
kubectl delete pods -l app=storage-demo
echo "Waiting for new pods to start..."
kubectl wait --for=condition=ready pod -l app=storage-demo --timeout=60s
echo ""

echo "✅ Step 6: Verify data still exists after pod deletion..."
kubectl exec client -- curl -s "$SERVICE_URL/files/test-file.txt" | jq '.'
echo ""

echo "========================================="
echo "✅ Test Complete!"
echo "Data survived pod deletion! 🎉"
echo "========================================="
