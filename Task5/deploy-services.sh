#!/usr/bin/env bash
# PropDevelopment — развёртывание сервисов и сетевых политик (Задание 5)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-task5}"

log() { echo "[task5] $*"; }

command -v kubectl >/dev/null || { echo "kubectl не найден" >&2; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите: minikube start --cni=calico" >&2; exit 1; }

log "Namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

deploy() {
  local name="$1"
  local role="$2"
  if kubectl get pod "${name}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    log "  ✓ pod/${name} уже существует"
  else
    kubectl run "${name}" --image=nginx --labels "role=${role}" --expose --port 80 -n "${NAMESPACE}"
    log "  ✓ pod/${name} (role=${role})"
  fi
}

log "Развёртывание сервисов..."
deploy front-end-app front-end
deploy back-end-api-app back-end-api
deploy admin-front-end-app admin-front-end
deploy admin-back-end-api-app admin-back-end-api

kubectl wait --for=condition=ready pod -l role -n "${NAMESPACE}" --timeout=120s

log "Применение сетевых политик..."
kubectl apply -f "${SCRIPT_DIR}/non-admin-api-allow.yaml"
kubectl apply -f "${SCRIPT_DIR}/admin-api-allow.yaml"

log "Готово:"
kubectl get pods,svc,networkpolicy -n "${NAMESPACE}"
