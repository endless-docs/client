import 'package:local_api/local_api.dart';

final class AttachmentDownload {
  const AttachmentDownload({
    required this.attachmentId,
    required this.fileName,
    required this.mediaType,
    required this.sha256,
    required this.size,
    required this.bytes,
  });

  final String attachmentId;
  final String fileName;
  final String mediaType;
  final String sha256;
  final int size;
  final Stream<List<int>> bytes;
}

abstract interface class EndlessLocalApi {
  Future<JsonMap> handshake({
    required LocalClientType clientType,
    required String profileId,
  });

  Future<JsonMap> health();

  Future<List<JsonMap>> listWorkspaces({bool includeArchived = false});

  Future<JsonMap> getWorkspace(String workspaceId);

  Future<JsonMap> createWorkspace({
    required String commandId,
    required String name,
  });

  Future<JsonMap> renameWorkspace({
    required String commandId,
    required String workspaceId,
    required String name,
    int? expectedRevision,
  });

  Future<JsonMap> archiveWorkspace({
    required String commandId,
    required String workspaceId,
    required bool archived,
    int? expectedRevision,
  });

  Future<JsonMap> deleteWorkspace({
    required String commandId,
    required String workspaceId,
    int? expectedRevision,
  });

  Future<List<JsonMap>> listDocuments({
    required String workspaceId,
    bool includeDeleted = false,
  });

  Future<JsonMap> getDocument(String documentId);

  Future<JsonMap> createDocument({
    required String commandId,
    required String workspaceId,
    required String title,
    String? parentId,
  });

  Future<JsonMap> saveDocument({
    required String commandId,
    required String documentId,
    required String title,
    required List<JsonMap> blocks,
    int? expectedRevision,
  });

  Future<JsonMap> moveDocument({
    required String commandId,
    required String documentId,
    required String? parentId,
    required int position,
    int? expectedRevision,
  });

  Future<JsonMap> deleteDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  });

  Future<JsonMap> restoreDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  });

  Future<JsonMap> stageAttachment({
    required Stream<List<int>> bytes,
    required String fileName,
    required String mediaType,
    int? contentLength,
  });

  Future<JsonMap> attachStagedFile({
    required String commandId,
    required String documentId,
    required String stagingToken,
    int? expectedDocumentRevision,
  });

  Future<List<JsonMap>> listAttachments({
    required String documentId,
    bool includeDeleted = false,
  });

  Future<JsonMap> getAttachment(String attachmentId);

  Future<AttachmentDownload> downloadAttachment(String attachmentId);

  Future<JsonMap> deleteAttachment({
    required String commandId,
    required String attachmentId,
    int? expectedRevision,
  });

  Future<List<JsonMap>> searchDocuments({
    required String workspaceId,
    required String query,
    int limit = 50,
  });

  Future<JsonMap> getSearchStatus();

  Future<JsonMap> rebuildSearchIndex({required String commandId});

  Future<void> close();
}
