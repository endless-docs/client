# Local backup

Transport-neutral codec for versioned Endless profile backups.

The archive contains a bounded JSON application snapshot followed by unique
content-addressed attachment streams. The reader stages input, rejects
unsupported versions, malformed references, missing/trailing content, size
mismatches, and SHA-256 mismatches before exposing any restored bytes.

It deliberately contains no Isar, HTTP, profile-path, or Flutter dependency.
`locald` composes the codec with the application snapshot and managed
attachment store.
