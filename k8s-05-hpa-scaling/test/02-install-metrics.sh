#!/bin/bash
# Test 02: Install Metrics Server
# Required for HPA to work and for `kubectl top` to show metrics
set -e

echo "=========================================="
echo "Test 02: Install Metrics Server"
echo "=========================================="
echo ""

# Check if already installed
if kubectl get deployment -n kube-system metrics-server &>/dev/null; then
  echo "✅ Metrics Server is already installed"
  kubectl get deployment -n kube-system metrics-server
  echo ""
else
  echo "1. Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  echo ""
fi

echo "2. Patching for Docker Desktop / local clusters (--kubelet-insecure-tls)..."
# Add --kubelet-insecure-tls if not present (idempotent)
CURRENT_ARGS=$(kubectl get deployment -n kube-system metrics-server -o jsonpath='{.spec.template.spec.containers[0].args}')
if echo "$CURRENT_ARGS" | grep -q "kubelet-insecure-tls"; then
  echo "   ✅ Already patched"
else
  kubectl patch -n kube-system deployment metrics-server --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  echo "   ✅ Patched"
fi
echo ""

echo "3. Waiting for metrics-server to be ready (max 90s)..."
kubectl rollout status -n kube-system deployment/metrics-server --timeout=90s
echo ""

echo "4. Waiting for first metrics to be collected (30s)..."
sleep 30
echo ""

echo "5. Verifying with kubectl top..."
echo ""
echo "Nodes:"
kubectl top nodes || echo "   (Metrics may take a bit more to populate, retry in a few seconds)"
echo ""
echo "Pods:"
kubectl top pods -l app=scaling-app || echo "   (Metrics may take a bit more to populate)"
echo ""

echo "=========================================="
echo "✅ Metrics Server Setup Complete!"
echo "=========================================="
echo ""
echo "Try these commands now:"
echo "  kubectl top nodes"
echo "  kubectl top pods"
echo "  kubectl top pods -A"
