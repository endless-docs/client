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
       attachment metadata + filesystem commit marker
  -> managed SHA-256 attachment filesystem
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
- real schema v1 fixture открывается current adapter без потери blocks; legacy
  sentinel нормализуется, а search repair завершается до readiness;
- real schema v2 fixture открывается attachment-capable schema v3 с пустыми
  metadata/marker collections и без изменения существующих records;
- deterministic real-Isar fault matrix откатывает document, block, projection,
  sequence, Operation и CommandOutcome writes и допускает safe same-ID retry;
- isolated attachment filesystem adapter принимает bounded stream, вычисляет
  SHA-256, атомарно ведёт staging/commit journals, deduplicate-ит content и
  восстанавливает interrupted move без caller-provided final path;
- attachment metadata/marker/Operation/outcome/sequence атомарны в Isar;
  pending metadata скрыта, а startup repair проверен после metadata commit и
  после content commit; Flutter UI и CLI используют тот же Local API flow;
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
проверяет workspace lifecycle и managed attachment upload, принудительно
завершает bundled `locald`, проверяет document/search/attachment download после
cold restart, затем выполняет search rebuild.

## Acceptance evidence

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Start without network/account | Packaged UI/CLI bootstrap uses bundled `locald` and Isar; no identity code | Proven for Windows vertical slice |
| Workspace/document workflow | Widget + application + `locald` integration tests | Proven for workspace rename/archive/restore/delete and document create/read/edit/move/subtree delete/restore |
| Only `locald` opens Isar | Import checker and package graph | Proven |
| Durable acknowledgement | Isar close/reopen and packaged forced-restart smoke | Proven for implemented mutations |
| Command idempotency | Application and `locald` replay tests | Proven |
| Operation atomicity | Real Isar fault injection at document/block/attachment marker/projection/sequence/operation/outcome writes plus durable retry after reopen | Proven for injected exceptions; process-kill-during-Isar-commit evidence pending |
| Offline editor recovery | Autosave, flush-before-navigation, exit-request flush and same-ID reconnect tests | Partial: long disconnect/event subscription pending |
| Rebuildable local search | Application update/delete/restore/rebuild tests, real Isar/locald post-upgrade repair and cold-reopen tests, widget result UX and packaged smoke | Proven for correctness; 10k/100k benchmark and D6 decision pending |
| Managed attachments | Bounded streaming/SHA-256, authoritative Isar metadata/marker transaction, two process interruption points, dedup/download/cold reopen, tamper/traversal/symlink corpus, Flutter/CLI UX and packaged smoke | End-to-end offline flow proven; backup/export, reference-safe GC, performance evidence and D7 decision pending |
| Release build | Windows release bundle build script | Proven; installer/signing not implemented |

## Known gaps

Полная Client MVP пока не достигнута. Обязательные следующие work packages:

1. Multi-block editor после решения D5.
2. Versioned import/export и backup/restore с attachment round trip; добавить
   reference-safe cleanup unreferenced content.
3. MCP adapter, scopes, approval и audit.
4. Event subscription/reconnect и multi-client concurrency.
5. Disk-full/permission and process-kill-during-commit matrix; add a versioned
   fixture for every future schema.
6. Search 10k/100k benchmark, решение D6 и long offline soak.
7. Installer, signing policy, diagnostics, SBOM, license/notices и clean-machine
   release matrix.

Открытые product/architecture decisions в
[open decisions](open-decisions.md) остаются gates для полного C0/C8.
