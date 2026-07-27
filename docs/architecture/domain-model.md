---
title: Client domain model
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0004
---

# Client domain model

## Workspace

`Workspace` — верхняя граница владения local data.

Основные поля:

- stable `workspace_id`;
- name and settings;
- `kind=local` в Client MVP;
- lifecycle `active|archived|deleted`;
- current revision;
- created/updated timestamps.

Инварианты:

- local workspace не требует account;
- document и attachment принадлежат ровно одному workspace;
- cross-workspace parent/reference запрещён без explicit import/copy command;
- удаление workspace не выполняется неявно.

## Document

`Document` содержит stable ID, workspace ID, title, document type, tree
position, ordered blocks, revision и deletion state. `document_type` принимает
`plain|adr|business_need|rfc`; отсутствующее значение прежних schema
нормализуется в `plain`.

Инварианты:

- document tree не содержит cycles;
- parent находится в том же workspace;
- ID не переиспользуется после deletion;
- update проверяет expected revision, если caller её передал;
- delete создаёт tombstone и recoverable recycle entry.

## Block

`Block` — минимальная адресуемая единица content:

- stable `block_id`;
- owning `document_id`;
- block type;
- versioned payload;
- ordering/parent relation;
- block revision.

Минимальный набор block types принимается в Phase 0. Неизвестный versioned block
сохраняется без потери payload и отображается как unsupported, а не удаляется.

## Revision

Revision — domain version после принятой mutation. Она не равна wall-clock time и
не обязана совпадать с Isar transaction ID.

Revision используется для optimistic concurrency, UI projection freshness и
operation base version.

## Command outcome

`CommandOutcome` связывает `command_id` с method, request fingerprint, result
revision/error и commit sequence.

Повтор с тем же ID и другим fingerprint возвращает `CommandIdReused`, а не
применяет новую mutation.

## Operation

Каждая принятая mutation создаёт logical `Operation`:

- global `operation_id`;
- `workspace_id`, object ID и local device/installation ID;
- monotonic local sequence;
- operation type и format version;
- base/result revision;
- versioned payload;
- local delivery state.

Operation описывает domain change, а не Isar diff. В Client MVP она остаётся
локальной; future Sync сможет читать только опубликованный versioned format.

## Tombstone

Tombstone хранит identity удалённого объекта, deletion operation/revision и
retention metadata. Restore создаёт новую operation. Physical purge отделён от
user delete.

## Attachment

`Attachment` содержит stable ID, workspace/document IDs, display file name,
content hash, size, media metadata, revision и deletion state. Локальная
готовность bytes представлена application recovery marker и не смешивается с
logical attachment revision.

Binary bytes не входят в document operation payload. Link/unlink и binary
lifecycle имеют отдельные commands. Logical delete не удаляет hash object
немедленно: один content object может иметь несколько metadata references.

## Domain services

Cross-aggregate rules реализуются domain/application services:

- document tree validation;
- workspace deletion planning;
- import normalization;
- attachment reference integrity;
- operation construction;
- recycle/restore policy.

UI state managers, Isar query objects и transport handlers не содержат
authoritative domain rules.
