#!/usr/bin/env bash
# PropDevelopment — создание ClusterRole и namespace для RBAC
set -euo pipefail

log() { echo "[create-roles] $*"; }

command -v kubectl >/dev/null || { echo "kubectl не найден" >&2; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите: minikube start" >&2; exit 1; }

log "Создание namespace доменов PropDevelopment..."
for ns in sales tenant finance data platform; do
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
  log "  ✓ namespace/${ns}"
done

log "Создание ClusterRole: propdev-cluster-viewer..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-viewer
  labels:
    app.kubernetes.io/part-of: propdevelopment
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps", "persistentvolumeclaims",
                "events", "namespaces", "nodes", "endpoints", "serviceaccounts",
                "replicationcontrollers", "resourcequotas"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
EOF

log "Создание ClusterRole: propdev-namespace-developer..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-namespace-developer
  labels:
    app.kubernetes.io/part-of: propdevelopment
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps", "persistentvolumeclaims",
                "serviceaccounts", "events"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

log "Создание ClusterRole: propdev-platform-devops..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-platform-devops
  labels:
    app.kubernetes.io/part-of: propdevelopment
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps", "persistentvolumeclaims",
                "secrets", "events", "serviceaccounts", "endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["namespaces", "nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

log "Создание ClusterRole: propdev-secrets-reader (привилегированная)..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-secrets-reader
  labels:
    app.kubernetes.io/part-of: propdevelopment
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
EOF

log "Создание ClusterRole: propdev-security-auditor (привилегированная)..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-security-auditor
  labels:
    app.kubernetes.io/part-of: propdevelopment
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
EOF

log "Готово. ClusterRoles:"
kubectl get clusterroles -l app.kubernetes.io/part-of=propdevelopment
