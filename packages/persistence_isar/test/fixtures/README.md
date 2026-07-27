# Isar migration fixtures

`schema_v1.dart` is the released shape before search projection/checkpoints.
`schema_v2.dart` is the released shape before authoritative attachment metadata
and filesystem commit markers. Their generated schemas create real legacy Isar
profiles; the current adapter then opens those files and verifies migration.

Regenerate generated fixture schemas with:

```powershell
dart run build_runner build
```

Do not update an existing fixture when the production schema changes. Add a new
versioned fixture instead.
