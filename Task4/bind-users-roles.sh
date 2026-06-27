#!/usr/bin/env bash
# PropDevelopment — привязка групп пользователей к ролям (RoleBinding / ClusterRoleBinding)
set -euo pipefail

log() { echo "[bind-users-roles] $*"; }

command -v kubectl >/dev/null || { echo "kubectl не найден" >&2; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите: minikube start" >&2; exit 1; }

apply_binding() {
  kubectl apply -f -
}

log "ClusterRoleBinding: propdev-viewers → propdev-cluster-viewer"
apply_binding <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-viewers-binding
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: propdev-viewers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-cluster-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

log "ClusterRoleBinding: propdev-privileged → propdev-secrets-reader"
apply_binding <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-privileged-secrets-binding
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: propdev-privileged
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-secrets-reader
  apiGroup: rbac.authorization.k8s.io
EOF

log "ClusterRoleBinding: propdev-security → propdev-security-auditor"
apply_binding <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-security-auditor-binding
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: propdev-security
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-security-auditor
  apiGroup: rbac.authorization.k8s.io
EOF

log "ClusterRoleBinding: propdev-devops → propdev-platform-devops (namespace platform)"
apply_binding <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-devops-platform-binding
  namespace: platform
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: propdev-devops
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-platform-devops
  apiGroup: rbac.authorization.k8s.io
EOF

log "ClusterRoleBinding: propdev-devops → propdev-cluster-viewer (обзор кластера)"
apply_binding <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-devops-viewer-binding
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: propdev-devops
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-cluster-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

bind_developer_group() {
  local group="$1"
  local namespace="$2"
  local binding_name="${group}-${namespace}-binding"

  log "RoleBinding: ${group} → propdev-namespace-developer (namespace ${namespace})"
  apply_binding <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${binding_name}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/part-of: propdevelopment
subjects:
  - kind: Group
    name: ${group}
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-namespace-developer
  apiGroup: rbac.authorization.k8s.io
EOF
}

bind_developer_group "propdev-developers-sales"   "sales"
bind_developer_group "propdev-developers-tenant"  "tenant"
bind_developer_group "propdev-developers-finance" "finance"
bind_developer_group "propdev-developers-data"    "data"

log "Готово. Bindings:"
kubectl get clusterrolebindings -l app.kubernetes.io/part-of=propdevelopment
kubectl get rolebindings -l app.kubernetes.io/part-of=propdevelopment -A
