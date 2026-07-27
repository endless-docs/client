---
title: Client security architecture
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0003
---

# Client security architecture

## Assets

- document and workspace content;
- attachment bytes and metadata;
- Isar database and backups;
- Local API session material;
- MCP grants and approvals;
- import/export packages;
- diagnostics and audit records;
- installed binaries and version manifest.

## Trust boundaries

1. Flutter UI → Local API.
2. External MCP client → MCP server.
3. MCP server / CLI → Local API.
4. `locald` → Isar/filesystem/keyring.
5. Installer/update artifact → executable installation.
6. Flutter UI → local Codex app-server → OpenAI service, только после explicit
   disclosure пользователя.

## Threats and required controls

| Threat | Required controls | Required evidence |
| --- | --- | --- |
| Malicious local process calls `locald` | User-only endpoint, session proof, peer checks, bounded requests | Unauthorized caller integration test |
| MCP client reads another workspace | Explicit grants and workspace scope on every call | Cross-workspace denial tests |
| MCP performs destructive action silently | Destructive scope and confirmation policy | Approval/denial tests |
| Path traversal or symlink escapes attachment root | Canonical path validation, no caller final path, safe open/move | Traversal/symlink corpus |
| Duplicate command repeats mutation | Transactional `command_id` outcome | Retry/fault-injection tests |
| UI spoofs durable save | Success only after Isar commit | Kill around commit tests |
| Import exhausts memory/disk or injects unsafe paths | Streaming, quotas, safe parser, staging | Malformed/large archive tests |
| Logs or diagnostics leak content/secrets | Structured redaction, category preview, bounded logs | Redaction corpus |
| Modified binaries mix incompatible components | Signed/versioned manifest and handshake | Tampered/mismatch tests |
| Backup substitution/corruption | Integrity manifest and staging restore | Corrupted backup tests |

## Local API protection

- Endpoint недоступен external network interface.
- Filesystem/pipe permissions ограничивают текущего OS user.
- Session secret не передаётся через process arguments или logs.
- Handshake проверяет version, profile и caller type.
- Request имеет maximum size, deadline и concurrency budget.
- `locald` повторно проверяет workspace ownership; caller ID не является
  достаточным разрешением.

## Secret storage

Client MVP не требует cloud credentials. Local API session material хранится в
memory/protected runtime files с коротким lifecycle.

Optional AI не читает и не хранит Codex credentials: app-server использует
существующую локальную авторизацию. Endless передаёт только тип, заголовок,
текст текущего документа и пользовательскую команду; IDs, другие документы,
поиск и вложения не передаются. AI threads ephemeral, transcript хранится
только в памяти UI.

Будущие refresh/device credentials должны храниться в OS secure storage и не
попадать в Isar, Operation Log, backup или diagnostics.

## Data at rest

Profile directories получают user-only permissions. Application-level workspace
encryption не считается принятой до отдельного решения. Продукт не должен
обещать защиту от process с полным доступом к OS user session без дополнительного
encryption design.

## Attachment filesystem controls

`local_attachments` реализует filesystem foundation отдельно от application
metadata:

- caller задаёт только display file name и stream, но не final path;
- opaque staging tokens и hash-derived final paths проходят canonical-root
  containment checks;
- traversal/absolute names, overlapping roots, symbolic-link content prefixes
  и link targets отклоняются;
- bytes проверяются по size/SHA-256 до commit и перед чтением;
- journals публикуются через flushed temporary + atomic rename, а повреждённый
  journal изолируется как recovery warning.

Эти controls проверены adapter corpus, включая реальный Windows symlink.
Authenticated Local API integration дополнительно проверяет bounded stream,
authoritative metadata marker, download after cold reopen и отсутствие
caller-provided paths в persisted metadata. Attachment-aware backup/export,
reference-safe GC и performance gate остаются открыты.

## Audit

Security-relevant audit:

- MCP grant/revoke and invocation outcome;
- destructive confirmation;
- repeated unauthorized Local API caller;
- import/export/backup/restore;
- profile migration/recovery;
- integrity or version failure.

Audit содержит actor/caller type, target IDs, stable action, result, correlation
и timestamp, но не document bodies, tokens или attachment bytes.

## Secure failure modes

- Unknown API/policy version → deny writes.
- Keyring/session unavailable → actionable authentication error.
- Integrity failure → guarded recovery/read-only mode.
- Disk full → no durable success.
- Log failure → bounded fallback without exposing content.
- MCP approval channel unavailable → destructive action denied.

## Release security gate

Public release блокируется до доказательства threat cases, dependency/license
audit, SBOM, secret scan, signed artifact policy и clean-machine endpoint tests.
