# local_attachments

Managed filesystem adapter for attachment bytes. It accepts bounded streams,
stores staging files under a generated opaque token, computes SHA-256 while
writing, and commits to a content-addressed path. Callers never provide a final
filesystem path.

This package owns bytes and recovery journals only. Authoritative attachment
metadata and command orchestration remain application/persistence concerns.

The adapter:

- bounds the input stream without buffering the complete attachment;
- accepts a display file name but never a caller-provided final path;
- hashes bytes while staging and deduplicates them by SHA-256;
- makes commit intent and completion journals durable through atomic rename;
- completes interrupted commits and cleans only abandoned staging state;
- rejects traversal, overlapping roots, symbolic-link prefixes and integrity
  mismatches before returning content.

Run its focused verification from this directory:

```powershell
dart analyze
dart test
```
