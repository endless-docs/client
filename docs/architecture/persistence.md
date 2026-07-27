---
title: Client persistence architecture
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0002
  - ADR-0003
  - ADR-0004
---

# Client persistence architecture

## Ownership

Isar открывается только process `locald`. Flutter UI, MCP server, CLI и test
fixtures вне persistence package не получают database handle.

Isar является internal storage implementation. Его file, collection names,
generated IDs и generated Dart models не являются Local API, export, backup или
Sync Protocol.

## Logical datasets

Названия ниже описывают ответственность, а не обязательные Isar class names.

| Dataset | Purpose | Authority |
| --- | --- | --- |
| Workspace records | Workspace lifecycle/settings | Authoritative |
| Document records | Metadata/tree/revision/deletion state | Authoritative |
| Block records | Ordered document content | Authoritative |
| Command outcomes | `command_id` deduplication | Authoritative for retry |
| Operation records | Logical changes and delivery state | Authoritative |
| Attachment records | Hash, size, links, file state | Authoritative metadata |
| Search projection | Query-optimized representation | Rebuildable |
| Migration state | Applied/resumable schema steps | Authoritative |
| Runtime checkpoints | Event sequence and recovery markers | Authoritative |

Domain IDs генерируются независимо от Isar internal IDs и сохраняются при
export/import/migration.

## Transaction boundary

Mutating command выполняется так:

1. Проверить session, input и workspace boundary.
2. Найти `command_id` в command outcomes.
3. Загрузить aggregate и проверить expected revision.
4. Рассчитать domain transition и logical operation.
5. В одной Isar write transaction:
   - сохранить aggregate records;
   - сохранить command outcome;
   - append Operation Log record;
   - записать attachment/search recovery marker, если применимо;
   - увеличить local event sequence.
6. После commit опубликовать event.
7. Только после commit вернуть durable success.

Transport disconnect после commit не отменяет command: retry с тем же
`command_id` возвращает сохранённый outcome.

## Search consistency

Если search реализуется Isar indexes, projection изменяется в основной
transaction. Если выбран отдельный search engine, transaction сохраняет
projection event/checkpoint, а worker применяет его идемпотентно. Search response
показывает applied event sequence.

Search projection всегда можно удалить и построить из documents/blocks.

## Attachments

Bytes хранятся в managed filesystem:

1. Caller передаёт stream в bounded staging file.
2. Adapter вычисляет hash/size и fsync policy.
3. Local command фиксирует metadata и recovery marker.
4. File атомарно перемещается в content-addressed location.
5. Marker закрывается; crash recovery завершает или откатывает шаг.

Все resolved paths должны оставаться внутри canonical attachment root. Symlinks,
path traversal и caller-provided final paths запрещены.

Текущий `local_attachments` adapter доказывает bounded streaming, SHA-256
content addressing/deduplication, атомарные intent/completion journals,
interrupted-move recovery, abandoned-staging cleanup и filesystem security
corpus. Он намеренно не фиксирует authoritative metadata: связывание hash с
document/block и recovery marker в Isar остаётся следующим application/
persistence increment.

## Schema versioning

- Isar schema version — monotonic integer.
- Document/operation/Local API versions изменяются независимо.
- Каждая migration имеет fixture предыдущей версии и expected result.
- Migration должна быть resumable или иметь однозначный restore path.
- Destructive migration начинается только после consistent pre-migration backup.
- `locald` не публикует `ready`, пока migration/recovery не завершены.

## Backup and restore

Поддерживаемый backup создаётся через `locald` из consistent state. Копирование
открытого Isar file не является backup.

Restore:

1. Валидирует archive/version/integrity.
2. Восстанавливает в новый staging profile.
3. Запускает migrations и consistency checks.
4. Переключает active profile атомарно.
5. Сохраняет предыдущий profile до подтверждённого запуска.

## Corruption and disk pressure

- `DiskFull` не подтверждает command.
- Corruption переводит profile в guarded recovery/read-only mode.
- Diagnostic export не изменяет damaged data.
- Cleanup удаляет только rebuildable caches и abandoned staging по journal.
- Operation Log и authoritative records не удаляются как автоматическая мера
  освобождения места.

## Required tests

- transaction rollback at every write step;
- duplicate command replay;
- kill process before/during/after commit;
- migration from every released schema fixture;
- disk-full and permission-denied;
- attachment crash-recovery states;
- backup → clean restore round trip;
- search projection rebuild;
- single-owner lock contention.
