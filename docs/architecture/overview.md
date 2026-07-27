---
title: Client architecture overview
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0002
  - ADR-0003
  - ADR-0004
---

# Client architecture overview

## Контекст

Endless Docs Client — local-first приложение. Его ценность не зависит от cloud:
пользователь создаёт workspaces и documents, редактирует blocks, ищет,
импортирует, экспортирует и использует MCP полностью offline.

## Архитектурный срез Client MVP

```text
Flutter UI process
        |
        | versioned authenticated Local API
        v
locald process
        |-- Application command/query pipeline
        |-- Domain model
        |-- Isar adapter
        |-- Local search
        |-- Attachment storage
        |-- Operation Log
        |-- Migration / backup / diagnostics
        |
        +-- Isar profile storage
        +-- managed attachment files

MCP server process ---- Local API
CLI process ----------- Local API
```

Cloud Sync adapter отсутствует или compile/runtime-disabled в Client MVP.
Local workflows не содержат cloud stubs, которые могут блокировать пользователя.

## Основные решения

- UI отвечает за presentation, navigation и projections, но не за persistence.
- `locald` является application host и единственной durable write boundary.
- Domain behavior доступен только через commands/queries; adapter не меняет
  domain state напрямую.
- Local API transport скрыт за typed client, чтобы заменить IPC без изменения UI,
  MCP и CLI semantics.
- Isar records отображаются в domain entities через mapper; generated records не
  покидают persistence package.
- Operation Log создаётся с первого релиза, даже без network Sync.
- Search и attachments используют ports, принадлежащие application layer.
- Client installer поставляет совместимый набор UI, `locald`, MCP, CLI, migrations
  и version manifest.

## Trust boundaries

1. User/Flutter UI → Local API.
2. External MCP caller → MCP server → Local API.
3. CLI invocation → Local API.
4. `locald` → OS filesystem / Isar.
5. Installer/update channel → installed binaries.

OS user не равен автоматически доверенному MCP caller. Каждый adapter получает
минимально необходимые scopes.

## Владение данными

| Данные | Authoritative owner | Storage |
| --- | --- | --- |
| Workspaces/documents/blocks | `locald` domain | Isar |
| Command deduplication | `locald` | Isar |
| Local Operation Log | `locald` | Isar |
| Search projection | `locald`, rebuildable | Isar или search adapter |
| Attachment metadata | `locald` | Isar |
| Attachment bytes | `locald` attachment adapter | Managed filesystem |
| Local API session | `locald` runtime | Memory/protected endpoint state |
| Cloud credentials | Не входят в Client MVP | Future OS secure storage |

## Диаграммы

- `docs/architecture/diagrams/process-topology.mmd`
- `docs/architecture/diagrams/components.mmd`
- `docs/architecture/diagrams/local-command.mmd`
