---
title: Client quality and testing architecture
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

# Client quality and testing architecture

## Reliability invariants

- Confirmed change survives UI and `locald` restart.
- Rolled-back transaction leaves no partial domain/operation state.
- Repeated command does not duplicate effect.
- Interrupted migration resumes or restores safely.
- Attachment staging converges to committed or cleaned state.
- Search projection can be rebuilt from authoritative data.
- Offline duration does not disable local workflows.
- MCP works with Flutter UI closed.

## Performance targets

Reference dataset: 10 000 documents / 100 000 blocks on documented reference
desktop hardware.

| Scenario | Target |
| --- | --- |
| `locald` ready without migration | p95 ≤ 1.0 s |
| Open existing document query | p95 ≤ 100 ms |
| Create/rename/move durable command | p95 ≤ 150 ms |
| Search first page | p95 ≤ 250 ms |
| Typing interaction | No blocking on storage transaction |
| Performance regression | ≤ 10% without reviewed justification |

Выбор Isar не считается доказательством targets. Каждый report фиксирует
release mode, platform, hardware, dataset version, cold/warm state и p50/p95/p99.

## Test layers

### Domain unit tests

Pure Dart, без Flutter/Isar:

- workspace/document/block invariants;
- tree cycle prevention;
- revision conflicts;
- operation construction;
- tombstone/restore;
- command fingerprint rules.

### Application tests

In-memory ports:

- command/query orchestration;
- transaction outcome semantics;
- error mapping;
- authorization/scope policy;
- projection event creation.

### Persistence integration tests

Real Isar and filesystem:

- indexes/mappers;
- atomic command + outcome + operation;
- migration fixtures;
- crash recovery markers;
- backup/restore;
- attachment paths;
- single-owner lock.

### Attachment filesystem adapter tests

- bounded chunked input and partial cleanup on quota failure;
- SHA-256 content addressing, deduplication and idempotent token replay;
- restart recovery after durable commit intent;
- staged and committed byte tampering;
- traversal, invalid token/hash, overlapping-root and real symlink-prefix
  rejection;
- malformed journal isolation and abandoned-state cleanup.

### Local API contract tests

- handshake/version negotiation;
- serialization and unknown fields;
- stable error codes;
- retry with same `command_id`;
- pagination/event resume;
- size/deadline/cancellation;
- unauthorized callers.

### Process integration tests

Real UI client or test harness + real `locald` process:

- discovery/startup/shutdown;
- process crash/reconnect;
- incompatible component versions;
- concurrent UI/MCP/CLI calls;
- profile separation.

### Flutter tests

- widget behavior and state transitions;
- golden rendering for supported themes/sizes;
- keyboard navigation;
- accessibility semantics;
- autosave pending/error/recovery states;
- localization-ready UI strings.

### MCP/CLI tests

- headless operation;
- scopes/confirmation/audit;
- output/exit code stability;
- duplicate retry;
- large stream cleanup.

### Fault injection

Обязательные injection points:

- before transaction;
- during Isar writes;
- after commit before response;
- attachment staging/move;
- migration step;
- disk full/permission denied;
- event stream disconnect;
- process kill.

## Static architecture checks

CI должна проверять:

- forbidden package imports;
- Isar dependency location;
- no machine-readable contract source copies;
- Conventional Commits where history is evaluated;
- Markdown and Mermaid syntax;
- dependency/license policy;
- generated code reproducibility.

## Definition of Done for a feature

Feature завершена только если:

1. UI/MCP/CLI behavior использует одну application path.
2. Durable and retry semantics определены.
3. Error/recovery UX реализован.
4. Unit и real-adapter integration tests проходят.
5. Security scope и audit определены.
6. Performance impact измерен, если затронут hot path.
7. Architecture documents обновлены при изменении boundaries.
