import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:local_api/local_api.dart';
import 'package:local_attachments/local_attachments.dart';
import 'package:local_backup/local_backup.dart' as backup;
import 'package:persistence_isar/persistence_isar.dart';
import 'package:platform_runtime/platform_runtime.dart';

enum LocaldWriteStep {
  afterAttachmentMetadataCommit,
  afterAttachmentContentCommit,
}

typedef LocaldFaultInjector = void Function(LocaldWriteStep step);

final class LocaldServer {
  LocaldServer._({
    required this.paths,
    required IsarClientStore store,
    required ProcessLock processLock,
    required HttpServer httpServer,
    required String sessionProof,
    required LocalAttachmentStore attachmentStore,
    required LocaldFaultInjector? faultInjector,
  }) : _store = store,
       _processLock = processLock,
       _httpServer = httpServer,
       _sessionProof = sessionProof,
       _attachmentStore = attachmentStore,
       _faultInjector = faultInjector,
       _application = ClientApplicationService(
         store: store,
         clock: const _SystemClock(),
         ids: _SecureIdGenerator(),
       );

  final ProfilePaths paths;
  final IsarClientStore _store;
  final ProcessLock _processLock;
  final HttpServer _httpServer;
  final String _sessionProof;
  final LocalAttachmentStore _attachmentStore;
  final LocaldFaultInjector? _faultInjector;
  final ClientApplicationService _application;
  late final StreamSubscription<HttpRequest> _requests;
  bool _closed = false;

  int get port => _httpServer.port;

  static Future<LocaldServer> start({
    String profileId = 'default',
    String? profileRoot,
    String? nativeLibraryPath,
    bool allowDevelopmentIsarDownload = false,
    LocaldFaultInjector? faultInjector,
  }) async {
    final ProfilePaths paths = ProfilePaths.resolve(
      profileId: profileId,
      rootOverride: profileRoot,
    );
    await paths.ensureCreated();
    final ProcessLock processLock = await ProcessLock.acquire(
      paths.processLockFile,
    );
    IsarClientStore? store;
    HttpServer? server;
    try {
      final LocalAttachmentStore attachmentStore =
          await LocalAttachmentStore.open(
            attachmentsRoot: paths.attachments.path,
            stagingRoot: paths.attachmentStaging.path,
            maximumBytes: maximumAttachmentBytes,
          );
      store = await IsarClientStore.open(
        directory: paths.database.path,
        nativeLibraryPath: nativeLibraryPath,
        allowDevelopmentDownload: allowDevelopmentIsarDownload,
      );
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      final String proof = _SecureIdGenerator().nextId();
      final LocaldServer locald = LocaldServer._(
        paths: paths,
        store: store,
        processLock: processLock,
        httpServer: server,
        sessionProof: proof,
        attachmentStore: attachmentStore,
        faultInjector: faultInjector,
      );
      await locald._application.ensureSearchIndex();
      await locald._recoverAttachments();
      locald._requests = server.listen(locald._handleRequest);
      await paths.writeEndpoint(
        EndpointManifest(
          port: server.port,
          sessionProof: proof,
          profileId: profileId,
          processId: pid,
          apiVersion: localApiVersion,
        ),
      );
      return locald;
    } on Object {
      await server?.close(force: true);
      await store?.close();
      await processLock.release();
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final String correlationId =
        request.headers.value('x-request-id') ??
        DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final bool isAttachmentDownload =
          request.uri.path == '/v1/attachments/content';
      final bool isBackupExport = request.uri.path == '/v1/backup/export';
      final bool acceptsGet = isAttachmentDownload || isBackupExport;
      if (request.method != (acceptsGet ? 'GET' : 'POST')) {
        throw const _HttpApiError(
          status: HttpStatus.methodNotAllowed,
          error: LocalApiException(
            code: 'InvalidArgument',
            message: 'Only POST requests are accepted.',
            retryable: false,
          ),
        );
      }
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer $_sessionProof') {
        throw const _HttpApiError(
          status: HttpStatus.unauthorized,
          error: LocalApiException(
            code: 'Unauthenticated',
            message: 'Local API session proof is invalid.',
            retryable: false,
          ),
        );
      }
      if (request.uri.path == '/v1/attachments/stage') {
        if (request.contentLength > maximumAttachmentBytes) {
          throw const _HttpApiError(
            status: HttpStatus.requestEntityTooLarge,
            error: LocalApiException(
              code: 'AttachmentTooLarge',
              message: 'Attachment exceeds the supported byte limit.',
              retryable: false,
            ),
          );
        }
        final JsonMap data = await _stageAttachment(request);
        await _respond(request.response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'data': data,
        });
        return;
      }
      if (isAttachmentDownload) {
        await _downloadAttachment(request);
        return;
      }
      if (isBackupExport) {
        await _exportBackup(request);
        return;
      }
      if (request.uri.path == '/v1/backup/restore') {
        if (request.contentLength > maximumBackupArchiveBytes) {
          throw const _HttpApiError(
            status: HttpStatus.requestEntityTooLarge,
            error: LocalApiException(
              code: 'BackupArchiveTooLarge',
              message: 'Backup archive exceeds the supported byte limit.',
              retryable: false,
            ),
          );
        }
        final JsonMap data = await _restoreBackup(request);
        await _respond(request.response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'data': data,
        });
        return;
      }
      final int contentLength = request.contentLength;
      if (contentLength > maximumRequestBytes) {
        throw const _HttpApiError(
          status: HttpStatus.requestEntityTooLarge,
          error: LocalApiException(
            code: 'InvalidArgument',
            message: 'Local API request is too large.',
            retryable: false,
          ),
        );
      }
      final JsonMap body = await _readJson(request);
      final JsonMap data = switch (request.uri.path) {
        '/v1/health' => _health(),
        '/v1/handshake' => _handshake(body),
        '/v1/query' => await _query(body),
        '/v1/command' => await _command(body),
        _ => throw const _HttpApiError(
          status: HttpStatus.notFound,
          error: LocalApiException(
            code: 'MethodNotFound',
            message: 'Unknown Local API endpoint.',
            retryable: false,
          ),
        ),
      };
      await _respond(request.response, HttpStatus.ok, <String, Object?>{
        'ok': true,
        'data': data,
      });
    } on _HttpApiError catch (failure) {
      await _respondError(
        request.response,
        failure.status,
        failure.error,
        correlationId,
      );
    } on DomainException catch (failure) {
      await _respondError(
        request.response,
        HttpStatus.badRequest,
        LocalApiException(
          code: failure.code,
          message: failure.message,
          retryable: false,
        ),
        correlationId,
      );
    } on ApplicationException catch (failure) {
      await _respondError(
        request.response,
        _statusForApplicationError(failure.code),
        LocalApiException(
          code: failure.code,
          message: failure.message,
          retryable: failure.code == 'StorageBusy',
        ),
        correlationId,
      );
    } on AttachmentStoreException catch (failure) {
      await _respondError(
        request.response,
        _statusForAttachmentError(failure.code),
        LocalApiException(
          code: failure.code,
          message: failure.message,
          retryable:
              failure.code == 'AttachmentRecoveryRequired' ||
              failure.code == 'AttachmentNotFound',
        ),
        correlationId,
      );
    } on backup.BackupArchiveException catch (failure) {
      await _respondError(
        request.response,
        failure.code == 'BackupArchiveTooLarge' ||
                failure.code == 'BackupManifestTooLarge'
            ? HttpStatus.requestEntityTooLarge
            : HttpStatus.badRequest,
        LocalApiException(
          code: failure.code,
          message: failure.message,
          retryable: false,
        ),
        correlationId,
      );
    } on FormatException catch (failure) {
      await _respondError(
        request.response,
        HttpStatus.badRequest,
        LocalApiException(
          code: 'InvalidArgument',
          message: failure.message,
          retryable: false,
        ),
        correlationId,
      );
    } on Object {
      await _respondError(
        request.response,
        HttpStatus.internalServerError,
        const LocalApiException(
          code: 'Internal',
          message: 'Local storage could not complete the request.',
          retryable: true,
        ),
        correlationId,
      );
    }
  }

  JsonMap _health() => <String, Object?>{
    'status': 'ready',
    'locald_version': componentVersion,
    'api_version': localApiVersion,
    'profile_id': paths.profileId,
  };

  JsonMap _handshake(JsonMap body) {
    if (requireString(body, 'api_version') != localApiVersion) {
      throw const _HttpApiError(
        status: HttpStatus.preconditionFailed,
        error: LocalApiException(
          code: 'ApiVersionUnsupported',
          message: 'Requested Local API version is unsupported.',
          retryable: false,
        ),
      );
    }
    if (requireString(body, 'profile_id') != paths.profileId) {
      throw const _HttpApiError(
        status: HttpStatus.forbidden,
        error: LocalApiException(
          code: 'ScopeDenied',
          message: 'Endpoint belongs to another profile.',
          retryable: false,
        ),
      );
    }
    requireString(body, 'client_type');
    requireString(body, 'client_version');
    return <String, Object?>{
      'api_version': localApiVersion,
      'locald_version': componentVersion,
      'profile_id': paths.profileId,
      'capabilities': <String>[
        'documents',
        'document_versions',
        'offline',
        'command_deduplication',
        'search',
        'search_rebuild',
        'attachments',
        'backup_export',
        'backup_restore',
      ],
      'compatibility': 'compatible',
    };
  }

  Future<JsonMap> _query(JsonMap body) async {
    _requireApiVersion(body);
    final String method = requireString(body, 'method');
    final JsonMap payload = requireMap(body, 'payload');
    return switch (method) {
      'ListWorkspaces' => <String, Object?>{
        'workspaces': (await _application.listWorkspaces(
          includeArchived: payload['include_archived'] == true,
        )).map((Workspace workspace) => workspace.toJson()).toList(),
      },
      'GetWorkspace' => (await _application.getWorkspace(
        requireString(payload, 'workspace_id'),
      )).toJson(),
      'ListDocumentTree' => <String, Object?>{
        'documents': (await _application.listDocuments(
          requireString(payload, 'workspace_id'),
          includeDeleted: payload['include_deleted'] == true,
        )).map((Document document) => document.toJson()).toList(),
      },
      'GetDocument' => (await _application.getDocument(
        requireString(payload, 'document_id'),
      )).toJson(),
      'ListDocumentVersions' => <String, Object?>{
        'versions': (await _application.listDocumentVersions(
          requireString(payload, 'document_id'),
        )).map((DocumentVersion version) => version.toJson()).toList(),
      },
      'ListAttachments' => <String, Object?>{
        'attachments': (await _application.listAttachments(
          requireString(payload, 'document_id'),
          includeDeleted: payload['include_deleted'] == true,
        )).map((Attachment attachment) => attachment.toJson()).toList(),
      },
      'GetAttachment' => (await _application.getAttachment(
        requireString(payload, 'attachment_id'),
      )).toJson(),
      'SearchDocuments' => <String, Object?>{
        'results': (await _application.searchDocuments(
          workspaceId: requireString(payload, 'workspace_id'),
          query: requireString(payload, 'query'),
          limit: payload.containsKey('limit')
              ? requireInt(payload, 'limit')
              : 50,
        )).map((SearchHit hit) => hit.toJson()).toList(),
      },
      'GetSearchStatus' => (await _application.getSearchStatus()).toJson(),
      _ => throw const _HttpApiError(
        status: HttpStatus.notFound,
        error: LocalApiException(
          code: 'MethodNotFound',
          message: 'Unknown Local API query.',
          retryable: false,
        ),
      ),
    };
  }

  Future<JsonMap> _command(JsonMap body) async {
    _requireApiVersion(body);
    final String commandId = requireString(body, 'command_id');
    final String method = requireString(body, 'method');
    final JsonMap payload = requireMap(body, 'payload');
    final CommandReceipt receipt = switch (method) {
      'CreateWorkspace' => await _application.createWorkspace(
        commandId: commandId,
        name: requireString(payload, 'name'),
      ),
      'RenameWorkspace' => await _application.renameWorkspace(
        commandId: commandId,
        workspaceId: requireString(payload, 'workspace_id'),
        name: requireString(payload, 'name'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'ArchiveWorkspace' => await _application.archiveWorkspace(
        commandId: commandId,
        workspaceId: requireString(payload, 'workspace_id'),
        archived: requireBool(payload, 'archived'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'DeleteWorkspace' => await _application.deleteWorkspace(
        commandId: commandId,
        workspaceId: requireString(payload, 'workspace_id'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'CreateDocument' => await _application.createDocument(
        commandId: commandId,
        workspaceId: requireString(payload, 'workspace_id'),
        title: requireString(payload, 'title'),
        parentId: payload['parent_id'] as String?,
        documentType: _documentType(payload['document_type']),
      ),
      'ApplyBlockChanges' => await _application.saveDocument(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        title: requireString(payload, 'title'),
        blocks: requireMapList(payload, 'blocks').map(_blockDraft).toList(),
        documentType: payload.containsKey('document_type')
            ? _documentType(payload['document_type'])
            : null,
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'MoveDocument' => await _application.moveDocument(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        parentId: payload['parent_id'] as String?,
        position: requireInt(payload, 'position'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'DeleteDocument' => await _application.deleteDocument(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'RestoreDocument' => await _application.restoreDocument(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'AttachStagedFile' => await _attachStagedFile(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        stagingToken: requireString(payload, 'staging_token'),
        expectedDocumentRevision: payload['expected_document_revision'] as int?,
      ),
      'DeleteAttachment' => await _application.deleteAttachment(
        commandId: commandId,
        attachmentId: requireString(payload, 'attachment_id'),
        expectedRevision: payload['expected_revision'] as int?,
      ),
      'RebuildSearchIndex' => await _application.rebuildSearchIndex(
        commandId: commandId,
      ),
      _ => throw const _HttpApiError(
        status: HttpStatus.notFound,
        error: LocalApiException(
          code: 'MethodNotFound',
          message: 'Unknown Local API command.',
          retryable: false,
        ),
      ),
    };
    return <String, Object?>{
      ...receipt.result,
      'commit_sequence': receipt.commitSequence,
      'was_replay': receipt.wasReplay,
    };
  }

  Future<JsonMap> _stageAttachment(HttpRequest request) async {
    final String? fileName = request.uri.queryParameters['file_name'];
    final String? mediaType = request.uri.queryParameters['media_type'];
    if (fileName == null || mediaType == null) {
      throw const FormatException(
        'Attachment file_name and media_type are required.',
      );
    }
    final StagedAttachment staged = await _attachmentStore.stage(
      bytes: request,
      fileName: fileName,
      mediaType: mediaType,
    );
    return staged.toJson();
  }

  Future<void> _downloadAttachment(HttpRequest request) async {
    final String? attachmentId = request.uri.queryParameters['attachment_id'];
    if (attachmentId == null || attachmentId.isEmpty) {
      throw const FormatException('Attachment attachment_id is required.');
    }
    final Attachment attachment = await _application.getAttachment(
      attachmentId,
    );
    final AttachmentContent content = await _attachmentStore.openContent(
      attachment.sha256,
    );
    if (content.size != attachment.size) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Attachment bytes do not match authoritative metadata.',
      );
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = content.size
      ..headers.set(HttpHeaders.contentTypeHeader, attachment.mediaType)
      ..headers.set('x-endless-attachment-id', attachment.id)
      ..headers.set(
        'x-endless-file-name',
        Uri.encodeComponent(attachment.fileName),
      )
      ..headers.set('x-endless-sha256', attachment.sha256)
      ..headers.set(
        'content-disposition',
        "attachment; filename*=UTF-8''${Uri.encodeComponent(attachment.fileName)}",
      );
    await request.response.addStream(content.bytes);
    await request.response.close();
  }

  Future<void> _exportBackup(HttpRequest request) async {
    final ClientBackupSnapshot snapshot = await _application
        .createBackupSnapshot();
    final backup.BackupArchiveWriter archive =
        await backup.BackupArchiveWriter.prepare(
          snapshot: snapshot,
          openContent: (String hash, int expectedSize) async {
            final AttachmentContent content = await _attachmentStore
                .openContent(hash);
            if (content.size != expectedSize) {
              throw const backup.BackupArchiveException(
                'BackupAttachmentMismatch',
                'Attachment bytes do not match authoritative metadata.',
              );
            }
            return backup.BackupContent(
              sha256: content.sha256,
              size: content.size,
              bytes: content.bytes,
            );
          },
        );
    request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = archive.contentLength
      ..headers.set(
        HttpHeaders.contentTypeHeader,
        'application/vnd.endless.backup',
      )
      ..headers.set('cache-control', 'no-store')
      ..headers.set(
        'content-disposition',
        'attachment; filename="endless-${paths.profileId}.backup"',
      );
    await request.response.addStream(archive.openRead());
    await request.response.close();
  }

  Future<JsonMap> _restoreBackup(HttpRequest request) async {
    final backup.BackupArchiveReader archive =
        await backup.BackupArchiveReader.stage(
          bytes: request,
          stagingDirectory: paths.backupStaging.path,
          maximumArchiveBytes: maximumBackupArchiveBytes,
        );
    try {
      await _application.ensureCleanRestoreTarget();
      for (final String hash in archive.contentHashes) {
        final backup.BackupContent content = archive.openContent(hash);
        final StagedAttachment staged = await _attachmentStore.stage(
          bytes: content.bytes,
          fileName: '$hash.bin',
          mediaType: 'application/octet-stream',
        );
        if (staged.sha256 != hash || staged.size != content.size) {
          throw const backup.BackupArchiveException(
            'BackupAttachmentMismatch',
            'Restored attachment bytes failed their integrity check.',
          );
        }
        final StagedAttachment committed = await _attachmentStore.commit(
          staged.token,
        );
        if (committed.sha256 != hash || committed.size != content.size) {
          throw const backup.BackupArchiveException(
            'BackupAttachmentMismatch',
            'Committed attachment bytes failed their integrity check.',
          );
        }
        await _attachmentStore.releaseToken(staged.token);
      }
      await _application.restoreBackupSnapshot(archive.snapshot);
      return <String, Object?>{
        'format_version': clientBackupFormatVersion,
        'workspaces': archive.snapshot.workspaces.length,
        'documents': archive.snapshot.documents.length,
        'attachments': archive.snapshot.attachments.length,
        'operations': archive.snapshot.operations.length,
        'event_sequence': archive.snapshot.eventSequence,
      };
    } finally {
      await archive.dispose();
    }
  }

  Future<CommandReceipt> _attachStagedFile({
    required String commandId,
    required String documentId,
    required String stagingToken,
    int? expectedDocumentRevision,
  }) async {
    final StagedAttachment staged;
    try {
      staged = await _attachmentStore.describe(stagingToken);
    } on AttachmentStoreException catch (failure) {
      if (failure.code != 'AttachmentNotFound') {
        rethrow;
      }
      final CommandReceipt? replay = await _application.replayAttachStagedFile(
        commandId: commandId,
        documentId: documentId,
        stagingToken: stagingToken,
        expectedDocumentRevision: expectedDocumentRevision,
      );
      if (replay == null) {
        rethrow;
      }
      await _verifyCommittedAttachment(
        requireString(replay.result, 'sha256'),
        requireInt(replay.result, 'size'),
      );
      return replay;
    }
    final CommandReceipt receipt = await _application.attachStagedFile(
      commandId: commandId,
      documentId: documentId,
      staged: StagedAttachmentDraft(
        stagingToken: staged.token,
        fileName: staged.fileName,
        mediaType: staged.mediaType,
        sha256: staged.sha256,
        size: staged.size,
      ),
      expectedDocumentRevision: expectedDocumentRevision,
    );
    _faultInjector?.call(LocaldWriteStep.afterAttachmentMetadataCommit);
    final String attachmentId = requireString(receipt.result, 'attachment_id');
    final AttachmentCommitMarker? marker = await _application
        .pendingAttachmentCommit(attachmentId);
    if (marker == null) {
      await _verifyCommittedAttachment(
        requireString(receipt.result, 'sha256'),
        requireInt(receipt.result, 'size'),
      );
      await _attachmentStore.releaseToken(stagingToken);
    } else {
      await _finishAttachmentCommit(marker);
    }
    return receipt;
  }

  Future<void> _finishAttachmentCommit(AttachmentCommitMarker marker) async {
    try {
      final StagedAttachment staged = await _attachmentStore.describe(
        marker.stagingToken,
      );
      if (staged.sha256 != marker.sha256 || staged.size != marker.size) {
        throw const AttachmentStoreException(
          'AttachmentIntegrityFailure',
          'Staged bytes do not match their authoritative recovery marker.',
        );
      }
      final StagedAttachment committed = await _attachmentStore.commit(
        marker.stagingToken,
      );
      if (committed.sha256 != marker.sha256 || committed.size != marker.size) {
        throw const AttachmentStoreException(
          'AttachmentIntegrityFailure',
          'Committed bytes do not match their authoritative recovery marker.',
        );
      }
    } on AttachmentStoreException catch (failure) {
      if (failure.code != 'AttachmentNotFound') {
        rethrow;
      }
      await _verifyCommittedAttachment(marker.sha256, marker.size);
    }
    _faultInjector?.call(LocaldWriteStep.afterAttachmentContentCommit);
    await _application.completeAttachmentCommit(marker);
    await _attachmentStore.releaseToken(marker.stagingToken);
  }

  Future<void> _verifyCommittedAttachment(String hash, int size) async {
    final AttachmentContent content = await _attachmentStore.openContent(hash);
    if (content.size != size) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Committed bytes do not match authoritative metadata.',
      );
    }
  }

  Future<void> _recoverAttachments() async {
    for (final AttachmentCommitMarker marker
        in await _application.pendingAttachmentCommits()) {
      await _finishAttachmentCommit(marker);
    }
    final AttachmentRecoveryReport report = await _attachmentStore
        .recoverPendingCommits();
    if (report.warnings.isNotEmpty) {
      throw AttachmentStoreException(
        'AttachmentRecoveryRequired',
        'Attachment recovery found ${report.warnings.length} invalid '
            'journal(s).',
      );
    }
  }

  static BlockDraft _blockDraft(JsonMap json) {
    final String typeName = requireString(json, 'type');
    final BlockType type = BlockType.values.firstWhere(
      (BlockType candidate) => candidate.name == typeName,
      orElse: () => BlockType.unsupported,
    );
    return BlockDraft(
      id: json['block_id'] as String?,
      type: type,
      payload: requireMap(json, 'payload'),
    );
  }

  static void _requireApiVersion(JsonMap body) {
    if (requireString(body, 'api_version') != localApiVersion) {
      throw const _HttpApiError(
        status: HttpStatus.preconditionFailed,
        error: LocalApiException(
          code: 'ApiVersionUnsupported',
          message: 'Requested Local API version is unsupported.',
          retryable: false,
        ),
      );
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _requests.cancel();
    await _httpServer.close(force: true);
    final EndpointManifest? endpoint = await paths.readEndpoint();
    if (endpoint?.processId == pid && await paths.endpointFile.exists()) {
      await paths.endpointFile.delete();
    }
    await _store.close();
    await _processLock.release();
  }

  static Future<JsonMap> _readJson(HttpRequest request) async {
    final BytesBuilder bytes = BytesBuilder(copy: false);
    int size = 0;
    await for (final List<int> chunk in request) {
      size += chunk.length;
      if (size > maximumRequestBytes) {
        throw const _HttpApiError(
          status: HttpStatus.requestEntityTooLarge,
          error: LocalApiException(
            code: 'InvalidArgument',
            message: 'Local API request is too large.',
            retryable: false,
          ),
        );
      }
      bytes.add(chunk);
    }
    final Object? decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON request object.');
    }
    return decoded;
  }

  static Future<void> _respondError(
    HttpResponse response,
    int status,
    LocalApiException error,
    String correlationId,
  ) => _respond(response, status, <String, Object?>{
    'ok': false,
    'error': <String, Object?>{
      ...error.toJson(),
      'correlation_id': correlationId,
    },
  });

  static Future<void> _respond(
    HttpResponse response,
    int status,
    JsonMap body,
  ) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('cache-control', 'no-store')
      ..write(jsonEncode(body));
    await response.close();
  }

  static int _statusForApplicationError(String code) => switch (code) {
    'WorkspaceNotFound' ||
    'DocumentNotFound' ||
    'AttachmentNotFound' => HttpStatus.notFound,
    'RevisionConflict' ||
    'CommandIdReused' ||
    'RestoreTargetNotEmpty' ||
    'AttachmentRecoveryConflict' => HttpStatus.conflict,
    _ => HttpStatus.badRequest,
  };

  static int _statusForAttachmentError(String code) => switch (code) {
    'AttachmentNotFound' => HttpStatus.notFound,
    'AttachmentTooLarge' => HttpStatus.requestEntityTooLarge,
    'AttachmentRecoveryRequired' => HttpStatus.serviceUnavailable,
    'AttachmentIntegrityFailure' ||
    'AttachmentJournalInvalid' ||
    'AttachmentJournalConflict' ||
    'UnsafeAttachmentPath' => HttpStatus.conflict,
    _ => HttpStatus.badRequest,
  };
}

final class _SystemClock implements Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

DocumentType _documentType(Object? value) {
  if (value == null) {
    return DocumentType.plain;
  }
  if (value is! String) {
    throw const FormatException('document_type must be a string.');
  }
  try {
    return documentTypeFromWireName(value);
  } on ArgumentError {
    throw FormatException('Unsupported document_type "$value".');
  }
}

final class _SecureIdGenerator implements IdGenerator {
  final Random _random = Random.secure();

  @override
  String nextId() {
    final Uint8List bytes = Uint8List(20);
    for (int index = 0; index < bytes.length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

final class _HttpApiError implements Exception {
  const _HttpApiError({required this.status, required this.error});

  final int status;
  final LocalApiException error;
}
