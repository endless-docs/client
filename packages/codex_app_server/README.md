# codex_app_server

Pure Dart adapter for the optional Endless Docs AI panel. It launches an
installed `codex app-server`, speaks the stable stdio JSONL protocol, and
converts structured turns into document-focused actions.

It does not depend on Flutter, Isar, Local API, MCP, or document persistence.
On Windows, discovery prefers the npm `codex.cmd` launcher before a standalone
`codex.exe`, so a private WindowsApps executable cannot shadow a usable CLI.

Run `tool\smoke_codex_ai.ps1` manually from the repository root to verify an
installed and authenticated Codex against synthetic document content. The
smoke prints only availability, the structured action, and result sizes.
