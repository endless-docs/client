---
title: Client delivery plan
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

# Client delivery plan

## Objective

Deliver a production-ready, publicly distributable Flutter desktop client that
provides a complete offline document workflow, uses Isar exclusively through
`locald`, and exposes the same domain behavior through Flutter UI, MCP, and CLI.

Cloud, identity, billing, entitlements, web и infrastructure не входят в этот
delivery plan.

## C0 — Architecture spikes

Deliverables:

- Flutter/Dart workspace;
- target platform matrix decision;
- open-source license decision;
- Isar headless process proof;
- IPC comparison and selected transport;
- runnable UI → `locald` → Isar vertical slice;
- Local API v1 semantic envelope;
- initial block/import/export decision.

Exit: real Flutter UI выполняет typed create/read через отдельный `locald`; UI не
импортирует Isar.

## C1 — `locald` host and Local API

Deliverables:

- profile discovery and paths;
- process lock and supervision;
- protected endpoint and handshake;
- health/readiness;
- typed client, reconnect and event stream;
- stable errors and command IDs.

Exit: concurrent UI/MCP/CLI harnesses подключаются к одному owner process, crash
и version mismatch имеют deterministic behavior.

## C2 — Isar persistence and migrations

Deliverables:

- records/mappers/indexes;
- transaction abstraction;
- command deduplication;
- Operation Log;
- migration fixtures;
- backup/restore;
- attachment staging journal.

Exit: fault injection не теряет committed data и не создаёт duplicated effect.

## C3 — Workspace and document domain

Deliverables:

- workspace lifecycle;
- document tree;
- document/block commands and queries;
- revisions/conflicts;
- tombstone/recycle/restore;
- import normalization foundation.

Exit: domain and Local API integration tests доказывают полный CRUD/tree flow.

## C4 — Flutter document experience

Deliverables:

- workspace switcher;
- document tree;
- block editor;
- autosave/pending/error states;
- keyboard navigation and accessibility baseline;
- empty/recovery states.

Exit: пользователь полностью offline создаёт и редактирует дерево документов,
restart не теряет durable changes.

## C5 — Local knowledge capabilities

Deliverables:

- full-text search;
- local attachments;
- import validation/execution;
- portable export;
- recycle bin;
- benchmark dataset/report.

Exit: export восстанавливается в clean profile, search достигает targets,
malformed import не оставляет partial active state.

## C6 — MCP and CLI

Deliverables:

- MCP resources/tools;
- scopes and destructive confirmation;
- MCP audit;
- CLI command groups;
- stable machine output and exit codes;
- headless lifecycle/reconnect.

Exit: MCP/CLI работают без UI и сети, не импортируют Isar, retry идемпотентен.

## C7 — Hardening

Deliverables:

- threat-case suite;
- diagnostics/redaction;
- compatibility manifest;
- long offline soak;
- fault-injection matrix;
- dependency/license audit and SBOM.

Exit: security/reliability/performance gates имеют сохранённые reports.

## C8 — Public release

Deliverables:

- installers for accepted platform matrix;
- signing/notarization where applicable;
- clean install/upgrade/uninstall tests;
- user documentation and privacy disclosure;
- release notes and known limitations;
- public source/license/notices.

Exit: release artifact проходит Definition of Done и clean-machine smoke.

## Dependency order

```text
C0 -> C1 -> C2 -> C3 -> C4
                       |-> C5
                       |-> C6
C5 + C6 -> C7 -> C8
```

Parallel work начинается только после принятия shared domain и Local API
boundaries.

## Client MVP acceptance

1. Install/start не требует network/account.
2. Workspace/document/tree/block workflow завершён.
3. Только `locald` открывает Isar.
4. Durable acknowledgement переживает forced restart.
5. Migrations и restore доказаны fixtures.
6. Search, attachments, import/export и recycle доступны offline.
7. MCP/CLI используют scopes, audit и command idempotency.
8. Operation Log атомарен с mutation.
9. Benchmark targets доказаны.
10. Threat-case suite проходит.
11. Installer/version manifest/diagnostics готовы.
12. License/notices утверждены.
13. Нет обязательных cloud calls или hard-coded credentials.
14. Release test matrix зелёная.
