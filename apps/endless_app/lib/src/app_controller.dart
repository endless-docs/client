import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';
import 'package:platform_runtime/platform_runtime.dart';

enum AppPhase { starting, ready, failed }

typedef LocalApiBootstrap = Future<EndlessLocalApi> Function();

final class DocumentTreeEntry {
  const DocumentTreeEntry({required this.document, required this.depth});

  final JsonMap document;
  final int depth;
}

final class AppController extends ChangeNotifier {
  AppController({required LocalApiBootstrap bootstrap})
    : _bootstrap = bootstrap;

  factory AppController.production() => AppController(
    bootstrap: () async {
      const String profileId = 'default';
      final EndpointManifest endpoint = await const LocaldDiscovery()
          .ensureLocald(profileId: profileId);
      final HttpLocalApiClient client = HttpLocalApiClient(endpoint: endpoint);
      try {
        await client.handshake(
          clientType: LocalClientType.flutterUi,
          profileId: profileId,
        );
        return client;
      } on Object {
        await client.close();
        rethrow;
      }
    },
  );

  final LocalApiBootstrap _bootstrap;
  EndlessLocalApi? _client;
  Object? _editorOwner;
  Future<void> Function()? _flushEditor;

  AppPhase phase = AppPhase.starting;
  String? errorMessage;
  bool reconnecting = false;
  bool showRecycleBin = false;
  bool searching = false;
  String searchQuery = '';
  String? searchError;
  List<JsonMap> searchResults = <JsonMap>[];
  List<JsonMap> workspaces = <JsonMap>[];
  List<JsonMap> documents = <JsonMap>[];
  List<JsonMap> attachments = <JsonMap>[];
  String? selectedWorkspaceId;
  String? selectedDocumentId;
  int _searchRequest = 0;

  bool get hasSearch => searchQuery.isNotEmpty;

  JsonMap? get selectedWorkspace {
    final String? id = selectedWorkspaceId;
    if (id == null) {
      return null;
    }
    for (final JsonMap workspace in workspaces) {
      if (workspace['workspace_id'] == id) {
        return workspace;
      }
    }
    return null;
  }

  bool get isSelectedWorkspaceWritable =>
      selectedWorkspace?['lifecycle'] == 'active';

  JsonMap? get selectedDocument {
    final String? id = selectedDocumentId;
    if (id == null) {
      return null;
    }
    for (final JsonMap document in documents) {
      if (document['document_id'] == id && document['is_deleted'] != true) {
        return document;
      }
    }
    return null;
  }

  List<JsonMap> get activeDocuments => documents
      .where((JsonMap document) => document['is_deleted'] != true)
      .toList(growable: false);

  List<JsonMap> get deletedDocuments =>
      documents
          .where((JsonMap document) => document['is_deleted'] == true)
          .toList(growable: false)
        ..sort(
          (JsonMap left, JsonMap right) => requireString(
            right,
            'updated_at',
          ).compareTo(requireString(left, 'updated_at')),
        );

  List<DocumentTreeEntry> get documentTree {
    final List<JsonMap> active = activeDocuments;
    final Set<String> knownIds = active
        .map((JsonMap document) => requireString(document, 'document_id'))
        .toSet();
    final Map<String?, List<JsonMap>> children = <String?, List<JsonMap>>{};
    for (final JsonMap document in active) {
      final String? requestedParent = document['parent_id'] as String?;
      final String? parent =
          requestedParent != null && knownIds.contains(requestedParent)
          ? requestedParent
          : null;
      children.putIfAbsent(parent, () => <JsonMap>[]).add(document);
    }
    for (final List<JsonMap> siblings in children.values) {
      siblings.sort((JsonMap left, JsonMap right) {
        final int position = requireInt(
          left,
          'position',
        ).compareTo(requireInt(right, 'position'));
        return position != 0
            ? position
            : requireString(
                left,
                'title',
              ).compareTo(requireString(right, 'title'));
      });
    }
    final List<DocumentTreeEntry> result = <DocumentTreeEntry>[];
    final Set<String> visited = <String>{};
    void append(String? parentId, int depth) {
      for (final JsonMap document in children[parentId] ?? const <JsonMap>[]) {
        final String id = requireString(document, 'document_id');
        if (!visited.add(id)) {
          continue;
        }
        result.add(DocumentTreeEntry(document: document, depth: depth));
        append(id, depth + 1);
      }
    }

    append(null, 0);
    for (final JsonMap document in active) {
      final String id = requireString(document, 'document_id');
      if (visited.add(id)) {
        result.add(DocumentTreeEntry(document: document, depth: 0));
      }
    }
    return result;
  }

  List<JsonMap> validParentsFor(String documentId) {
    final Set<String> excluded = <String>{documentId};
    bool changed;
    do {
      changed = false;
      for (final JsonMap document in activeDocuments) {
        final String id = requireString(document, 'document_id');
        if (!excluded.contains(id) &&
            excluded.contains(document['parent_id'])) {
          excluded.add(id);
          changed = true;
        }
      }
    } while (changed);
    return activeDocuments
        .where(
          (JsonMap document) =>
              !excluded.contains(requireString(document, 'document_id')),
        )
        .toList(growable: false);
  }

  Future<void> initialize() async {
    phase = AppPhase.starting;
    errorMessage = null;
    notifyListeners();
    await _client?.close();
    _client = null;
    try {
      _client = await _bootstrap();
      await _loadWorkspaces();
      phase = AppPhase.ready;
    } on LocalApiException catch (error) {
      phase = AppPhase.failed;
      errorMessage = error.message;
    } on Object {
      phase = AppPhase.failed;
      errorMessage = 'Не удалось запустить локальное хранилище.';
    }
    notifyListeners();
  }

  void attachEditor(Object owner, Future<void> Function() flush) {
    _editorOwner = owner;
    _flushEditor = flush;
  }

  void detachEditor(Object owner) {
    if (identical(_editorOwner, owner)) {
      _editorOwner = null;
      _flushEditor = null;
    }
  }

  Future<void> flushPendingChanges() async {
    await _flushEditor?.call();
  }

  Future<void> _loadWorkspaces() async {
    workspaces = await _withReconnect(
      (EndlessLocalApi client) => client.listWorkspaces(includeArchived: true),
    );
    if (workspaces.isEmpty) {
      selectedWorkspaceId = null;
      selectedDocumentId = null;
      documents = <JsonMap>[];
      attachments = <JsonMap>[];
      _clearSearchState();
      return;
    }
    final bool selectedStillExists = workspaces.any(
      (JsonMap workspace) => workspace['workspace_id'] == selectedWorkspaceId,
    );
    selectedWorkspaceId = selectedStillExists
        ? selectedWorkspaceId
        : requireString(
            workspaces.firstWhere(
              (JsonMap workspace) => workspace['lifecycle'] == 'active',
              orElse: () => workspaces.first,
            ),
            'workspace_id',
          );
    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final String? workspaceId = selectedWorkspaceId;
    if (workspaceId == null) {
      documents = <JsonMap>[];
      attachments = <JsonMap>[];
      selectedDocumentId = null;
      _clearSearchState();
      return;
    }
    documents = await _withReconnect(
      (EndlessLocalApi client) =>
          client.listDocuments(workspaceId: workspaceId, includeDeleted: true),
    );
    final bool selectedStillExists = activeDocuments.any(
      (JsonMap document) => document['document_id'] == selectedDocumentId,
    );
    selectedDocumentId = selectedStillExists
        ? selectedDocumentId
        : showRecycleBin || activeDocuments.isEmpty
        ? null
        : requireString(activeDocuments.first, 'document_id');
    await _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    final String? documentId = selectedDocumentId;
    if (documentId == null) {
      attachments = <JsonMap>[];
      return;
    }
    attachments = await _withReconnect(
      (EndlessLocalApi client) =>
          client.listAttachments(documentId: documentId),
    );
  }

  Future<void> selectWorkspace(String workspaceId) async {
    if (workspaceId == selectedWorkspaceId) {
      return;
    }
    await flushPendingChanges();
    selectedWorkspaceId = workspaceId;
    selectedDocumentId = null;
    showRecycleBin = false;
    _clearSearchState();
    await _loadDocuments();
    notifyListeners();
  }

  Future<void> selectDocument(String documentId) async {
    if (documentId == selectedDocumentId) {
      return;
    }
    await flushPendingChanges();
    selectedDocumentId = documentId;
    showRecycleBin = false;
    await _loadAttachments();
    notifyListeners();
  }

  Future<void> setRecycleBin(bool value) async {
    if (value == showRecycleBin) {
      return;
    }
    await flushPendingChanges();
    showRecycleBin = value;
    _clearSearchState();
    selectedDocumentId = null;
    if (!value && activeDocuments.isNotEmpty) {
      selectedDocumentId = requireString(activeDocuments.first, 'document_id');
    }
    await _loadAttachments();
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    await flushPendingChanges();
    final String commandId = _commandId();
    final JsonMap created = await _withReconnect(
      (EndlessLocalApi client) =>
          client.createWorkspace(commandId: commandId, name: name),
    );
    await _loadWorkspaces();
    selectedWorkspaceId = requireString(created, 'workspace_id');
    selectedDocumentId = null;
    showRecycleBin = false;
    _clearSearchState();
    await _loadDocuments();
    notifyListeners();
  }

  Future<void> renameSelectedWorkspace(String name) async {
    await flushPendingChanges();
    final JsonMap? workspace = selectedWorkspace;
    if (workspace == null) {
      return;
    }
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.renameWorkspace(
        commandId: commandId,
        workspaceId: requireString(workspace, 'workspace_id'),
        name: name,
        expectedRevision: requireInt(workspace, 'revision'),
      ),
    );
    await _loadWorkspaces();
    notifyListeners();
  }

  Future<void> setSelectedWorkspaceArchived(bool archived) async {
    await flushPendingChanges();
    final JsonMap? workspace = selectedWorkspace;
    if (workspace == null) {
      return;
    }
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.archiveWorkspace(
        commandId: commandId,
        workspaceId: requireString(workspace, 'workspace_id'),
        archived: archived,
        expectedRevision: requireInt(workspace, 'revision'),
      ),
    );
    showRecycleBin = false;
    _clearSearchState();
    await _loadWorkspaces();
    notifyListeners();
  }

  Future<void> deleteSelectedWorkspace() async {
    await flushPendingChanges();
    final JsonMap? workspace = selectedWorkspace;
    if (workspace == null) {
      return;
    }
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.deleteWorkspace(
        commandId: commandId,
        workspaceId: requireString(workspace, 'workspace_id'),
        expectedRevision: requireInt(workspace, 'revision'),
      ),
    );
    selectedWorkspaceId = null;
    selectedDocumentId = null;
    showRecycleBin = false;
    _clearSearchState();
    await _loadWorkspaces();
    notifyListeners();
  }

  Future<void> createDocument(String title, {String? parentId}) async {
    await flushPendingChanges();
    final String? workspaceId = selectedWorkspaceId;
    if (workspaceId == null) {
      throw StateError('Select a workspace first.');
    }
    if (!isSelectedWorkspaceWritable) {
      throw StateError('Archived workspace is read-only.');
    }
    final String commandId = _commandId();
    final JsonMap created = await _withReconnect(
      (EndlessLocalApi client) => client.createDocument(
        commandId: commandId,
        workspaceId: workspaceId,
        title: title,
        parentId: parentId,
      ),
    );
    showRecycleBin = false;
    _clearSearchState();
    await _loadDocuments();
    selectedDocumentId = requireString(created, 'document_id');
    await _loadAttachments();
    notifyListeners();
  }

  Future<JsonMap> saveDocument({
    required String documentId,
    required String title,
    required String text,
    required int expectedRevision,
    String? blockId,
  }) async {
    final String commandId = _commandId();
    final JsonMap saved = await _withReconnect(
      (EndlessLocalApi client) => client.saveDocument(
        commandId: commandId,
        documentId: documentId,
        title: title,
        blocks: <JsonMap>[
          <String, Object?>{
            'block_id': blockId,
            'type': 'paragraph',
            'payload': <String, Object?>{'text': text},
          },
        ],
        expectedRevision: expectedRevision,
      ),
    );
    _replaceDocument(saved);
    notifyListeners();
    return saved;
  }

  Future<void> addAttachmentFromPath(
    String sourcePath, {
    String mediaType = 'application/octet-stream',
  }) async {
    await flushPendingChanges();
    final JsonMap? document = selectedDocument;
    if (document == null) {
      throw StateError('Select a document first.');
    }
    if (!isSelectedWorkspaceWritable) {
      throw StateError('Archived workspace is read-only.');
    }
    final File source = File(sourcePath.trim()).absolute;
    if (!await source.exists()) {
      throw const LocalApiException(
        code: 'InvalidArgument',
        message: 'Указанный файл не найден.',
        retryable: false,
      );
    }
    final int size = await source.length();
    final JsonMap staged = await _withReconnect(
      (EndlessLocalApi client) => client.stageAttachment(
        bytes: source.openRead(),
        fileName: _baseName(source.path),
        mediaType: mediaType,
        contentLength: size,
      ),
    );
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.attachStagedFile(
        commandId: commandId,
        documentId: requireString(document, 'document_id'),
        stagingToken: requireString(staged, 'token'),
        expectedDocumentRevision: requireInt(document, 'revision'),
      ),
    );
    await _loadAttachments();
    notifyListeners();
  }

  Future<void> downloadAttachmentToPath(
    String attachmentId,
    String targetPath,
  ) async {
    final File target = File(targetPath.trim()).absolute;
    if (await target.exists()) {
      throw const LocalApiException(
        code: 'InvalidArgument',
        message: 'Файл назначения уже существует.',
        retryable: false,
      );
    }
    final AttachmentDownload download = await _withReconnect(
      (EndlessLocalApi client) => client.downloadAttachment(attachmentId),
    );
    final IOSink output = target.openWrite(mode: FileMode.writeOnly);
    bool closed = false;
    try {
      await output.addStream(download.bytes);
      await output.flush();
      await output.close();
      closed = true;
    } on Object {
      if (!closed) {
        try {
          await output.close();
        } on Object {
          // Preserve the transfer failure; the partial target is removed below.
        }
      }
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteAttachment(String attachmentId) async {
    if (!isSelectedWorkspaceWritable) {
      throw StateError('Archived workspace is read-only.');
    }
    final JsonMap attachment = attachments.firstWhere(
      (JsonMap candidate) => candidate['attachment_id'] == attachmentId,
    );
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.deleteAttachment(
        commandId: commandId,
        attachmentId: attachmentId,
        expectedRevision: requireInt(attachment, 'revision'),
      ),
    );
    await _loadAttachments();
    notifyListeners();
  }

  Future<void> moveDocument({
    required String documentId,
    required String? parentId,
  }) async {
    if (documentId == selectedDocumentId) {
      await flushPendingChanges();
    }
    final JsonMap document = _documentById(documentId);
    final int position = activeDocuments
        .where(
          (JsonMap candidate) =>
              candidate['parent_id'] == parentId &&
              candidate['document_id'] != documentId,
        )
        .length;
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.moveDocument(
        commandId: commandId,
        documentId: documentId,
        parentId: parentId,
        position: position,
        expectedRevision: requireInt(document, 'revision'),
      ),
    );
    await _loadDocuments();
    await _refreshSearch();
    selectedDocumentId = documentId;
    notifyListeners();
  }

  Future<void> deleteSelectedDocument() async {
    final JsonMap? document = selectedDocument;
    if (document == null) {
      return;
    }
    await deleteDocument(requireString(document, 'document_id'));
  }

  Future<void> deleteDocument(String documentId) async {
    await flushPendingChanges();
    final JsonMap document = _documentById(documentId);
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.deleteDocument(
        commandId: commandId,
        documentId: documentId,
        expectedRevision: requireInt(document, 'revision'),
      ),
    );
    if (selectedDocumentId == documentId ||
        !activeDocuments.any(
          (JsonMap candidate) => candidate['document_id'] == selectedDocumentId,
        )) {
      selectedDocumentId = null;
    }
    await _loadDocuments();
    await _refreshSearch();
    notifyListeners();
  }

  Future<void> restoreDocument(String documentId) async {
    final JsonMap document = _documentById(documentId);
    final String commandId = _commandId();
    await _withReconnect(
      (EndlessLocalApi client) => client.restoreDocument(
        commandId: commandId,
        documentId: documentId,
        expectedRevision: requireInt(document, 'revision'),
      ),
    );
    await _loadDocuments();
    await _refreshSearch();
    notifyListeners();
  }

  Future<void> search(String query) async {
    final int request = ++_searchRequest;
    final String normalized = query.trim();
    searchQuery = normalized;
    searchError = null;
    if (normalized.isEmpty || selectedWorkspaceId == null) {
      searchResults = <JsonMap>[];
      searching = false;
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    try {
      await flushPendingChanges();
      final List<JsonMap> results = await _withReconnect(
        (EndlessLocalApi client) => client.searchDocuments(
          workspaceId: selectedWorkspaceId!,
          query: normalized,
        ),
      );
      if (request != _searchRequest) {
        return;
      }
      searchResults = results;
    } on LocalApiException catch (error) {
      if (request != _searchRequest) {
        return;
      }
      searchResults = <JsonMap>[];
      searchError = error.message;
    } on Object {
      if (request != _searchRequest) {
        return;
      }
      searchResults = <JsonMap>[];
      searchError = 'Не удалось выполнить локальный поиск.';
    } finally {
      if (request == _searchRequest) {
        searching = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadSelectedDocument() async {
    final String? documentId = selectedDocumentId;
    if (documentId == null) {
      return;
    }
    final JsonMap document = await _withReconnect(
      (EndlessLocalApi client) => client.getDocument(documentId),
    );
    _replaceDocument(document);
    notifyListeners();
  }

  JsonMap _documentById(String documentId) {
    for (final JsonMap document in documents) {
      if (document['document_id'] == documentId) {
        return document;
      }
    }
    throw StateError('Document is not loaded.');
  }

  void _replaceDocument(JsonMap document) {
    final String documentId = requireString(document, 'document_id');
    final int index = documents.indexWhere(
      (JsonMap candidate) => candidate['document_id'] == documentId,
    );
    if (index >= 0) {
      documents[index] = document;
    }
  }

  Future<void> _refreshSearch() async {
    if (searchQuery.isNotEmpty) {
      await search(searchQuery);
    }
  }

  void _clearSearchState() {
    _searchRequest += 1;
    searchQuery = '';
    searchResults = <JsonMap>[];
    searchError = null;
    searching = false;
  }

  Future<T> _withReconnect<T>(
    Future<T> Function(EndlessLocalApi client) operation,
  ) async {
    try {
      return await operation(_requireClient());
    } on LocalApiException catch (error) {
      if (!_isAvailabilityError(error)) {
        rethrow;
      }
      reconnecting = true;
      notifyListeners();
      try {
        await _client?.close();
        _client = await _bootstrap();
        return await operation(_requireClient());
      } finally {
        reconnecting = false;
        notifyListeners();
      }
    }
  }

  static bool _isAvailabilityError(LocalApiException error) =>
      error.retryable &&
      <String>{
        'LocaldUnavailable',
        'LocaldStarting',
        'DeadlineExceeded',
        'StorageBusy',
      }.contains(error.code);

  EndlessLocalApi _requireClient() {
    final EndlessLocalApi? client = _client;
    if (client == null) {
      throw StateError('Local API is not connected.');
    }
    return client;
  }

  static String _commandId() {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(18);
    for (int index = 0; index < bytes.length; index++) {
      bytes[index] = random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;

  @override
  void dispose() {
    _editorOwner = null;
    _flushEditor = null;
    final EndlessLocalApi? client = _client;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }
}
