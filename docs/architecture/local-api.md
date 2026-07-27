---
title: Local API architecture
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0003
  - ADR-0007
---

# Local API architecture

## Purpose

Local API — единственная программная граница Flutter UI, MCP, CLI и будущих
local integrations с `locald`.

Документ фиксирует semantics. Machine-readable schema и generated artifacts
должны публиковаться из `endless-docs/contracts`; копия schema в `client`
запрещена.

## Interaction types

- **Command** — mutating request с обязательным `command_id`.
- **Query** — read-only request с pagination/consistency metadata.
- **Event subscription** — ordered committed notifications с resume sequence.
- **Health/lifecycle** — readiness, version handshake и diagnostics.
- **Streaming transfer** — bounded import/export/attachment data.

## Handshake

Первый request каждого connection передаёт:

| Field | Meaning |
| --- | --- |
| `api_version` | Requested Local API major/minor |
| `client_type` | `flutter_ui`, `mcp_server`, `cli`, `integration` |
| `client_version` | Installed component version |
| `profile_id` | Canonical target profile |
| `session_proof` | Protected local session authentication |
| `capabilities` | Supported optional features |

Response содержит selected API version, `locald` version, profile identity,
runtime capabilities, current local event sequence и compatibility decision.

## Command envelope

Semantic envelope:

| Field | Requirement |
| --- | --- |
| `request_id` | Correlation for one transport attempt |
| `command_id` | Stable across retries; deduplication key |
| `api_version` | Versioned semantics |
| `workspace_id` | Explicit authorization/ownership boundary |
| `method` | Stable command name |
| `payload` | Versioned command data |
| `expected_revision` | Optional optimistic concurrency precondition |
| `deadline` | Caller deadline; not a durability guarantee |

`request_id` меняется при retry, `command_id` не меняется. Повтор команды
возвращает сохранённый outcome и не создаёт вторую domain operation.

## Initial API surface

### Runtime

`Handshake`, `Health`, `GetVersionManifest`, `ExportDiagnostics`,
`RequestShutdown`.

### Workspaces

`CreateWorkspace`, `ListWorkspaces`, `GetWorkspace`, `RenameWorkspace`,
`ArchiveWorkspace`, `DeleteWorkspace`.

### Documents

`CreateDocument`, `GetDocument`, `ListDocumentTree`, `RenameDocument`,
`MoveDocument`, `ApplyBlockChanges`, `DeleteDocument`, `RestoreDocument`.

### Search

`SearchDocuments`, `GetSearchStatus`, `RebuildSearchIndex`.

### Attachments

`StageAttachment`, `CommitAttachment`, `OpenAttachment`, `LinkAttachment`,
`UnlinkAttachment`, `DeleteAttachment`.

Текущий typed adapter реализует этот semantic flow как:

- binary `POST /v1/attachments/stage` с bounded body, display name и media type;
- idempotent command `AttachStagedFile`, который связывает opaque staging token
  с document;
- queries `ListAttachments`/`GetAttachment`;
- authenticated streaming content response;
- command `DeleteAttachment`.

Общий JSON request limit и 100 MiB attachment stream limit независимы. Session
proof обязателен для metadata и bytes; caller filesystem paths не передаются.

### Portability

`ValidateImport`, `ExecuteImport`, `CreateExport`, `RestoreBackup`.

Имена являются semantic inventory, а не wire schema.

## Query behavior

- Large collections используют opaque page token и bounded page size.
- Query response объявляет `observed_revision` или local event sequence.
- Search может быть кратковременно eventually consistent; response содержит
  indexed sequence.
- Export читает consistent snapshot.
- Caller cancellation прекращает expensive work, если commit ещё не начался.

## Event stream

Событие содержит local sequence, event type, affected IDs, revision и минимальный
projection hint. Document content не дублируется в event без необходимости.

Subscriber восстанавливается с `after_sequence`. Если history compacted,
`ResubscribeSnapshotRequired` заставляет caller перечитать projections.

## Error model

| Class | Example | Retry |
| --- | --- | --- |
| Validation | `InvalidArgument`, `InvalidParent` | После исправления |
| Not found | `DocumentNotFound` | Нет, если состояние не изменилось |
| Conflict | `RevisionConflict`, `AlreadyExists` | После reread/merge |
| Authorization | `Unauthenticated`, `ScopeDenied` | После approval/session |
| Availability | `LocaldStarting`, `StorageBusy` | Да, с backoff |
| Capacity | `DiskFull`, `AttachmentTooLarge` | После освобождения/изменения |
| Compatibility | `ApiVersionUnsupported` | После upgrade |
| Integrity | `StorageCorrupted`, `HashMismatch` | Recovery workflow |

Каждая ошибка имеет stable `code`, safe user message key, diagnostic correlation,
retry class и optional details. Stack traces не являются public API.

## Transport requirements

- user-local endpoint only;
- peer/session authentication;
- maximum frame and stream sizes;
- cancellation/deadlines;
- backpressure;
- no silent fallback to external network interface;
- no plaintext secret in command line or logs.

## Testing contract

Каждый method имеет:

1. domain/application unit tests;
2. Local API serialization/compatibility tests;
3. real-process integration test;
4. duplicate `command_id` test для mutations;
5. stable error mapping test;
6. unauthorized caller test.
