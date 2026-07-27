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
- document tree move и subtree delete/recycle/ordered restore проходят через тот
  же application pipeline;
- release bundle содержит Flutter UI, CLI, `locald` и native Isar library;
- packaged CLI создаёт и читает данные после forced `locald` restart при
  недоступном внешнем proxy.

## Reproducible verification

Полная локальная проверка:

```powershell
.\tool\verify.ps1
```

Она запускает format check, `flutter analyze`, import-boundary checker, domain,
application, Local API, runtime, real Isar, `locald` HTTP и Flutter widget tests.

Сборка self-contained Windows bundle:

```powershell
.\tool\build_windows.ps1
.\tool\smoke_windows.ps1
```

Bundle появляется в `dist/endless-windows-x64`. Isar native library загружается
только как build input и включается рядом с `locald.exe`; runtime download
отсутствует. Smoke блокирует внешний proxy, создаёт данные packaged CLI,
принудительно завершает bundled `locald` и проверяет чтение после cold restart.

## Acceptance evidence

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Start without network/account | Packaged UI/CLI bootstrap uses bundled `locald` and Isar; no identity code | Proven for Windows vertical slice |
| Workspace/document workflow | Widget + application + `locald` integration tests | Proven for create/read/edit/move/subtree delete/restore |
| Only `locald` opens Isar | Import checker and package graph | Proven |
| Durable acknowledgement | Isar close/reopen and packaged forced-restart smoke | Proven for implemented mutations |
| Command idempotency | Application and `locald` replay tests | Proven |
| Operation atomicity | Same Isar transaction adapter + rollback/replay tests | Partial: additional write-step fault injection required |
| Offline editor recovery | Autosave, flush-before-navigation and same-ID reconnect tests | Partial: long disconnect/event subscription pending |
| Release build | Windows release bundle build script | Proven; installer/signing not implemented |

## Known gaps

Полная Client MVP пока не достигнута. Обязательные следующие work packages:

1. Complete workspace rename/archive/delete lifecycle, multi-block editor и
   window-close flush.
2. Search projection и rebuild.
3. Managed attachments со staging journal и traversal/symlink corpus.
4. Versioned import/export и backup/restore с clean-profile round trip.
5. MCP adapter, scopes, approval и audit.
6. Event subscription/reconnect и multi-client concurrency.
7. Migration fixtures, disk-full/permission/fault-injection matrix.
8. Benchmark dataset/report и long offline soak.
9. Installer, signing policy, diagnostics, SBOM, license/notices и clean-machine
   release matrix.

Открытые product/architecture decisions в
[open decisions](open-decisions.md) остаются gates для полного C0/C8.
