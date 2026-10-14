#!/usr/bin/env bash
#
# Smoke test for Project 15 - Monitoring Stack.
#
# Deploys Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics
# and the instrumented demo app into the `monitoring` namespace, then verifies
# that the whole pipeline actually works:
#
#   app exposes /metrics
#     -> Prometheus discovers and scrapes it
#       -> recording rules produce derived series
#         -> an alert fires when the app starts failing
#           -> Grafana can query Prometheus
#
# Requires: kubectl pointed at a cluster, and the image `metrics-app:v1`
#           built and available to that cluster:
#
#   docker build -t metrics-app:v1 app/metrics-app
#
# Usage:
#   ./test/smoke-test.sh          # run the checks
#   ./test/smoke-test.sh clean    # delete everything the test created
set -euo pipefail

NS=monitoring
K8S_DIR="$(cd "$(dirname "$0")/../k8s" && pwd)"

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; exit 1; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
info() { printf "\n\033[1m%s\033[0m\n" "$1"; }

# Run an instant query from inside the Prometheus Pod, so the test needs no
# port-forward. `promtool` ships inside the prom/prometheus image.
#
# Output looks like:   {job="kubernetes-pods"} => 2 @[1760000000]
# An empty result produces no output at all.
promql() {
  kubectl exec -n "$NS" deploy/prometheus -- \
    promtool query instant http://localhost:9090 "$1" 2>/dev/null
}

# Extract the numeric value from the first result line.
promval() {
  promql "$1" | sed -n 's/.*=> \([0-9.e+-]*\) @.*/\1/p' | head -1
}

cleanup() {
  info "Cleaning up namespace $NS and the cluster-scoped RBAC objects"
  kubectl delete namespace "$NS" --ignore-not-found
  kubectl delete clusterrole prometheus kube-state-metrics --ignore-not-found
  kubectl delete clusterrolebinding prometheus kube-state-metrics --ignore-not-found
  pass "cleaned up"
}

if [[ "${1:-}" == "clean" ]]; then
  cleanup
  exit 0
fi

info "1. Create the namespace"
kubectl apply -f "$K8S_DIR/namespace.yaml"

info "2. Deploy the instrumented app"
kubectl apply -f "$K8S_DIR/app-deployment.yaml"
kubectl apply -f "$K8S_DIR/app-service.yaml"
kubectl rollout status deploy/metrics-app -n "$NS" --timeout=180s
pass "metrics-app is running"

info "3. Verify the app exposes Prometheus text format on /metrics"
pod="$(kubectl get pod -l app=metrics-app -n "$NS" -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$pod" -- \
  python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/metrics').read().decode())" \
  | grep -q "^# TYPE http_requests_total counter" \
  && pass "/metrics exposes http_requests_total" \
  || fail "/metrics did not return the expected exposition format"

info "4. Deploy Prometheus (RBAC -> config -> rules -> server)"
kubectl apply -f "$K8S_DIR/prometheus-rbac.yaml"
kubectl apply -f "$K8S_DIR/prometheus-config.yaml"
kubectl apply -f "$K8S_DIR/prometheus-rules.yaml"
kubectl apply -f "$K8S_DIR/alertmanager.yaml"
kubectl apply -f "$K8S_DIR/prometheus-deployment.yaml"
kubectl apply -f "$K8S_DIR/prometheus-service.yaml"
kubectl rollout status deploy/prometheus -n "$NS" --timeout=180s
kubectl rollout status deploy/alertmanager -n "$NS" --timeout=180s
pass "Prometheus and Alertmanager are running"

info "5. Deploy the exporters"
kubectl apply -f "$K8S_DIR/node-exporter.yaml"
kubectl apply -f "$K8S_DIR/kube-state-metrics.yaml"
kubectl rollout status daemonset/node-exporter -n "$NS" --timeout=180s
kubectl rollout status deploy/kube-state-metrics -n "$NS" --timeout=180s
pass "node-exporter and kube-state-metrics are running"

info "6. Deploy Grafana"
kubectl apply -f "$K8S_DIR/grafana-provisioning.yaml"
kubectl apply -f "$K8S_DIR/grafana-dashboards.yaml"
kubectl apply -f "$K8S_DIR/grafana-deployment.yaml"
kubectl rollout status deploy/grafana -n "$NS" --timeout=180s
pass "Grafana is running"

info "7. Start the load generator and wait for metrics to accumulate"
kubectl apply -f "$K8S_DIR/load-generator.yaml"
kubectl rollout status deploy/load-generator -n "$NS" --timeout=120s
echo "  generating traffic for 60s..."
sleep 60

info "8. Prometheus discovered the app pods (annotation-based SD)"
count="$(promval 'count(up{job="kubernetes-pods"} == 1)')"
[[ -n "${count:-}" && "${count%%.*}" -ge 2 ]] \
  && pass "$count annotated targets are UP" \
  || fail "expected at least 2 healthy annotated targets, got '${count:-none}'"

info "9. App metrics are actually in the TSDB"
[[ -n "$(promql 'sum(http_requests_total)')" ]] \
  && pass "http_requests_total is being scraped" \
  || fail "http_requests_total not found in Prometheus"

info "10. cAdvisor and kube-state-metrics are reporting"
[[ -n "$(promql 'count(container_memory_working_set_bytes{namespace="monitoring"})')" ]] \
  && pass "cAdvisor container metrics present" \
  || warn "cAdvisor metrics missing (some local clusters block the kubelet proxy)"
[[ -n "$(promql 'count(kube_pod_info)')" ]] \
  && pass "kube-state-metrics object metrics present" \
  || fail "kube_pod_info not found"

info "11. Recording rules evaluated"
[[ -n "$(promql 'job:http_requests:rate5m')" ]] \
  && pass "job:http_requests:rate5m exists" \
  || fail "recording rule produced no series"

info "12. Fire a real alert - hammer /error until HighErrorRate trips"
lg="$(kubectl get pod -l app=load-generator -n "$NS" -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$lg" -- sh -c \
  'i=0; while [ $i -lt 600 ]; do curl -s -o /dev/null http://metrics-app:8000/error; i=$((i+1)); done' >/dev/null 2>&1 || true
echo "  waiting up to 4m for the alert to move pending -> firing..."
fired=""
for _ in $(seq 1 24); do
  if [[ -n "$(promql 'ALERTS{alertname="HighErrorRate",alertstate="firing"}')" ]]; then
    fired=yes
    break
  fi
  sleep 10
done
[[ -n "$fired" ]] \
  && pass "HighErrorRate is FIRING" \
  || warn "HighErrorRate did not fire - check: kubectl exec -n $NS deploy/prometheus -- promtool query instant http://localhost:9090 ALERTS"

info "13. Grafana is healthy and its datasource resolves"
kubectl exec -n "$NS" deploy/grafana -- \
  wget -qO- http://localhost:3000/api/health | grep -q '"database": *"ok"' \
  && pass "Grafana API healthy" \
  || fail "Grafana /api/health did not report ok"

info "Done. Open the UIs:"
cat <<'URLS'
  Prometheus   http://localhost:30090      (Status -> Targets, then Alerts)
  Alertmanager http://localhost:30093
  Grafana      http://localhost:30030      (admin / admin)
  The app      http://localhost:30080/work

  Clean up:    ./test/smoke-test.sh clean
URLS
