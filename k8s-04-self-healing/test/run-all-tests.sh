#!/bin/bash
# Master test runner for Project 04 - Self Healing

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "╔══════════════════════════════════════════╗"
echo "║   Project 04 - Self Healing Test Suite   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! kubectl get deployment self-healing-app &>/dev/null; then
  echo "   Deploying self-healing app..."
  kubectl apply -f k8s/deployment.yaml
fi

if ! kubectl get service self-healing-service &>/dev/null; then
  echo "   Deploying service..."
  kubectl apply -f k8s/service.yaml
fi

echo "   Waiting for deployment to be ready..."
kubectl rollout status deployment self-healing-app --timeout=120s
echo ""

# Test 1: Pod Deletion
echo "▶ TEST 1: Pod Deletion & Recreation"
echo "──────────────────────────────────────"
bash test/test-pod-deletion.sh
echo ""
echo ""

# Test 2: Crash Recovery
echo "▶ TEST 2: Container Crash Recovery"
echo "──────────────────────────────────────"
bash test/test-crash-recovery.sh || true
echo ""
echo ""

# Test 3: ReplicaSet Scaling
echo "▶ TEST 3: ReplicaSet Desired State"
echo "──────────────────────────────────────"
bash test/test-replicaset-scaling.sh
echo ""
echo ""

# Test 4: Zero-Downtime
echo "▶ TEST 4: Zero-Downtime Resilience"
echo "──────────────────────────────────────"
bash test/test-zero-downtime.sh || true
echo ""
echo ""

echo "╔══════════════════════════════════════════╗"
echo "║          ✅ ALL TESTS COMPLETE!          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Cleanup:"
echo "  kubectl delete pod crashing-pod --ignore-not-found=true"
echo "  kubectl delete -f k8s/"
