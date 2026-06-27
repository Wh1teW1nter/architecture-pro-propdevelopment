#!/usr/bin/env bash
# PropDevelopment — настройка Minikube с Kubernetes Audit Log
# Конфигурация подключается «снаружи» через ~/.minikube/files/ и --extra-config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIKUBE_FILES="${HOME}/.minikube/files"
AUDIT_POLICY_SRC="${SCRIPT_DIR}/audit-policy.yaml"
AUDIT_LOG_EXPORT="/var/log/audit.log"

log() { echo "[setup-audit] $*"; }

[[ -f "${AUDIT_POLICY_SRC}" ]] || { echo "Не найден ${AUDIT_POLICY_SRC}" >&2; exit 1; }

log "Подготовка файлов на хосте (~/.minikube/files/)..."
mkdir -p "${MINIKUBE_FILES}/etc/ssl/certs"
mkdir -p "${MINIKUBE_FILES}/etc/kubernetes"
mkdir -p "${MINIKUBE_FILES}/var/log"

cp "${AUDIT_POLICY_SRC}" "${MINIKUBE_FILES}/etc/ssl/certs/audit-policy.yaml"
cp "${AUDIT_POLICY_SRC}" "${MINIKUBE_FILES}/etc/kubernetes/audit-policy.yaml"
rm -f "${MINIKUBE_FILES}/var/log/audit.log"

log "Остановка minikube..."
minikube stop 2>/dev/null || true

log "Запуск minikube с audit-policy и ${AUDIT_LOG_EXPORT}..."
minikube start \
  --driver=docker \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path="${AUDIT_LOG_EXPORT}" \
  --extra-config=apiserver.audit-log-maxage=7 \
  --extra-config=apiserver.audit-log-maxbackup=3 \
  --extra-config=apiserver.audit-log-maxsize=100

kubectl wait --for=condition=ready pod -l component=kube-apiserver -n kube-system --timeout=120s
kubectl get ns >/dev/null
sleep 2

if minikube ssh -- "test -s ${AUDIT_LOG_EXPORT}" 2>/dev/null; then
  lines=$(minikube ssh -- "wc -l < ${AUDIT_LOG_EXPORT}" 2>/dev/null | tr -d ' \r')
  log "✓ Audit log: ${lines} строк в ${AUDIT_LOG_EXPORT}"
else
  log "⚠ ${AUDIT_LOG_EXPORT} пуст — используйте extract-audit-events.sh (fallback: kubectl logs apiserver)"
fi

log "Готово. Следующий шаг: ./simulate-incident.sh && ./extract-audit-events.sh"
