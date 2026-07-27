final class SearchProjection {
  const SearchProjection({
    required this.documentId,
    required this.workspaceId,
    required this.title,
    required this.content,
    required this.revision,
  });

  final String documentId;
  final String workspaceId;
  final String title;
  final String content;
  final int revision;
}

final class SearchHit {
  const SearchHit({
    required this.documentId,
    required this.workspaceId,
    required this.title,
    required this.snippet,
    required this.score,
    required this.observedRevision,
    required this.indexedSequence,
  });

  final String documentId;
  final String workspaceId;
  final String title;
  final String snippet;
  final int score;
  final int observedRevision;
  final int indexedSequence;

  Map<String, Object?> toJson() => <String, Object?>{
    'document_id': documentId,
    'workspace_id': workspaceId,
    'title': title,
    'snippet': snippet,
    'score': score,
    'observed_revision': observedRevision,
    'indexed_sequence': indexedSequence,
  };
}

final class SearchStatus {
  const SearchStatus({
    required this.eventSequence,
    required this.indexedSequence,
    required this.documentCount,
  });

  final int eventSequence;
  final int indexedSequence;
  final int documentCount;

  bool get isCurrent => eventSequence == indexedSequence;

  Map<String, Object?> toJson() => <String, Object?>{
    'event_sequence': eventSequence,
    'indexed_sequence': indexedSequence,
    'document_count': documentCount,
    'is_current': isCurrent,
  };
}
