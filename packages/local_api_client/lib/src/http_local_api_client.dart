import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:local_api/local_api.dart';

import 'endless_local_api.dart';

final class HttpLocalApiClient implements EndlessLocalApi {
  HttpLocalApiClient({
    required EndpointManifest endpoint,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
    Duration attachmentTimeout = const Duration(minutes: 2),
  }) : _endpoint = endpoint,
       _httpClient = httpClient ?? _directLoopbackClient(),
       _timeout = timeout,
       _attachmentTimeout = attachmentTimeout;

  final EndpointManifest _endpoint;
  final http.Client _httpClient;
  final Duration _timeout;
  final Duration _attachmentTimeout;
  int _requestSequence = 0;

  @override
  Future<JsonMap> handshake({
    required LocalClientType clientType,
    required String profileId,
  }) => _post('/v1/handshake', <String, Object?>{
    'api_version': localApiVersion,
    'client_type': clientType.name,
    'client_version': componentVersion,
    'profile_id': profileId,
    'capabilities': <String>['documents', 'offline', 'attachments'],
  });

  @override
  Future<JsonMap> health() => _post('/v1/health', const <String, Object?>{});

  @override
  Future<List<JsonMap>> listWorkspaces({bool includeArchived = false}) async {
    final JsonMap data = await _query(
      'ListWorkspaces',
      payload: <String, Object?>{'include_archived': includeArchived},
    );
    return requireMapList(data, 'workspaces');
  }

  @override
  Future<JsonMap> getWorkspace(String workspaceId) => _query(
    'GetWorkspace',
    payload: <String, Object?>{'workspace_id': workspaceId},
  );

  @override
  Future<JsonMap> createWorkspace({
    required String commandId,
    required String name,
  }) => _command(
    commandId: commandId,
    method: 'CreateWorkspace',
    payload: <String, Object?>{'name': name},
  );

  @override
  Future<JsonMap> renameWorkspace({
    required String commandId,
    required String workspaceId,
    required String name,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'RenameWorkspace',
    payload: <String, Object?>{
      'workspace_id': workspaceId,
      'name': name,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> archiveWorkspace({
    required String commandId,
    required String workspaceId,
    required bool archived,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'ArchiveWorkspace',
    payload: <String, Object?>{
      'workspace_id': workspaceId,
      'archived': archived,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> deleteWorkspace({
    required String commandId,
    required String workspaceId,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'DeleteWorkspace',
    payload: <String, Object?>{
      'workspace_id': workspaceId,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<List<JsonMap>> listDocuments({
    required String workspaceId,
    bool includeDeleted = false,
  }) async {
    final JsonMap data = await _query(
      'ListDocumentTree',
      payload: <String, Object?>{
        'workspace_id': workspaceId,
        'include_deleted': includeDeleted,
      },
    );
    return requireMapList(data, 'documents');
  }

  @override
  Future<JsonMap> getDocument(String documentId) => _query(
    'GetDocument',
    payload: <String, Object?>{'document_id': documentId},
  );

  @override
  Future<JsonMap> createDocument({
    required String commandId,
    required String workspaceId,
    required String title,
    String? parentId,
  }) => _command(
    commandId: commandId,
    method: 'CreateDocument',
    payload: <String, Object?>{
      'workspace_id': workspaceId,
      'title': title,
      'parent_id': parentId,
    },
  );

  @override
  Future<JsonMap> saveDocument({
    required String commandId,
    required String documentId,
    required String title,
    required List<JsonMap> blocks,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'ApplyBlockChanges',
    payload: <String, Object?>{
      'document_id': documentId,
      'title': title,
      'blocks': blocks,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> moveDocument({
    required String commandId,
    required String documentId,
    required String? parentId,
    required int position,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'MoveDocument',
    payload: <String, Object?>{
      'document_id': documentId,
      'parent_id': parentId,
      'position': position,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> deleteDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'DeleteDocument',
    payload: <String, Object?>{
      'document_id': documentId,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> restoreDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'RestoreDocument',
    payload: <String, Object?>{
      'document_id': documentId,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<JsonMap> stageAttachment({
    required Stream<List<int>> bytes,
    required String fileName,
    required String mediaType,
    int? contentLength,
  }) async {
    if (contentLength != null &&
        (contentLength < 0 || contentLength > maximumAttachmentBytes)) {
      throw const LocalApiException(
        code: 'InvalidArgument',
        message: 'Attachment content length is outside the supported range.',
        retryable: false,
      );
    }
    final Uri uri = _endpoint.baseUri
        .resolve('/v1/attachments/stage')
        .replace(
          queryParameters: <String, String>{
            'file_name': fileName,
            'media_type': mediaType,
          },
        );
    final http.StreamedRequest request = http.StreamedRequest('POST', uri)
      ..headers['authorization'] = 'Bearer ${_endpoint.sessionProof}'
      ..headers['content-type'] = 'application/octet-stream';
    if (contentLength != null) {
      request.contentLength = contentLength;
    }
    bool requestClosed = false;
    try {
      final Future<http.StreamedResponse> responseFuture = _httpClient.send(
        request,
      );
      await request.sink.addStream(bytes).timeout(_attachmentTimeout);
      await request.sink.close();
      requestClosed = true;
      final http.StreamedResponse response = await responseFuture.timeout(
        _attachmentTimeout,
      );
      final List<int> body = await response.stream.toBytes().timeout(
        _attachmentTimeout,
      );
      return _decodeJsonBytes(body);
    } on LocalApiException {
      await _closeUploadRequest(request, requestClosed);
      rethrow;
    } on TimeoutException {
      await _closeUploadRequest(request, requestClosed);
      throw const LocalApiException(
        code: 'DeadlineExceeded',
        message: 'Attachment upload did not complete in time.',
        retryable: true,
      );
    } on Object catch (error) {
      await _closeUploadRequest(request, requestClosed);
      throw LocalApiException(
        code: 'LocaldUnavailable',
        message: 'Cannot upload to local storage: $error',
        retryable: true,
      );
    }
  }

  @override
  Future<JsonMap> attachStagedFile({
    required String commandId,
    required String documentId,
    required String stagingToken,
    int? expectedDocumentRevision,
  }) => _command(
    commandId: commandId,
    method: 'AttachStagedFile',
    payload: <String, Object?>{
      'document_id': documentId,
      'staging_token': stagingToken,
      'expected_document_revision': expectedDocumentRevision,
    },
  );

  @override
  Future<List<JsonMap>> listAttachments({
    required String documentId,
    bool includeDeleted = false,
  }) async {
    final JsonMap data = await _query(
      'ListAttachments',
      payload: <String, Object?>{
        'document_id': documentId,
        'include_deleted': includeDeleted,
      },
    );
    return requireMapList(data, 'attachments');
  }

  @override
  Future<JsonMap> getAttachment(String attachmentId) => _query(
    'GetAttachment',
    payload: <String, Object?>{'attachment_id': attachmentId},
  );

  @override
  Future<AttachmentDownload> downloadAttachment(String attachmentId) async {
    final Uri uri = _endpoint.baseUri
        .resolve('/v1/attachments/content')
        .replace(
          queryParameters: <String, String>{'attachment_id': attachmentId},
        );
    final http.Request request = http.Request('GET', uri)
      ..headers['authorization'] = 'Bearer ${_endpoint.sessionProof}';
    try {
      final http.StreamedResponse response = await _httpClient
          .send(request)
          .timeout(_attachmentTimeout);
      if (response.statusCode != HttpStatus.ok) {
        final List<int> body = await response.stream.toBytes().timeout(
          _attachmentTimeout,
        );
        _decodeJsonBytes(body);
        throw const LocalApiException(
          code: 'InvalidResponse',
          message: 'locald returned an invalid attachment response.',
          retryable: true,
        );
      }
      final String? encodedName = response.headers['x-endless-file-name'];
      final String? hash = response.headers['x-endless-sha256'];
      final String? responseAttachmentId =
          response.headers['x-endless-attachment-id'];
      final int? size = response.contentLength;
      if (encodedName == null ||
          hash == null ||
          responseAttachmentId == null ||
          responseAttachmentId != attachmentId ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
          size == null ||
          size < 0 ||
          size > maximumAttachmentBytes) {
        throw const LocalApiException(
          code: 'InvalidResponse',
          message: 'locald omitted required attachment metadata.',
          retryable: true,
        );
      }
      return AttachmentDownload(
        attachmentId: responseAttachmentId,
        fileName: Uri.decodeComponent(encodedName),
        mediaType:
            response.headers[HttpHeaders.contentTypeHeader] ??
            'application/octet-stream',
        sha256: hash,
        size: size,
        bytes: response.stream.timeout(_attachmentTimeout),
      );
    } on LocalApiException {
      rethrow;
    } on TimeoutException {
      throw const LocalApiException(
        code: 'DeadlineExceeded',
        message: 'Attachment download did not respond in time.',
        retryable: true,
      );
    } on Object catch (error) {
      throw LocalApiException(
        code: 'LocaldUnavailable',
        message: 'Cannot download from local storage: $error',
        retryable: true,
      );
    }
  }

  @override
  Future<JsonMap> deleteAttachment({
    required String commandId,
    required String attachmentId,
    int? expectedRevision,
  }) => _command(
    commandId: commandId,
    method: 'DeleteAttachment',
    payload: <String, Object?>{
      'attachment_id': attachmentId,
      'expected_revision': expectedRevision,
    },
  );

  @override
  Future<List<JsonMap>> searchDocuments({
    required String workspaceId,
    required String query,
    int limit = 50,
  }) async {
    final JsonMap data = await _query(
      'SearchDocuments',
      payload: <String, Object?>{
        'workspace_id': workspaceId,
        'query': query,
        'limit': limit,
      },
    );
    return requireMapList(data, 'results');
  }

  @override
  Future<JsonMap> getSearchStatus() => _query('GetSearchStatus');

  @override
  Future<JsonMap> rebuildSearchIndex({required String commandId}) => _command(
    commandId: commandId,
    method: 'RebuildSearchIndex',
    payload: const <String, Object?>{},
  );

  Future<JsonMap> _query(String method, {JsonMap? payload}) =>
      _post('/v1/query', <String, Object?>{
        'request_id': _nextRequestId(),
        'api_version': localApiVersion,
        'method': method,
        'payload': payload ?? const <String, Object?>{},
      });

  Future<JsonMap> _command({
    required String commandId,
    required String method,
    required JsonMap payload,
  }) => _post('/v1/command', <String, Object?>{
    'request_id': _nextRequestId(),
    'command_id': commandId,
    'api_version': localApiVersion,
    'method': method,
    'payload': payload,
  });

  Future<JsonMap> _post(String path, JsonMap body) async {
    try {
      final http.Response response = await _httpClient
          .post(
            _endpoint.baseUri.resolve(path),
            headers: <String, String>{
              'authorization': 'Bearer ${_endpoint.sessionProof}',
              'content-type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decodeJsonBytes(response.bodyBytes);
    } on LocalApiException {
      rethrow;
    } on TimeoutException {
      throw const LocalApiException(
        code: 'DeadlineExceeded',
        message: 'locald did not respond in time.',
        retryable: true,
      );
    } on Object catch (error) {
      throw LocalApiException(
        code: 'LocaldUnavailable',
        message: 'Cannot connect to local storage: $error',
        retryable: true,
      );
    }
  }

  String _nextRequestId() {
    _requestSequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_requestSequence';
  }

  static JsonMap _decodeJsonBytes(List<int> bytes) {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const LocalApiException(
        code: 'InvalidResponse',
        message: 'locald returned an invalid response.',
        retryable: true,
      );
    }
    if (decoded['ok'] != true) {
      throw LocalApiException.fromJson(requireMap(decoded, 'error'));
    }
    return requireMap(decoded, 'data');
  }

  static Future<void> _closeUploadRequest(
    http.StreamedRequest request,
    bool alreadyClosed,
  ) async {
    if (alreadyClosed) {
      return;
    }
    try {
      await request.sink.close();
    } on Object {
      // Preserve the original upload/transport failure.
    }
  }

  @override
  Future<void> close() async {
    _httpClient.close();
  }

  static http.Client _directLoopbackClient() {
    final HttpClient client = HttpClient()..findProxy = (Uri _) => 'DIRECT';
    return IOClient(client);
  }
}
