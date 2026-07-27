final class StagedAttachmentDraft {
  const StagedAttachmentDraft({
    required this.stagingToken,
    required this.fileName,
    required this.mediaType,
    required this.sha256,
    required this.size,
  });

  final String stagingToken;
  final String fileName;
  final String mediaType;
  final String sha256;
  final int size;
}

final class AttachmentCommitMarker {
  const AttachmentCommitMarker({
    required this.attachmentId,
    required this.stagingToken,
    required this.sha256,
    required this.size,
    required this.createdAt,
  });

  final String attachmentId;
  final String stagingToken;
  final String sha256;
  final int size;
  final DateTime createdAt;
}
