---
title: Client process topology
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0002
  - ADR-0003
---

# Client process topology

## Processes

| Process | Runtime | Responsibility | Durable data access |
| --- | --- | --- | --- |
| Flutter UI | Flutter/Dart | Presentation, navigation, UI state | Нет |
| `locald` | Dart native или Flutter engine-backed auxiliary process | Domain/application host | Isar + managed files |
| MCP server | Dart executable | MCP tools/resources adapter | Нет |
| CLI | Dart executable | Automation and diagnostics adapter | Нет |

`locald` implementation mode окончательно выбирается после Phase 0 spike:
headless Dart должен доказать совместимость с Isar на выбранных platforms.
Fallback — отдельный Flutter engine-backed executable, но process ownership и
Local API boundary сохраняются.

## Profile topology

Один OS user может иметь один или несколько named profiles. Для каждого active
profile разрешён ровно один `locald`.

```text
Application data root/
  profiles/
    <profile-id>/
      profile.manifest
      database/
      attachments/
      staging/
      backups/
      logs/
      runtime/
```

`profile-id` валидируется и не используется как произвольный filesystem path.
Runtime endpoint и lock могут размещаться в OS runtime directory, но ссылаются
на один canonical profile.

## Startup

1. Caller читает installed version manifest.
2. Shared launcher вычисляет canonical profile root.
3. Launcher ищет защищённый endpoint и выполняет `Handshake`.
4. Если endpoint отсутствует, launcher получает process-start lock и запускает
   bundled `locald`.
5. `locald` получает single-instance lock, проверяет profile manifest, выполняет
   recovery и migrations.
6. `locald` публикует endpoint только после перехода в `ready`.
7. Caller проверяет совместимость Local API и начинает работу.

## Shutdown and crash

- UI exit не завершает `locald`, если подключены MCP/CLI или выполняется command.
- Graceful shutdown прекращает принимать writes, завершает active transactions,
  flushes bounded logs и закрывает Isar.
- После crash новый process проверяет staging journal, migration state и
  attachment recovery markers до публикации `ready`.
- Второй владелец Isar завершает запуск со stable `ProfileAlreadyOwned` error.

## IPC

Предпочтительный topology:

- Unix domain socket на macOS/Linux;
- named pipe на Windows;
- authenticated loopback transport только как fallback после threat review.

Transport обязан поддерживать request/response, server event stream, bounded
message size, cancellation, deadlines и peer/session authentication.

## Packaging

Installer поставляет все processes одной совместимой версией. Произвольное
смешивание UI и `locald` из разных installations запрещено. Version manifest
содержит versions UI, Local API, Isar schema, document format, operation format,
MCP и CLI.

Canonical diagram: `docs/architecture/diagrams/process-topology.mmd`.
