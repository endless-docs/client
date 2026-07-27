# Endless app

Flutter desktop presentation layer for Endless Docs. It talks only to
`local_api_client`; it does not import Isar or application internals.

From the application directory, run:

```powershell
flutter run -d windows
```

The app discovers or starts `locald` and remains usable without a cloud server.
Document navigation flushes pending edits before switching; tree, recycle and
restore operations use the same Local API boundary. Workspace lifecycle has a
read-only archive mode, and a desktop exit request is cancelled if pending
editor state cannot be committed locally.

The document editor also lists managed attachments. A user can provide a local
source path, download to an explicit target path, or delete the logical
attachment. Source/target paths stay in the UI process and are never persisted
as attachment metadata.
