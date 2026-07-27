---
title: Client data flow
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0003
  - ADR-0004
---

# Client data flow

## Local write

```text
Flutter UI / MCP / CLI
  -> Local API authentication and scope
  -> command deserialization and validation
  -> application command handler
  -> domain transition
  -> Isar transaction
       aggregate records
       command outcome
       Operation Log
       projection/recovery markers
       event sequence
  -> commit
  -> Local API result
  -> asynchronous committed event
```

Caller получает `saved locally` только после commit. Network отсутствует в этом
flow.

Canonical sequence:
`docs/architecture/diagrams/local-command.mmd`.

## Local read

```text
Caller
  -> authenticated Local API query
  -> application query handler
  -> persistence/search port
  -> bounded DTO projection
  -> response with observed revision/event sequence
```

Query handler не возвращает Isar records или filesystem paths.

## Editor autosave

1. UI поддерживает transient editing state.
2. Debounce/coalescing уменьшает transport chatter, но не меняет semantics.
3. Каждый отправленный batch получает новый `command_id`.
4. UI хранит pending state до durable response.
5. `RevisionConflict` вызывает reread/merge UX, а не blind overwrite.
6. После reconnect UI повторяет неизвестный outcome с прежним `command_id`.

## Attachment write

1. Stream попадает в staging через Local API.
2. `locald` проверяет size/type policy и hash.
3. Metadata command проходит domain rules.
4. Journal связывает Isar metadata и filesystem move.
5. Crash recovery приводит состояние к `committed` или удаляет abandoned staging.

## Search update

Search projection обновляется в основной transaction или из durable projection
event. UI видит `indexed_sequence` и не предполагает мгновенную consistency, если
выбран отдельный engine.

## Import

```text
external file
  -> safe parser in staging
  -> validation report
  -> normalized domain commands
  -> bounded transactions
  -> final import outcome
```

Invalid import не изменяет active state частично. Большой import может быть
несколькими resumable transactions с явным import journal.

## Export

Export читает consistent snapshot и создаёт portable package:

- version manifest;
- workspaces/documents/blocks;
- attachment manifest and bytes;
- integrity hashes;
- warnings for unsupported content.

Export не содержит raw Isar file, Local API session secrets или diagnostic logs.

## Event delivery

Events отправляются после commit и могут быть доставлены повторно. Subscriber
deduplicates по local sequence. Потеря transient connection восстанавливается с
последней применённой sequence.
