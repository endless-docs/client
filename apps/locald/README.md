# locald

The single local application and Isar owner process. It exposes the versioned,
session-protected Local API on a loopback-only endpoint.

`locald` is also the sole owner of managed attachment bytes. It streams bounded
uploads, commits authoritative metadata plus a recovery marker in Isar, moves
content by SHA-256, and repairs interrupted marker states before readiness.
