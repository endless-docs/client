# locald

The single local application and Isar owner process. It exposes the versioned,
session-protected Local API on a loopback-only endpoint.

`locald` is also the sole owner of managed attachment bytes. It streams bounded
uploads, commits authoritative metadata plus a recovery marker in Isar, moves
content by SHA-256, and repairs interrupted marker states before readiness.

It also creates authenticated, versioned streaming backups from a consistent
application snapshot. Restore accepts only a clean profile, validates the
archive and every attachment hash before publishing restored metadata in one
Isar transaction, and rebuilds the disposable search projection.
