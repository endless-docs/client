---
title: Client open architecture decisions
status: proposed
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0002
  - ADR-0003
---

# Client open architecture decisions

Эти решения намеренно не подменяются догадками. Каждое должно получить
зафиксированное evidence и выбранный option до указанного gate.

## D1 — Initial desktop platform matrix

Status: open

Decision required before: C0 completion

Options:

1. Windows first, затем macOS/Linux.
2. Windows/macOS/Linux одновременно.

Evidence:

- `locald` process/IPC spike;
- Isar support;
- packaging/signing effort;
- keyboard/accessibility behavior;
- CI runner availability.

Implementation evidence collected:

- Windows x64 Flutter release bundle builds successfully in the current
  toolchain;
- packaged UI, CLI and `locald` binaries are produced together;
- macOS/Linux parity and CI availability remain unverified.

## D2 — Public client license

Status: open

Decision required before: C0 completion

Options:

1. Permissive open-source license.
2. Copyleft open-source license.
3. Source-available model, если пользователь явно изменит требование
   публичного клиента.

Evidence:

- product intent;
- dependency licenses;
- contribution/distribution model;
- bundled asset licenses.

## D3 — `locald` runtime

Status: open

Decision required before: C0 completion

Options:

1. Pure Dart native executable.
2. Flutter engine-backed auxiliary executable.

Evidence:

- real Isar CRUD/migration in headless process on target platforms;
- binary size/startup/memory;
- packaging and process lifecycle;
- test/tooling support.

Boundary that cannot change: `locald` remains the single storage owner.

Implementation evidence collected:

- pure Dart `locald.exe` opens bundled Isar Core without runtime download;
- Isar close/reopen and forced process restart preserve committed records;
- current result supports option 1 on Windows x64, but other accepted platforms
  remain unverified.

## D4 — Local API transport and encoding

Status: open

Decision required before: C0 completion

Options:

1. Unix domain socket / Windows named pipe with framed versioned messages.
2. Platform sockets with code-generated RPC.
3. Authenticated loopback HTTP/gRPC as reviewed fallback.

Evidence:

- Flutter/Dart platform support;
- peer/session authentication;
- streaming/backpressure;
- startup/discovery;
- generated code and compatibility;
- attack surface.

Implementation evidence collected:

- a transport-neutral typed client is exercised over authenticated loopback
  HTTP for the vertical slice;
- endpoint binds only `127.0.0.1`, enforces a bounded request and direct proxy
  bypass;
- this is fallback evidence, not an accepted replacement for the pending
  named-pipe/platform-socket threat review.

## D5 — Initial block types

Status: open

Decision required before: C0 completion

Options:

1. Paragraph, heading, list, code, quote.
2. Option 1 plus table and callout.

Evidence:

- editor complexity;
- import/export round trip;
- accessibility;
- operation granularity.

## D6 — Search implementation

Status: open

Decision required before: C2 completion

Options:

1. Isar-native indexed/tokenized projection.
2. Separate embedded search adapter driven by durable projection events.

Evidence:

- 10k/100k benchmark;
- language/tokenization requirements;
- index rebuild behavior;
- package/platform support.

Current baseline: application-owned search ports are implemented with an Isar
projection updated in the authoritative transaction. Rebuild and cold-restart
correctness are verified, but the adapter currently performs normalized
substring matching. This does not select option 1 until the required dataset,
tokenization and latency evidence exists.

## D7 — Attachment persistence

Status: open

Decision required before: C2 completion

Options:

1. Content-addressed managed filesystem with staging journal.
2. Hybrid small blobs in Isar and large files in filesystem.

Evidence:

- crash atomicity;
- memory/performance;
- backup/export behavior;
- filesystem security.

Preferred baseline is option 1 unless evidence proves a hybrid is necessary.

Implementation evidence collected:

- the isolated `local_attachments` adapter writes a bounded stream to an opaque
  staging token and calculates SHA-256 without buffering the complete payload;
- commit intent/completion journals use flushed temporary files and atomic
  rename; restart recovery completes a move that was interrupted after durable
  intent, while cleanup preserves pending commits;
- final paths are derived only from the content hash, and identical bytes
  deduplicate;
- the Windows test corpus rejects traversal, overlapping roots, a real
  symbolic-link content prefix, staged/committed tampering and malformed
  journals.
- authoritative attachment metadata, recovery marker, Operation Log, command
  outcome and event sequence commit in one real Isar transaction; schema-v2 is
  retained as the pre-attachment upgrade fixture;
- process tests interrupt orchestration after metadata commit and after content
  commit; cold startup completes both states before readiness;
- the typed Local API streams a payload larger than the JSON request limit,
  deduplicates equal content, downloads it after cold reopen, and is exercised
  by Flutter widget, CLI and packaged-smoke flows.

This evidence supports option 1 as the current implementation baseline, but D7
remains open until attachment-aware backup/export, safe unreferenced-content GC
and representative size/performance evidence are implemented.

## D8 — MCP pairing and approval

Status: open

Decision required before: C6 completion

Options:

1. Per-client pairing code.
2. OS user identity plus explicit Flutter approval.
3. Both mechanisms.

Evidence:

- supported MCP launch modes;
- headless usability;
- threat tests;
- revocation and audit UX.

## Decision record

После выбора:

1. Update этого документа со status/decision/evidence.
2. Если решение меняет system boundary, запросить ADR в `architecture`.
3. Обновить affected client documents/tests.
4. Commit и push как отдельную завершённую task.
