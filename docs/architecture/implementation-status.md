---
title: Client implementation status
status: active
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

# Client implementation status

## Verified vertical slice

Текущая реализация доказывает следующий offline flow:

```text
Flutter UI / CLI
  -> direct loopback Local API client
  -> authenticated locald endpoint
  -> application command pipeline
  -> Isar transaction
       workspace/document/block records
       command outcome
       Operation Log
       event sequence
       rebuildable search projection + indexed sequence
```

Подтверждённые свойства:

- Flutter UI не импортирует domain, application или Isar packages;
- pure Dart `locald` является единственной composition root для Isar;
- endpoint слушает только `127.0.0.1`, требует session proof и ограничивает
  request size;
- Local API client принудительно использует direct loopback и не передаёт
  session proof через настроенный HTTP proxy;
- duplicate `command_id` возвращает сохранённый outcome, а reuse с другим
  fingerprint отклоняется;
- workspace/document mutation и Operation Log находятся в одной Isar
  transaction;
- document revision conflict не оставляет partial state;
- pending editor state flushes before navigation, а availability retry сохраняет
  исходный `command_id`;
- desktop exit request flushes pending editor state и отменяет закрытие при
  ошибке durable commit;
- workspace rename/archive/read-only restore/delete lifecycle использует ту же
  command pipeline; delete атомарно tombstone-ит документы и очищает search;
- document tree move и subtree delete/recycle/ordered restore проходят через тот
  же application pipeline;
- search projection обновляется в domain transaction, исключает tombstones,
  возвращает indexed sequence и перестраивается из authoritative documents;
- real schema v1 fixture открывается schema v2 adapter без потери blocks;
  legacy sentinel нормализуется, а search repair завершается до readiness;
- deterministic real-Isar fault matrix откатывает document, block, projection,
  sequence, Operation и CommandOutcome writes и допускает safe same-ID retry;
- isolated attachment filesystem adapter принимает bounded stream, вычисляет
  SHA-256, атомарно ведёт staging/commit journals, deduplicate-ит content и
  восстанавливает interrupted move без caller-provided final path;
- release bundle содержит Flutter UI, CLI, `locald` и native Isar library;
- packaged CLI создаёт и читает данные после forced `locald` restart при
  недоступном внешнем proxy.

## Reproducible verification

Полная локальная проверка:

```powershell
.\tool\verify.ps1
```

Она запускает format check, `flutter analyze`, import-boundary checker, domain,
application, Local API, attachment filesystem, runtime, real Isar, `locald`
HTTP и Flutter widget tests.

Сборка self-contained Windows bundle:

```powershell
.\tool\build_windows.ps1
.\tool\smoke_windows.ps1
```

Bundle появляется в `dist/endless-windows-x64`. Isar native library загружается
только как build input и включается рядом с `locald.exe`; runtime download
отсутствует. Smoke блокирует внешний proxy, создаёт данные packaged CLI,
проверяет workspace lifecycle, принудительно завершает bundled `locald` и
проверяет чтение и local search после cold restart, затем выполняет search
rebuild.

## Acceptance evidence

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Start without network/account | Packaged UI/CLI bootstrap uses bundled `locald` and Isar; no identity code | Proven for Windows vertical slice |
| Workspace/document workflow | Widget + application + `locald` integration tests | Proven for workspace rename/archive/restore/delete and document create/read/edit/move/subtree delete/restore |
| Only `locald` opens Isar | Import checker and package graph | Proven |
| Durable acknowledgement | Isar close/reopen and packaged forced-restart smoke | Proven for implemented mutations |
| Command idempotency | Application and `locald` replay tests | Proven |
| Operation atomicity | Real Isar fault injection at document/block/projection/sequence/operation/outcome writes plus durable retry after reopen | Proven for injected exceptions; process-kill-during-commit evidence pending |
| Offline editor recovery | Autosave, flush-before-navigation, exit-request flush and same-ID reconnect tests | Partial: long disconnect/event subscription pending |
| Rebuildable local search | Application update/delete/restore/rebuild tests, real Isar/locald post-upgrade repair and cold-reopen tests, widget result UX and packaged smoke | Proven for correctness; 10k/100k benchmark and D6 decision pending |
| Managed attachment bytes | Bounded streaming/SHA-256, deduplication, interrupted-commit recovery, tamper/traversal and real symlink-prefix adapter tests | Foundation proven; metadata transaction, Local API/UI, backup/export and D7 decision pending |
| Release build | Windows release bundle build script | Proven; installer/signing not implemented |

## Known gaps

Полная Client MVP пока не достигнута. Обязательные следующие work packages:

1. Multi-block editor после решения D5.
2. Attachment metadata transaction, Local API/UI and backup/export integration
   поверх проверенного managed-filesystem adapter.
3. Versioned import/export и backup/restore с clean-profile round trip.
4. MCP adapter, scopes, approval и audit.
5. Event subscription/reconnect и multi-client concurrency.
6. Disk-full/permission and process-kill-during-commit matrix; add a versioned
   fixture for every future schema.
7. Search 10k/100k benchmark, решение D6 и long offline soak.
8. Installer, signing policy, diagnostics, SBOM, license/notices и clean-machine
   release matrix.

Открытые product/architecture decisions в
[open decisions](open-decisions.md) остаются gates для полного C0/C8.
