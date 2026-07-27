# Endless CLI

Headless Local API client for health, workspace, document, and local search
workflows. Use
`dart run apps/endless_cli/bin/endless_cli.dart` from the repository root.

Search commands:

```text
endless search WORKSPACE_ID QUERY
endless search-index status
endless search-index rebuild
```

Workspace lifecycle commands:

```text
endless workspace rename WORKSPACE_ID NAME
endless workspace archive WORKSPACE_ID
endless workspace restore WORKSPACE_ID
endless workspace delete WORKSPACE_ID
```
