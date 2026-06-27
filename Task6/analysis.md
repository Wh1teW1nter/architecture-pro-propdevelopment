# Отчёт по результатам анализа Kubernetes Audit Log

Кластер: Minikube с `audit-policy.yaml` (монтирование через `~/.minikube/files/`) и audit-log.  
Симуляция: `simulate-incident.sh` в namespace `secure-ops`.

## Подозрительные события

### 1. Доступ к секретам

- **Кто:** `minikube-user` (impersonation → `system:serviceaccount:secure-ops:monitoring`)
- **Где:** namespace `kube-system`, resource `secrets`, verb `list`
- **Почему подозрительно:** ServiceAccount `monitoring` из нового namespace `secure-ops` пытается получить список секретов в системном namespace. Это типичный reconnaissance перед exfiltration токенов и credentials. RBAC отклонил запрос (`403 Forbidden`), но попытка зафиксирована в audit log (`auditID: aed9ce33-e803-4ed1-a39f-6b38c74c58a0`).

### 2. Привилегированные поды

- **Кто:** `minikube-user` (группа `system:masters`)
- **Комментарий:** Создан pod `privileged-pod` в `secure-ops` с `securityContext.privileged: true`. Такой pod получает полный доступ к host namespace — возможность побега из контейнера, перехват трафика, доступ к host filesystem. Событие: `create pods/privileged-pod`, HTTP 201, decision `allow`. Admission Policy (Pod Security) не заблокировала создание.

### 3. Использование kubectl exec в чужом поде

- **Кто:** `minikube-user`
- **Что делал:** `kubectl exec` в pod `coredns-7d764666f9-kv6h5` (namespace `kube-system`) — команда `cat /etc/resolv.conf`. Это lateral movement: доступ к системному pod из пользовательского контекста. Событие: `get pods/exec`, decision `allow`, response code 101 (WebSocket upgrade). Pod принадлежит другому namespace/команде — нарушение принципа least privilege.

### 4. Создание RoleBinding с правами cluster-admin

- **Кто:** `minikube-user`
- **К чему привело:** Создан `RoleBinding/escalate-binding` в `secure-ops`, привязавший SA `monitoring` к `ClusterRole/cluster-admin`. Это **прямая эскалация привилегий**: после применения SA `monitoring` получает полный контроль над кластером. HTTP 201, decision `allow`. Критическая ошибка RBAC — любой пользователь с правом create RoleBinding в namespace может выдать cluster-admin.

### 5. Удаление audit-policy.yaml

- **Кто:** Попытка от имени `--as=admin` (файл `/etc/kubernetes/audit-policy.yaml` отсутствовал на хосте)
- **Возможные последствия:** Команда `kubectl delete -f /etc/kubernetes/audit-policy.yaml --as=admin` не выполнилась (файл не найден). В audit log событие не зафиксировано. В production удаление или подмена audit policy означало бы **слепую зону** для расследования инцидентов и нарушение требований compliance (152-ФЗ, ISO 27001 — Task 2).

## Вывод

Симуляция выявила **критические пробелы RBAC PropDevelopment**:

| Проблема | Риск | Рекомендация (связь с Task 4) |
|----------|------|-------------------------------|
| `minikube-user` / `system:masters` может создавать privileged pods | Компрометация node | Pod Security Admission: `restricted` для app namespaces |
| exec в системные pods разрешён | Lateral movement, утечка данных | Ограничить `pods/exec` через RBAC; только `propdev-devops` |
| create RoleBinding → cluster-admin | Полная компрометация кластера | Запретить bind cluster-admin на namespace level; audit + approval workflow |
| SA monitoring без прав на secrets — попытка всё равно логируется | Reconnaissance | Алерт на `secrets` + `forbid` + impersonation |
| Privileged pod создан без блокировки | Host escape | NetworkPolicy (Task 5) + PSA |

**Компрометация кластера** наступает после создания `escalate-binding`: SA `monitoring` получает `cluster-admin` и может читать все secrets (Keycloak, smart-home API keys из Task 3), удалять audit trail и развёртывать malicious workloads.

Audit policy (RequestResponse для pods/secrets/rolebindings) позволила зафиксировать все ключевые события. Для production рекомендуется централизованный сбор (ELK/Loki) и алерты на: `secrets` access, `privileged` pods, `cluster-admin` bindings, `pods/exec` в kube-system.
