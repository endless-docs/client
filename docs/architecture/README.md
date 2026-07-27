---
title: Client architecture
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0002
  - ADR-0003
  - ADR-0004
  - ADR-0007
---

# Client architecture

## Назначение

Этот раздел переводит общесистемные решения Endless Docs в исполнимую
архитектуру репозитория `client`.

## Текущая цель

Поставить production-ready, publicly distributable Flutter desktop client с
полным offline document workflow, Isar под исключительным контролем `locald` и
одинаковым domain behavior для Flutter UI, MCP и CLI.

## Граница ответственности

Репозиторий владеет:

- Flutter application и desktop integration;
- `locald`, его lifecycle и Local API runtime;
- client domain/application packages;
- Isar adapter, schema migrations и local recovery;
- local search и attachments;
- MCP server и CLI adapters;
- installers, diagnostics и client release artifacts;
- client unit, integration, widget, fault-injection и benchmark tests.

Репозиторий не владеет cloud backend, billing, identity, infrastructure,
cross-repository machine-readable contracts или общесистемными ADR.

## Архитектурные инварианты

1. Только `locald` открывает Isar.
2. Все mutations проходят одну application command pipeline.
3. Domain mutation, command deduplication и Operation Log фиксируются одной Isar
   transaction.
4. Flutter UI, MCP и CLI являются Local API clients.
5. Domain packages не зависят от Flutter widgets, Isar generated models и
   transport.
6. Local workflows не вызывают cloud и не требуют account.
7. Search indexes и caches rebuildable; documents и Operation Log authoritative.
8. Attachment paths находятся под managed profile root и не принимаются на
   доверие от caller.
9. API, Isar schema, document format, operation format и MCP versioned
   независимо.
10. Неподдерживаемая версия блокирует writes безопасно и сохраняет export/recovery
    path.

## Карта документов

| Документ | Что фиксирует |
| --- | --- |
| [Overview](overview.md) | Client MVP и ключевые boundaries |
| [Process topology](process-topology.md) | Processes, lifecycle и storage |
| [Module boundaries](module-boundaries.md) | Packages и dependency rules |
| [Local API](local-api.md) | Commands, queries, events и errors |
| [Persistence](persistence.md) | Isar, transactions, migrations и backup |
| [Domain model](domain-model.md) | Workspaces, documents, blocks и operations |
| [Data flow](data-flow.md) | Write/read/attachment flows |
| [MCP and CLI](mcp-and-cli.md) | Headless surfaces и scopes |
| [Security](security.md) | Local threat controls |
| [Quality and testing](quality-and-testing.md) | Tests, performance и reliability |
| [Delivery plan](delivery-plan.md) | Work packages C0–C8 |
| [Traceability](traceability.md) | Связь с system ADR и contracts |
| [Open decisions](open-decisions.md) | Решения, которые нельзя выдумывать |

## Правило изменения

Client detail можно менять здесь, если системные boundaries остаются
неизменными. Изменение local-first свойства, владельца Isar, sync model или
cross-repository contract сначала требует решения в `endless-docs/architecture`.
