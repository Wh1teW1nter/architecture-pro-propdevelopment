#!/usr/bin/env bash
# PropDevelopment Task7 — проверка PodSecurity Admission и OPA Gatekeeper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK7_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NAMESPACE="audit-zone"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.17.1}"
GATEKEEPER_URL="https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"

log() { echo "[verify-admission] $*"; }
fail() { echo "[verify-admission] FAIL: $*" >&2; exit 1; }

command -v kubectl >/dev/null || fail "kubectl не найден"
kubectl cluster-info >/dev/null 2>&1 || fail "Кластер недоступен"

apply_and_expect_deny() {
  local manifest="$1"
  local name
  name=$(grep -E '^\s*name:' "${manifest}" | head -1 | awk '{print $2}')
  log "Ожидаем DENY: ${name} ← $(basename "${manifest}")"
  if kubectl apply -f "${manifest}" 2>&1 | tee /tmp/task7-deny.out; then
    kubectl delete pod "${name}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
    fail "${name} был принят — ожидалось отклонение"
  fi
  grep -qiE 'denied|forbidden|violation|restricted|admission|would violate|not allowed' /tmp/task7-deny.out \
    || fail "${name}: отклонён без явного сообщения admission"
  echo "  ✓ ${name} отклонён"
}

apply_and_expect_allow() {
  local manifest="$1"
  local name
  name=$(grep -E '^\s*name:' "${manifest}" | head -1 | awk '{print $2}')
  log "Ожидаем ALLOW: ${name} ← $(basename "${manifest}")"
  kubectl apply -f "${manifest}"
  kubectl wait --for=condition=Ready "pod/${name}" -n "${NAMESPACE}" --timeout=120s
  echo "  ✓ ${name} принят и Ready"
  kubectl delete pod "${name}" -n "${NAMESPACE}" --wait=false >/dev/null 2>&1 || true
}

log "1. Namespace audit-zone (PodSecurity: restricted)"
kubectl apply -f "${TASK7_DIR}/01-create-namespace.yaml"
kubectl get namespace "${NAMESPACE}" --show-labels | grep 'pod-security.kubernetes.io/enforce=restricted' \
  || fail "label pod-security restricted не найден"

log "2. OPA Gatekeeper"
if ! kubectl get ns gatekeeper-system >/dev/null 2>&1; then
  kubectl apply -f "${GATEKEEPER_URL}"
fi
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=180s
kubectl wait --for=condition=Ready pod -l control-plane=audit \
  -n gatekeeper-system --timeout=180s 2>/dev/null || true

log "3. ConstraintTemplates и Constraints"
for f in "${TASK7_DIR}/gatekeeper/constraint-templates/"*.yaml; do
  kubectl apply -f "${f}"
done
sleep 5
for f in "${TASK7_DIR}/gatekeeper/constraints/"*.yaml; do
  kubectl apply -f "${f}"
done
sleep 3
kubectl get constrainttemplates,constraints 2>/dev/null | grep -E 'k8sdisallow|k8srequire' || true

log "4. Небезопасные манифесты (должны быть отклонены)"
for f in "${TASK7_DIR}/insecure-manifests/"*.yaml; do
  apply_and_expect_deny "${f}"
done

log "5. Безопасные манифесты (должны пройти)"
for f in "${TASK7_DIR}/secure-manifests/"*.yaml; do
  apply_and_expect_allow "${f}"
done

log "6. Статус Gatekeeper"
kubectl get pods -n gatekeeper-system

log "Готово: PodSecurity + Gatekeeper работают корректно."
