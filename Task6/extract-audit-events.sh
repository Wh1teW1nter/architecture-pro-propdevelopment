#!/usr/bin/env bash
# PropDevelopment — фильтрация подозрительных событий из Kubernetes Audit Log
# Использование:
#   ./extract-audit-events.sh [audit.log] [output.json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${1:-}"
OUTPUT="${2:-${SCRIPT_DIR}/audit-extract.json}"

log() { echo "[extract-audit] $*" >&2; }

fetch_audit_log() {
  local dest="$1"
  if [[ -n "${INPUT}" && -f "${INPUT}" ]]; then
    cp "${INPUT}" "${dest}"
    return
  fi
  if [[ -f "${SCRIPT_DIR}/audit.log" ]]; then
    cp "${SCRIPT_DIR}/audit.log" "${dest}"
    return
  fi
  if minikube status >/dev/null 2>&1; then
    if minikube ssh -- "test -s /var/log/audit.log" 2>/dev/null; then
      minikube ssh -- "cat /var/log/audit.log" > "${dest}"
      return
    fi
    log "Файл /var/log/audit.log пуст — извлекаем из логов kube-apiserver"
    kubectl logs -n kube-system kube-apiserver-minikube 2>/dev/null \
      | grep '"kind":"Event"' > "${dest}" || true
    [[ -s "${dest}" ]] && return
  fi
  echo "Не найден audit.log. Укажите путь: $0 /path/to/audit.log" >&2
  exit 1
}

command -v jq >/dev/null || { echo "Требуется jq" >&2; exit 1; }

TMP=$(mktemp)
fetch_audit_log "${TMP}"

grep '"kind":"Event"' "${TMP}" > "${TMP}.events" || true
mv "${TMP}.events" "${TMP}"

log "Источник: $(wc -l < "${TMP}") строк"

SECRETS=$(jq -sc '[.[] | select(.objectRef.resource=="secrets" and (.verb=="get" or .verb=="list"))]' "${TMP}" 2>/dev/null || echo '[]')
EXEC=$(jq -sc '[.[] | select((.verb=="create" or .verb=="get") and .objectRef.subresource=="exec")]' "${TMP}" 2>/dev/null || echo '[]')
PRIV=$(jq -sc '[.[] | select(.objectRef.resource=="pods" and (.requestObject.spec.containers[]?.securityContext.privileged==true))]' "${TMP}" 2>/dev/null || echo '[]')
RBAC=$(jq -sc '[.[] | select(.objectRef.resource=="rolebindings" and .verb=="create")]' "${TMP}" 2>/dev/null || echo '[]')
AUDIT_POLICY=$(grep -i 'audit-policy' "${TMP}" | jq -sc '[inputs]' 2>/dev/null || echo '[]')
PRIV_RESP=$(jq -sc '[.[] | select(.objectRef.resource=="pods" and .verb=="create" and (.requestObject.spec.containers[]?.securityContext.privileged==true or .responseObject.spec.containers[]?.securityContext.privileged==true))]' "${TMP}" 2>/dev/null || echo '[]')

jq -n \
  --argjson secrets "${SECRETS}" \
  --argjson exec "${EXEC}" \
  --argjson privileged "${PRIV}" \
  --argjson privileged_response "${PRIV_RESP}" \
  --argjson rolebindings "${RBAC}" \
  --argjson audit_policy "${AUDIT_POLICY:-[]}" \
  '{
    extractedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    summary: {
      secrets_access: ($secrets | length),
      exec_into_pods: ($exec | length),
      privileged_pods: (($privileged + $privileged_response) | unique_by(.auditID) | length),
      rolebinding_escalation: ($rolebindings | length),
      audit_policy_events: ($audit_policy | length)
    },
    events: {
      secrets_access: $secrets,
      exec_into_pods: $exec,
      privileged_pods: (($privileged + $privileged_response) | unique_by(.auditID)),
      rolebinding_escalation: $rolebindings,
      audit_policy: $audit_policy
    }
  }' > "${OUTPUT}"

log "Сохранено: ${OUTPUT}"
jq '.summary' "${OUTPUT}"

rm -f "${TMP}"
