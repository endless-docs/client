---
title: Client architecture traceability
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

# Client architecture traceability

## Normative system sources

| System decision/specification | Client realization |
| --- | --- |
| `architecture/docs/adr/0001-local-first-architecture.md` | [Overview](overview.md), [delivery](delivery-plan.md) |
| `architecture/docs/adr/0002-isar-as-local-storage.md` | [Persistence](persistence.md) |
| `architecture/docs/adr/0003-local-daemon-as-storage-owner.md` | [Process topology](process-topology.md), [Local API](local-api.md) |
| `architecture/docs/adr/0004-operation-log-based-sync.md` | [Domain model](domain-model.md), [persistence](persistence.md) |
| `architecture/docs/adr/0007-versioned-cross-repository-contracts.md` | [Local API](local-api.md), [MCP/CLI](mcp-and-cli.md) |
| `architecture/docs/specifications/local-first.md` | [Overview](overview.md), [data flow](data-flow.md) |
| `architecture/docs/specifications/document-model.md` | [Domain model](domain-model.md) |
| `architecture/docs/specifications/local-storage.md` | [Persistence](persistence.md) |
| `architecture/docs/specifications/local-daemon.md` | [Process topology](process-topology.md), [Local API](local-api.md) |
| `architecture/docs/specifications/operation-log.md` | [Domain model](domain-model.md), [persistence](persistence.md) |
| `architecture/docs/specifications/offline-mode.md` | [Quality/testing](quality-and-testing.md) |
| `architecture/docs/security/threat-model.md` | [Security](security.md) |
| `architecture/docs/quality/performance.md` | [Quality/testing](quality-and-testing.md) |
| `architecture/docs/quality/reliability.md` | [Quality/testing](quality-and-testing.md) |
| `architecture/docs/roadmap/mvp.md` | [Delivery plan](delivery-plan.md) |

Coordinates относятся к repository `endless-docs/architecture`.

## Planned contract dependencies

Machine-readable source хранится только в `endless-docs/contracts`.

| Contract family | Planned coordinate | Client consumers |
| --- | --- | --- |
| Local API | `contracts/local/v1/` | UI, `locald`, MCP, CLI |
| MCP | `contracts/mcp/v1/` | MCP server |
| Document format | `contracts/schema/document/v1/` | import/export, Operation Log |
| Operation format | `contracts/protobuf/sync/v1/` или принятый successor | Operation Log/future Sync |

До публикации contract client architecture может фиксировать semantics, но не
должна создавать конкурирующий cross-repository schema source.

## Evidence map

| Architecture rule | Required repository evidence |
| --- | --- |
| Only `locald` opens Isar | Dependency check + real-process integration test |
| Durable acknowledgement | Kill-before/after-commit test |
| Command idempotency | Duplicate command property/integration tests |
| Operation atomicity | Real Isar transaction fault test |
| Offline independence | Network-disabled end-to-end suite |
| MCP/CLI use Local API | Import graph + headless process tests |
| Safe migrations | Fixture for every released schema |
| Local endpoint security | Unauthorized caller/path tests |
| Performance targets | Versioned benchmark report |
| Portable recovery | Export → clean restore end-to-end |

## Change escalation

Если implementation требует изменить system invariant, client project не меняет
соседние repositories. Он возвращает в architecture project:

1. affected invariant;
2. evidence/problem;
3. proposed alternatives;
4. compatibility/migration impact;
5. required contract changes;
6. client task blocked by decision.
