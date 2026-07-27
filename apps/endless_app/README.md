# Endless app

Flutter desktop presentation layer for Endless Docs. It talks only to
`local_api_client`; it does not import Isar or application internals.

From the application directory, run:

```powershell
flutter run -d windows
```

The app discovers or starts `locald` and remains usable without a cloud server.
Document navigation flushes pending edits before switching; tree, recycle and
restore operations use the same Local API boundary.
