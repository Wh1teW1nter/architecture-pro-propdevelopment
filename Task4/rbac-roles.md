# Задание 4. Ролевая модель доступа к Kubernetes — PropDevelopment

Модель RBAC отражает организационную структуру компании (домены «Продажи», «ЖКУ», «Финансы», «Дата», «Платформа») и выводы аудита безопасности из заданий 1–3: принцип минимальных привилегий, изоляция секретов (auth-service, API-ключи партнёров, smart-home), разграничение доступа по namespace.

## Namespace ↔ домены PropDevelopment

| Namespace | Домен | Сервисы |
| --- | --- | --- |
| `sales` | Продажи | client-mart-app, client-tour-app, client-crm-app, витрина |
| `tenant` | ЖКУ | tenant-core-app, smart-home-app, CRM собственников |
| `finance` | Финансы | accountant-service-1 |
| `data` | Дата | DWH ingestion, BI jobs |
| `platform` | Платформа | auth-service-1, ingress, мониторинг |

---

## Таблица ролей

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| **propdev-cluster-viewer** (ClusterRole) | Просмотр (`get`, `list`, `watch`) всех ресурсов кластера **кроме secrets**: pods, services, deployments, configmaps, events, namespaces, nodes (без изменения). Доступ только на чтение для мониторинга и аудита без доступа к секретам. | `propdev-viewers` — аналитики BI (домен «Дата»), бизнес-аналитики, менеджеры (операционные команды) |
| **propdev-namespace-developer** (ClusterRole) | Настройка приложений в namespace домена: `create/update/patch/delete` для deployments, services, configmaps, ingresses, HPA, jobs; `get/list/watch` pods и logs. **Без доступа к secrets** и cluster-scoped ресурсов. Применяется через RoleBinding в конкретном namespace. | `propdev-developers-sales` — разработчики домена «Продажи»; `propdev-developers-tenant` — разработчики домена «ЖКУ» (в т.ч. smart-home-app); `propdev-developers-finance` — разработчики «Финансы»; `propdev-developers-data` — разработчики «Дата» |
| **propdev-platform-devops** (ClusterRole) | Настройка кластера и платформенных компонентов: полное управление ресурсами в namespace `platform` и `kube-system` (deployments, services, configmaps, ingresses, networkpolicies); чтение nodes и namespaces; управление CRD/Helm releases в platform. **Без cluster-admin.** | `propdev-devops` — DevOps-инженеры продуктовых команд |
| **propdev-secrets-reader** (ClusterRole) | **Привилегированная роль:** `get`, `list`, `watch` для **secrets** во всех namespace. Доступ только на чтение секретов (API-ключи партнёров, Keycloak, smart-home credentials). Без права изменения или удаления. | `propdev-privileged` — DevOps-инженеры (ведущие), специалист по ИБ |
| **propdev-security-auditor** (ClusterRole) | **Привилегированная роль для ИБ:** `get`, `list`, `watch` всех ресурсов включая secrets; `get/list` events и audit-related resources. Только чтение — для расследования инцидентов (утечки ПДн, Task 2). | `propdev-security` — специалист по информационной безопасности (единственный в компании) |

---

## Пользователи (примеры)

| Пользователь (CN) | Группы (O=) | Роль в компании |
| --- | --- | --- |
| `bi-analyst` | propdev-viewers | Аналитик BI — мониторинг data-namespace |
| `sales-developer` | propdev-developers-sales | Разработчик client-mart-app / client-tour-app |
| `tenant-developer` | propdev-developers-tenant | Разработчик tenant-core-app / smart-home-app |
| `devops-engineer` | propdev-devops, propdev-privileged | DevOps — настройка кластера и доступ к секретам |
| `security-officer` | propdev-security, propdev-privileged | Специалист ИБ — аудит и расследование инцидентов |
