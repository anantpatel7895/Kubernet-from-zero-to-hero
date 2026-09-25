#!/usr/bin/env bash
#
# Smoke test for Project 11 - Resource Management.
# Deploys the demos into the `resource-demo` namespace, verifies QoS classes,
# triggers a CPU burn and a memory OOMKill, then cleans up.
#
# Requires: kubectl pointed at a cluster, metrics-server installed,
#           and the image `loadtest:v1` available to the cluster.
#
# Usage:
#   ./test/smoke-test.sh          # run the checks
#   ./test/smoke-test.sh clean    # delete everything the test created
set -euo pipefail

NS=resource-demo
K8S_DIR="$(cd "$(dirname "$0")/../k8s" && pwd)"

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; exit 1; }
info() { printf "\n\033[1m%s\033[0m\n" "$1"; }

cleanup() {
  info "Cleaning up namespace $NS and cluster-scoped objects"
  kubectl delete namespace "$NS" --ignore-not-found
  kubectl delete priorityclass high-priority low-priority --ignore-not-found
  pass "cleaned up"
}

if [[ "${1:-}" == "clean" ]]; then
  cleanup
  exit 0
fi

info "1. Create namespace"
kubectl apply -f "$K8S_DIR/namespace.yaml"

info "2. Deploy QoS pods (BEFORE the quota, which would reject BestEffort)"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-guaranteed.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-burstable.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/qos-besteffort.yaml"
kubectl wait --for=condition=Ready pod -l qos -n "$NS" --timeout=120s || true

info "3. Verify QoS classes"
for pair in "qos-guaranteed:Guaranteed" "qos-burstable:Burstable" "qos-besteffort:BestEffort"; do
  pod="${pair%%:*}"; want="${pair##*:}"
  got="$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.status.qosClass}')"
  [[ "$got" == "$want" ]] && pass "$pod -> $got" || fail "$pod expected $want, got $got"
done

info "4. Deploy the load-test app"
kubectl apply -n "$NS" -f "$K8S_DIR/deployment.yaml"
kubectl apply -n "$NS" -f "$K8S_DIR/service.yaml"
kubectl rollout status deploy/loadtest -n "$NS" --timeout=120s
pass "loadtest rollout complete"

info "5. Trigger an OOMKill (limit is 256Mi; allocate ~400Mi)"
pod="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$pod" -- sh -c \
  'curl -s "http://localhost:8000/eat-memory?mb=200" >/dev/null; curl -s "http://localhost:8000/eat-memory?mb=200" >/dev/null' || true
sleep 10
reason="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)"
restarts="$(kubectl get pod -l app=loadtest -n "$NS" -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')"
if [[ "$reason" == "OOMKilled" || "${restarts:-0}" -gt 0 ]]; then
  pass "memory limit enforced (reason=${reason:-restart}, restarts=$restarts)"
else
  fail "expected an OOMKill/restart, saw none (reason='$reason', restarts=$restarts)"
fi

info "6. Apply LimitRange + ResourceQuota (namespace governance)"
kubectl apply -f "$K8S_DIR/limitrange.yaml"
kubectl apply -f "$K8S_DIR/resourcequota.yaml"
pass "limitrange and quota applied"

info "7. Confirm the quota now REJECTS a BestEffort pod"
if kubectl run quota-reject --image=loadtest:v1 -n "$NS" --restart=Never \
     --overrides='{"spec":{"containers":[{"name":"quota-reject","image":"loadtest:v1"}]}}' 2>/dev/null; then
  fail "BestEffort pod was admitted despite the quota"
else
  pass "BestEffort pod correctly rejected by the quota"
fi

info "All checks passed. Run './test/smoke-test.sh clean' to tear down."
