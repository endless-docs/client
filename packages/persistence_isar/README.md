# persistence_isar

Isar implementation of application persistence ports. Only the `locald`
composition root may construct this adapter. Document mutations and their local
search projection/checkpoint share one Isar transaction; the projection can be
recreated from authoritative documents. Integration tests retain versioned
legacy schemas and expose deterministic write-step fault injection to prove
transaction rollback and durable retry behavior.

Attachment metadata and filesystem commit markers are separate collections.
They are created atomically with command outcome, Operation Log and event
sequence; marker deletion is independently retryable after verified content
commit. Schema-v2 is retained as a real pre-attachment migration fixture.
