---
title: Client module boundaries
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0003
  - ADR-0007
---

# Client module boundaries

## Target source layout

Названия могут уточняться без изменения dependency rules.

```text
apps/
  endless_app/            Flutter desktop UI
  locald/                 Local daemon composition root
  mcp_server/             MCP process composition root
  endless_cli/            CLI composition root

packages/
  client_domain/          Entities, values, invariants, domain operations
  client_application/     Commands, queries, ports, transaction orchestration
  codex_app_server/        Optional Codex app-server protocol and document AI
  local_api/              Semantic API facade and transport-neutral interfaces
  local_api_client/       Typed client, reconnect and event subscriptions
  persistence_isar/       Isar records, indexes, mappers, migrations
  local_search/           Search port implementation and projections
  local_attachments/      Managed file storage and recovery journal
  platform_runtime/       Paths, process locks, IPC and secure OS integration
  client_observability/   Errors, metrics, bounded/redacted diagnostics
```

Machine-readable schema source не создаётся в этих packages. Когда Local API или
MCP schema публикуется, source принадлежит `endless-docs/contracts`, а client
использует generated/versioned artifact.

## Dependency direction

```text
Flutter UI / MCP / CLI
          |
          v
Local API client
          |
          v
Local API server facade
          |
          v
Application services --> Domain
          |
          +--> Persistence port --> Isar adapter
          +--> Search port ------> Search adapter
          +--> Attachment port --> Attachment adapter
          +--> Clock/ID/Audit ---> Platform adapters
```

## Import rules

| Module | May depend on | Must not depend on |
| --- | --- | --- |
| `client_domain` | Dart standard libraries, small value packages | Flutter, Isar, IPC, MCP |
| `client_application` | Domain, port interfaces | Flutter widgets, Isar records |
| `local_api` | Application DTO mapping, contract artifact | Isar, UI |
| `local_api_client` | Contract artifact, transport client | Domain internals, Isar |
| `persistence_isar` | Isar, domain/application ports | UI, MCP |
| Flutter UI | `local_api_client`, presentation packages | Isar, application internals |
| `codex_app_server` | Dart standard library, Codex child process | Isar, Local API internals |
| MCP server | `local_api_client`, MCP SDK | Isar, domain internals |
| CLI | `local_api_client`, CLI framework | Isar, domain internals |
| `locald` root | Application, adapters, Local API host | Flutter UI |

## Composition roots

Только `apps/locald` связывает persistence/search/attachment implementations с
application ports. UI tests могут использовать fake Local API client, но
production UI не получает in-process shortcut к domain/application packages.

MCP и CLI всегда проходят настоящий Local API boundary в integration tests.

## Enforcement

- Dart package dependency graph проверяется CI.
- Запрещённые imports проверяются static rule или repository script.
- Isar dependency разрешена только `persistence_isar` и `apps/locald`
  composition wiring.
- Generated contract artifact обновляется отдельным Conventional Commit.
- Circular package dependencies запрещены.

Canonical diagram: `docs/architecture/diagrams/components.mmd`.
