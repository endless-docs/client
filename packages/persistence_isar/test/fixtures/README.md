# Isar migration fixtures

`schema_v1.dart` is the released schema-v1 shape before the search projection
was introduced. Its generated schema creates a real legacy Isar profile during
the integration test; the current adapter then opens that profile, verifies all
authoritative workspace/document/block data, normalizes legacy field defaults,
and rebuilds search before readiness.

Regenerate `schema_v1.g.dart` with:

```powershell
dart run build_runner build
```

Do not update the v1 shape when the current production schema changes. Add a
new versioned fixture instead.
