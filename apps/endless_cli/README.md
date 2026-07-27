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

Attachment bytes are streamed through `locald` and stored by SHA-256; caller
paths are never persisted:

```text
endless attachment add DOCUMENT_ID FILE [MEDIA_TYPE]
endless attachment list DOCUMENT_ID
endless attachment get ATTACHMENT_ID
endless attachment delete ATTACHMENT_ID
endless attachment download ATTACHMENT_ID OUTPUT_PATH
```

Versioned backup archives are streamed through `locald`; restore intentionally
requires a clean target profile:

```text
endless backup export OUTPUT_PATH
endless --profile-root EMPTY_PROFILE backup restore INPUT_PATH
```
