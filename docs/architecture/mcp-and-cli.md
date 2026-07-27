---
title: MCP and CLI architecture
status: accepted
owners:
  - client-team
last_reviewed: 2026-07-27
system_adrs:
  - ADR-0001
  - ADR-0003
  - ADR-0007
---

# MCP and CLI architecture

## Общая граница

MCP server и CLI — независимые Local API clients. Они не связываются с Isar,
domain packages или `locald` internals и продолжают работать при закрытом Flutter
UI.

Canonical sequence: `docs/architecture/diagrams/mcp-command.mmd`.

## MCP server

### Resources

- workspace list/metadata;
- document tree;
- document content projection;
- search results;
- Local API health/version.

### Tools

- create/rename/move document;
- apply versioned block changes;
- search;
- import/export;
- delete/restore с confirmation policy.

Точный MCP schema принадлежит `endless-docs/contracts`. Этот документ фиксирует
behavior и security requirements.

### Scopes

Минимальные scopes:

- `workspace:list`;
- `document:read`;
- `document:write`;
- `document:delete`;
- `search:read`;
- `import:write`;
- `export:read`;
- `diagnostics:read`.

Grant ограничивается workspace set, MCP client identity и сроком действия.
Destructive tool может требовать interactive approval в Flutter UI.

### Invocation

Mutating MCP invocation создаёт stable `command_id`, который сохраняется при
transport retry. MCP result возвращает domain revision и safe errors. MCP audit
фиксирует client, tool, scopes, target IDs, approval и outcome без document body.

## CLI

CLI предназначен для automation, diagnostics и headless workflows.

Initial command groups:

```text
endless health
endless workspace list|create|rename
endless document list|get|create|rename|move|delete|restore
endless search
endless import validate|run
endless export
endless backup create|restore
endless diagnostics export
```

CLI stdout имеет human-readable default и explicit machine-readable mode.
Errors имеют stable exit codes; secrets не передаются через command-line
arguments.

## Daemon discovery

MCP/CLI используют shared launcher/discovery package:

1. выбрать profile;
2. найти и authenticate endpoint;
3. при разрешённом режиме запустить bundled `locald`;
4. выполнить handshake/version check;
5. подключиться или вернуть actionable stable error.

Ни MCP, ни CLI не запускают второй `locald` в обход process lock.

## Backpressure and limits

- bounded request and response sizes;
- pagination для lists/search;
- streaming для import/export/attachments;
- per-session concurrency limits;
- cancellation and deadlines;
- rate limits для expensive MCP tools;
- no content in default audit/debug logs.

## Testing

- UI закрыт, MCP/CLI работают;
- unauthorized MCP client denied;
- scope and workspace isolation;
- destructive confirmation;
- duplicate mutation retry;
- daemon restart/reconnect;
- contract version mismatch;
- machine-readable CLI output stability;
- large stream cancellation and cleanup.
