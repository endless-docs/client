---
title: AI document editing
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-28
---

# AI document editing

## Boundary

AI — optional online capability Flutter UI. Обычный редактор, `locald`, Isar,
CLI, backup и search продолжают работать без Codex, сети и account.

```text
Current document snapshot
  -> Flutter AI controller
  -> codex app-server over stdio JSONL
  -> structured ask | replace_document | no_change
  -> expected-revision Local API command
  -> locald durable transaction
```

Codex не получает Local API или MCP tools и не изменяет Isar напрямую.
Production использует установленный `codex.exe`; `ENDLESS_CODEX_PATH`
разрешён для development и tests. Модель не фиксируется и берётся из локальной
Codex configuration.

## Session and prompt

На текущий документ создаётся ephemeral thread. При навигации thread и
in-memory transcript сбрасываются. Передаются только `document_type`, title,
Markdown body и текущая команда.

Поддерживаются:

- `adr`: Status, Context, Decision, Alternatives, Consequences;
- `business_need`: Problem, Audience, Desired outcome, Value, Constraints,
  Success criteria;
- `rfc`: Status, Summary, Motivation, Proposal, Alternatives, Risks, Rollout.

App-server запускается со strict config, когда CLI поддерживает этот флаг.
Актуальные версии без флага получают эквивалентный закрытый набор явных config
overrides. В обоих случаях отключены web search, shell, MCP, plugins, apps и
multi-agent tools. Turn использует read-only sandbox, no command network и
`approvalPolicy=never`.

## Mutation safety

UI flush-ит ручной текст до AI turn и сохраняет revision snapshot. После ответа
он повторно flush-ит editor. `replace_document` применяется только когда
document ID, type и revision не изменились. Commit использует
`ApplyBlockChanges(expected_revision=...)`; conflict или stale snapshot не
меняют документ.

Предыдущий title/body хранится в памяти до следующей правки и может быть
восстановлен новой revision через «Отменить AI-правку». AI transcript, prompts
и responses не входят в Isar, backup, Operation Log или diagnostics.

## Failure modes

Missing CLI, auth required, incompatible protocol, timeout, offline/rate limit,
invalid structured response, oversized context, cancellation и child-process
exit отображаются только в AI-панели. Ни одно из состояний не переводит
offline editor в failed phase.

CI проверяет протокол через fake process transport. Ручной
`tool\smoke_codex_ai.ps1` использует установленный и авторизованный Codex,
отправляет только синтетический ADR и не печатает prompt или response.
