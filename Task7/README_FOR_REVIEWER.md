# Task 7 — PodSecurity + OPA Gatekeeper (PropDevelopment)

## Цель

Аудит развёртываний подов в namespace `audit-zone` с уровнем **PodSecurity `restricted`** и дополнительными правилами **OPA Gatekeeper**.

## Структура

```
Task7/
├── 01-create-namespace.yaml      # audit-zone + PodSecurity restricted
├── insecure-manifests/           # 3 pod с нарушениями (должны быть отклонены)
├── secure-manifests/             # исправленные версии (должны пройти)
├── gatekeeper/
│   ├── constraint-templates/     # Rego-шаблоны
│   └── constraints/              # применение в audit-zone
├── verify/
│   ├── verify-admission.sh       # интеграционная проверка в кластере
│   └── validate-security.sh      # статическая проверка манифестов
└── audit-policy.yaml
```

## Быстрый старт

```bash
# Требования: minikube/k8s 1.25+, kubectl
cd Task7

# Статическая проверка манифестов (без кластера)
./verify/validate-security.sh

# Полная проверка admission (PodSecurity + Gatekeeper)
./verify/verify-admission.sh
```

## Политики

| Правило | PodSecurity restricted | Gatekeeper Constraint |
|---------|------------------------|------------------------|
| `privileged: true` запрещён | ✓ | `K8sDisallowPrivileged` |
| `hostPath` запрещён | ✓ | `K8sDisallowHostPath` |
| `runAsNonRoot: true` | ✓ | `K8sRequireSecureContext` |
| `readOnlyRootFilesystem: true` | ✓ | `K8sRequireSecureContext` |

## Нарушения (insecure-manifests)

1. **01-privileged-pod.yaml** — `privileged: true`
2. **02-hostpath-pod.yaml** — volume `hostPath`
3. **03-root-user-pod.yaml** — `runAsUser: 0`

## Исправления (secure-manifests)

- `runAsNonRoot: true`, `runAsUser: 101` (nginx)
- `readOnlyRootFilesystem: true` + `emptyDir` для `/tmp`, `/var/cache/nginx`, `/var/run`
- `hostPath` заменён на `emptyDir`
- `capabilities.drop: ["ALL"]`, `allowPrivilegeEscalation: false`

## Связь с другими заданиями

- **Task 6:** privileged pod из `simulate-incident.sh` прошёл admission — мотивация Task 7
- **Task 4:** RBAC не заменяет Pod Security — нужен defense in depth
- **Task 5:** NetworkPolicy изолирует трафик; PodSecurity/Gatekeeper — конфигурация pod

## Проверка для ревьюера

```bash
# Небезопасный pod — ожидается ошибка admission
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
# Error: pods "pod-privileged" is forbidden: ...

# Безопасный pod — успех
kubectl apply -f secure-manifests/01-secure.yaml
kubectl get pods -n audit-zone
```

Ожидаемый результат `verify-admission.sh`: 3 DENY + 3 ALLOW.
