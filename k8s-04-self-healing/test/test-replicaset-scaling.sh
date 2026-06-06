#!/bin/bash
# Test: ReplicaSet Scaling & Desired State
# Demonstrates: ReplicaSet enforces the desired pod count

set -e

echo "=========================================="
echo "Test: ReplicaSet Desired State"
echo "=========================================="
echo ""

# Check deployment exists
if ! kubectl get deployment self-healing-app &>/dev/null; then
  echo "❌ Deployment 'self-healing-app' not found!"
  echo "   Run: kubectl apply -f k8s/deployment.yaml"
  exit 1
fi

echo "1. Show the hierarchy: Deployment → ReplicaSet → Pods"
echo ""
echo "   Deployment:"
kubectl get deployment self-healing-app
echo ""
echo "   ReplicaSet (created by Deployment):"
kubectl get rs -l app=self-healing
echo ""
echo "   Pods (created by ReplicaSet):"
kubectl get pods -l app=self-healing
echo ""

echo "2. Current desired replicas: 3"
echo ""

echo "3. Scaling UP to 5 replicas via Deployment..."
kubectl scale deployment self-healing-app --replicas=5
echo ""

echo "4. Waiting for new pods to be ready..."
kubectl rollout status deployment self-healing-app --timeout=60s
echo ""

echo "5. State after scaling up:"
kubectl get deployment self-healing-app
kubectl get pods -l app=self-healing
echo ""

echo "6. Scaling DOWN to 2 replicas..."
kubectl scale deployment self-healing-app --replicas=2
echo ""

sleep 5

echo "7. State after scaling down:"
kubectl get deployment self-healing-app
kubectl get pods -l app=self-healing
echo ""

echo "8. Restoring to 3 replicas..."
kubectl scale deployment self-healing-app --replicas=3
echo ""

kubectl rollout status deployment self-healing-app --timeout=60s
echo ""

echo "9. Final state:"
kubectl get deployment self-healing-app
kubectl get pods -l app=self-healing
echo ""

echo "10. ReplicaSet details:"
RS_NAME=$(kubectl get rs -l app=self-healing -o jsonpath='{.items[0].metadata.name}')
kubectl describe rs $RS_NAME | head -20
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "Key Takeaways:"
echo "  • Scaling = changing desired state"
echo "  • ReplicaSet creates/deletes pods to match"
echo "  • Always scale via Deployment, not ReplicaSet"
echo "  • Operation is fast (seconds, not minutes)"
