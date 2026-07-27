import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:local_api/local_api.dart';
import 'package:persistence_isar/persistence_isar.dart';
import 'package:platform_runtime/platform_runtime.dart';

final class LocaldServer {
  LocaldServer._({
    required this.paths,
    required IsarClientStore store,
    required ProcessLock processLock,
    required HttpServer httpServer,
    required String sessionProof,
  }) : _store = store,
       _processLock = processLock,
       _httpServer = httpServer,
       _sessionProof = sessionProof,
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
  final ClientApplicationService _application;
  late final StreamSubscription<HttpRequest> _requests;
  bool _closed = false;

  int get port => _httpServer.port;

  static Future<LocaldServer> start({
    String profileId = 'default',
    String? profileRoot,
    String? nativeLibraryPath,
    bool allowDevelopmentIsarDownload = false,
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
      );
      await locald._application.ensureSearchIndex();
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
      if (request.method != 'POST') {
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
        'offline',
        'command_deduplication',
        'search',
        'search_rebuild',
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
      ),
      'ApplyBlockChanges' => await _application.saveDocument(
        commandId: commandId,
        documentId: requireString(payload, 'document_id'),
        title: requireString(payload, 'title'),
        blocks: requireMapList(payload, 'blocks').map(_blockDraft).toList(),
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
    'WorkspaceNotFound' || 'DocumentNotFound' => HttpStatus.notFound,
    'RevisionConflict' || 'CommandIdReused' => HttpStatus.conflict,
    _ => HttpStatus.badRequest,
  };
}

final class _SystemClock implements Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
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
