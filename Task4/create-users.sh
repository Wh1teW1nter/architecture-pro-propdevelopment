#!/usr/bin/env bash
# PropDevelopment — создание пользователей Kubernetes (X.509 client certificates)
# Требования: minikube запущен, openssl установлен
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERS_DIR="${SCRIPT_DIR}/users"
MINIKUBE_HOME="${HOME}/.minikube"
CA_CERT="${MINIKUBE_HOME}/ca.crt"
CA_KEY="${MINIKUBE_HOME}/ca.key"
CLUSTER_NAME="${CLUSTER_NAME:-minikube}"
CERT_DAYS=365

# Формат: "username:group1,group2"
USERS=(
  "bi-analyst:propdev-viewers"
  "sales-developer:propdev-developers-sales"
  "tenant-developer:propdev-developers-tenant"
  "devops-engineer:propdev-devops,propdev-privileged"
  "security-officer:propdev-security,propdev-privileged"
)

log() { echo "[create-users] $*"; }
die() { echo "[create-users] ERROR: $*" >&2; exit 1; }

command -v openssl >/dev/null || die "openssl не найден"
command -v kubectl >/dev/null || die "kubectl не найден"
[[ -f "${CA_CERT}" && -f "${CA_KEY}" ]] || die "CA minikube не найден. Запустите: minikube start"

mkdir -p "${USERS_DIR}"

create_user() {
  local username="$1"
  local groups="$2"
  local key_file="${USERS_DIR}/${username}.key"
  local csr_file="${USERS_DIR}/${username}.csr"
  local cert_file="${USERS_DIR}/${username}.crt"

  log "Создание пользователя: ${username} (группы: ${groups})"

  IFS=',' read -ra GROUP_ARR <<< "${groups}"
  local subject="/CN=${username}"
  subject+="/O=${GROUP_ARR[0]}"
  local i
  for ((i=1; i<${#GROUP_ARR[@]}; i++)); do
    subject+="/OU=${GROUP_ARR[$i]}"
  done

  openssl genrsa -out "${key_file}" 2048 2>/dev/null
  openssl req -new -key "${key_file}" -out "${csr_file}" -subj "${subject}" 2>/dev/null
  openssl x509 -req -in "${csr_file}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -CAcreateserial -out "${cert_file}" -days "${CERT_DAYS}" 2>/dev/null
  rm -f "${csr_file}"

  kubectl config set-credentials "${username}" \
    --client-certificate="${cert_file}" \
    --client-key="${key_file}" \
    --embed-certs=true

  kubectl config set-context "${username}@propdev" \
    --cluster="${CLUSTER_NAME}" \
    --user="${username}" \
    --namespace=default

  log "  ✓ ${cert_file}"
}

log "Minikube CA: ${CA_CERT}"
log "Директория пользователей: ${USERS_DIR}"

for entry in "${USERS[@]}"; do
  username="${entry%%:*}"
  groups="${entry#*:}"
  create_user "${username}" "${groups}"
done

log "Готово. Создано пользователей: ${#USERS[@]}"
log "Переключение: kubectl config use-context <user>@propdev"
