#!/usr/bin/env bash
# PropDevelopment Task7 — статическая проверка securityContext в манифестах
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK7_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo "[validate-security] $*"; }
ok() { echo "  ✓ $*"; }
bad() { echo "  ✗ $*" >&2; ERR=1; }

ERR=0

check_insecure() {
  local file="$1"
  local name
  name=$(basename "${file}")
  log "INSECURE ${name} — должен нарушать политику:"

  if grep -q 'privileged: true' "${file}" 2>/dev/null; then
    ok "privileged: true (нарушение)"
  elif grep -q 'hostPath:' "${file}" 2>/dev/null; then
    ok "hostPath (нарушение)"
  elif grep -q 'runAsUser: 0' "${file}" 2>/dev/null || grep -q 'runAsNonRoot: false' "${file}" 2>/dev/null; then
    ok "root UID / runAsNonRoot: false (нарушение)"
  else
    bad "${name}: не найдено ожидаемое нарушение"
  fi
}

check_secure() {
  local file="$1"
  local name
  name=$(basename "${file}")
  log "SECURE ${name} — должен соответствовать политике:"

  grep -q 'runAsNonRoot: true' "${file}" || bad "${name}: нет runAsNonRoot: true"
  grep -q 'readOnlyRootFilesystem: true' "${file}" || bad "${name}: нет readOnlyRootFilesystem: true"
  grep -q 'privileged: false' "${file}" || bad "${name}: нет privileged: false"
  ! grep -q 'hostPath:' "${file}" || bad "${name}: содержит hostPath"
  ! grep -q 'runAsUser: 0' "${file}" || bad "${name}: runAsUser: 0"

  [[ "${ERR}" -eq 0 ]] && ok "${name} прошёл статическую проверку"
}

log "=== insecure-manifests/ ==="
for f in "${TASK7_DIR}/insecure-manifests/"*.yaml; do
  check_insecure "${f}"
done

log "=== secure-manifests/ ==="
for f in "${TASK7_DIR}/secure-manifests/"*.yaml; do
  check_secure "${f}"
done

log "=== gatekeeper/ ==="
for f in "${TASK7_DIR}/gatekeeper/constraint-templates/"*.yaml; do
  grep -q 'ConstraintTemplate' "${f}" && ok "$(basename "${f}") — ConstraintTemplate"
done
for f in "${TASK7_DIR}/gatekeeper/constraints/"*.yaml; do
  grep -q 'enforcementAction: deny' "${f}" && ok "$(basename "${f}") — enforcementAction: deny"
done

if [[ "${ERR}" -ne 0 ]]; then
  log "Есть ошибки валидации."
  exit 1
fi
log "Все статические проверки пройдены."
