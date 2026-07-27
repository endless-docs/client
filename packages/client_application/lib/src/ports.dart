import 'dart:async';

import 'package:client_domain/client_domain.dart';

import 'attachments.dart';
import 'search.dart';

abstract interface class Clock {
  DateTime now();
}

abstract interface class IdGenerator {
  String nextId();
}

abstract interface class ClientStore {
  Future<T> read<T>(FutureOr<T> Function(ClientStoreReader reader) operation);

  Future<T> write<T>(FutureOr<T> Function(ClientStoreWriter writer) operation);
}

abstract interface class ClientStoreReader {
  Future<Workspace?> getWorkspace(String workspaceId);

  Future<List<Workspace>> listWorkspaces({bool includeArchived = false});

  Future<Document?> getDocument(String documentId);

  Future<List<Document>> listDocuments(
    String workspaceId, {
    bool includeDeleted = false,
  });

  Future<Attachment?> getAttachment(String attachmentId);

  Future<List<Attachment>> listAttachments(
    String documentId, {
    bool includeDeleted = false,
  });

  Future<AttachmentCommitMarker?> getAttachmentCommitMarker(
    String attachmentId,
  );

  Future<List<AttachmentCommitMarker>> listPendingAttachmentCommits();

  Future<CommandOutcome?> getCommandOutcome(String commandId);

  Future<List<SearchHit>> searchDocuments(
    String workspaceId,
    String query, {
    required int limit,
  });

  Future<SearchStatus> getSearchStatus();

  Future<int> currentEventSequence();
}

abstract interface class ClientStoreWriter implements ClientStoreReader {
  Future<void> putWorkspace(Workspace workspace);

  Future<void> putDocument(Document document);

  Future<void> putAttachment(Attachment attachment);

  Future<void> putAttachmentCommitMarker(AttachmentCommitMarker marker);

  Future<void> removeAttachmentCommitMarker(String attachmentId);

  Future<void> putSearchProjection(SearchProjection projection);

  Future<void> removeSearchProjection(String documentId);

  Future<void> replaceSearchProjections(List<SearchProjection> projections);

  Future<void> setSearchIndexedSequence(int sequence);

  Future<int> nextEventSequence();

  Future<void> putCommandOutcome(CommandOutcome outcome);

  Future<void> appendOperation(Operation operation);
}
