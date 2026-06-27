#!/usr/bin/env bash
# Проверка сетевой изоляции между сервисами Task5
set -euo pipefail

NAMESPACE="${NAMESPACE:-task5}"

run_wget() {
  local from_label="$1"
  local target="$2"
  local expect="$3"
  local pod
  pod="test-${from_label}-$(date +%s)"

  if [[ "${from_label}" == "random" ]]; then
    result=$(kubectl run "${pod}" --rm -i --restart=Never -n "${NAMESPACE}" \
      --image=alpine --command -- sh -c "wget -qO- --timeout=2 http://${target} 2>&1" || true)
  else
    result=$(kubectl run "${pod}" --rm -i --restart=Never -n "${NAMESPACE}" \
      --image=alpine --labels "role=${from_label}" --command -- \
      sh -c "wget -qO- --timeout=2 http://${target} 2>&1" || true)
  fi

  if echo "${result}" | grep -qiE 'html|nginx|welcome'; then
    actual="allow"
  else
    actual="deny"
  fi

  if [[ "${actual}" == "${expect}" ]]; then
    echo "  ✓ ${from_label} → ${target}: ${actual} (ожидалось ${expect})"
  else
    echo "  ✗ ${from_label} → ${target}: ${actual} (ожидалось ${expect})"
    echo "    ${result}" | head -1
    return 1
  fi
}

echo "[verify] Проверка connectivity в namespace ${NAMESPACE}..."
fail=0
run_wget front-end back-end-api-app allow || fail=1
run_wget admin-front-end admin-back-end-api-app allow || fail=1
run_wget front-end admin-back-end-api-app deny || fail=1
run_wget admin-front-end back-end-api-app deny || fail=1
run_wget random back-end-api-app deny || fail=1
run_wget random admin-back-end-api-app deny || fail=1

if [[ "${fail}" -eq 0 ]]; then
  echo "[verify] Все проверки пройдены."
else
  echo "[verify] Есть ошибки." >&2
  exit 1
fi
