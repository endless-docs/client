import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:codex_app_server/codex_app_server.dart';
import 'package:flutter/foundation.dart';
import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';
import 'package:platform_runtime/platform_runtime.dart';

enum AppPhase { starting, ready, failed }

enum AiMessageRole { user, assistant }

final class AiConversationMessage {
  const AiConversationMessage({required this.role, required this.text});

  final AiMessageRole role;
  final String text;
}

typedef LocalApiBootstrap = Future<EndlessLocalApi> Function();

final class DocumentTreeEntry {
  const DocumentTreeEntry({required this.document, required this.depth});

  final JsonMap document;
  final int depth;
}

final class AppController extends ChangeNotifier {
  AppController({required LocalApiBootstrap bootstrap, DocumentAi? documentAi})
    : _bootstrap = bootstrap,
      _documentAi = documentAi;

  factory AppController.production() => AppController(
    documentAi: CodexDocumentAi(),
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
  final DocumentAi? _documentAi;
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
  List<AiConversationMessage> aiMessages = <AiConversationMessage>[];
  String? selectedWorkspaceId;
  String? selectedDocumentId;
  DocumentAiAvailability aiAvailability = DocumentAiAvailability.unknown;
  String? aiError;
  bool aiPanelOpen = false;
  bool aiChecking = false;
  bool aiRunning = false;
  _AiUndoSnapshot? _aiUndo;
  int _searchRequest = 0;

  bool get hasSearch => searchQuery.isNotEmpty;
  bool get canUndoAiEdit => _aiUndo != null;

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
    await _resetAiSession();
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
    await _resetAiSession();
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
    await _resetAiSession();
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

  Future<void> createDocument(
    String title, {
    String? parentId,
    String documentType = 'plain',
  }) async {
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
        documentType: documentType,
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
    String? documentType,
    bool preserveAiUndo = false,
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
        documentType: documentType,
        expectedRevision: expectedRevision,
      ),
    );
    _replaceDocument(saved);
    if (!preserveAiUndo) {
      _aiUndo = null;
    }
    notifyListeners();
    return saved;
  }

  Future<List<JsonMap>> listSelectedDocumentVersions() async {
    await flushPendingChanges();
    final String? documentId = selectedDocumentId;
    if (documentId == null) {
      return const <JsonMap>[];
    }
    return _withReconnect(
      (EndlessLocalApi client) => client.listDocumentVersions(documentId),
    );
  }

  Future<void> restoreDocumentVersion(JsonMap version) async {
    await flushPendingChanges();
    final JsonMap? document = selectedDocument;
    if (document == null) {
      throw StateError('Select a document first.');
    }
    if (!isSelectedWorkspaceWritable) {
      throw StateError('Archived workspace is read-only.');
    }
    await saveDocument(
      documentId: requireString(document, 'document_id'),
      title: requireString(version, 'title'),
      text: requireString(version, 'content'),
      expectedRevision: requireInt(document, 'revision'),
      blockId: _documentBlockId(document),
      documentType: requireString(version, 'document_type'),
    );
  }

  Future<void> setSelectedDocumentType(String documentType) async {
    if (!const <String>{
      'plain',
      'adr',
      'business_need',
      'rfc',
    }.contains(documentType)) {
      throw ArgumentError.value(documentType, 'documentType');
    }
    await flushPendingChanges();
    final JsonMap? document = selectedDocument;
    if (document == null || !isSelectedWorkspaceWritable) {
      return;
    }
    try {
      await _documentAi?.reset();
    } on CodexException {
      // AI is optional: a failed child process must not block local metadata.
    }
    aiMessages = <AiConversationMessage>[];
    await saveDocument(
      documentId: requireString(document, 'document_id'),
      title: requireString(document, 'title'),
      text: _documentText(document),
      expectedRevision: requireInt(document, 'revision'),
      blockId: _documentBlockId(document),
      documentType: documentType,
    );
  }

  Future<void> setAiPanelOpen(bool open) async {
    aiPanelOpen = open;
    notifyListeners();
    if (open && aiAvailability == DocumentAiAvailability.unknown) {
      await checkAiAvailability();
    }
  }

  Future<void> checkAiAvailability() async {
    final DocumentAi? ai = _documentAi;
    if (ai == null) {
      aiAvailability = DocumentAiAvailability.missing;
      notifyListeners();
      return;
    }
    aiChecking = true;
    aiError = null;
    notifyListeners();
    try {
      aiAvailability = await ai.checkAvailability();
    } on Object {
      aiAvailability = DocumentAiAvailability.unavailable;
    } finally {
      aiChecking = false;
      notifyListeners();
    }
  }

  Future<void> runDocumentAi(String instruction) async {
    final DocumentAi? ai = _documentAi;
    if (ai == null) {
      aiAvailability = DocumentAiAvailability.missing;
      notifyListeners();
      return;
    }
    if (!isSelectedWorkspaceWritable) {
      throw StateError('Archived workspace is read-only.');
    }
    await flushPendingChanges();
    final JsonMap? source = selectedDocument;
    if (source == null) {
      return;
    }
    final String documentType = source['document_type'] as String? ?? 'plain';
    if (documentType == 'plain') {
      throw StateError('Select a document type first.');
    }
    final String documentId = requireString(source, 'document_id');
    final int sourceRevision = requireInt(source, 'revision');
    final String sourceTitle = requireString(source, 'title');
    final String sourceText = _documentText(source);
    final String? sourceBlockId = _documentBlockId(source);
    final String normalizedInstruction = instruction.trim();
    aiMessages = <AiConversationMessage>[
      ...aiMessages,
      AiConversationMessage(
        role: AiMessageRole.user,
        text: normalizedInstruction,
      ),
    ];
    aiRunning = true;
    aiError = null;
    _aiUndo = null;
    notifyListeners();
    try {
      final DocumentAiResult result = await ai.run(
        snapshot: DocumentAiSnapshot(
          documentType: documentType,
          title: sourceTitle,
          content: sourceText,
        ),
        instruction: normalizedInstruction,
      );
      final String assistantText = <String>[
        if (result.message.trim().isNotEmpty) result.message.trim(),
        for (final String question in result.questions) '• $question',
      ].join('\n');
      if (result.action == DocumentAiAction.replaceDocument) {
        await flushPendingChanges();
        final JsonMap? current = selectedDocument;
        if (current == null ||
            requireString(current, 'document_id') != documentId ||
            requireInt(current, 'revision') != sourceRevision ||
            (current['document_type'] as String? ?? 'plain') != documentType) {
          throw const CodexException(
            'AiResultStale',
            'Документ изменился. Повторите запрос для актуальной версии.',
          );
        }
        final JsonMap saved = await saveDocument(
          documentId: documentId,
          title: result.title!,
          text: result.content!,
          expectedRevision: sourceRevision,
          blockId: sourceBlockId,
          documentType: documentType,
          preserveAiUndo: true,
        );
        _aiUndo = _AiUndoSnapshot(
          documentId: documentId,
          documentType: documentType,
          title: sourceTitle,
          text: sourceText,
          blockId: sourceBlockId,
          appliedRevision: requireInt(saved, 'revision'),
        );
      }
      aiMessages = <AiConversationMessage>[
        ...aiMessages,
        AiConversationMessage(
          role: AiMessageRole.assistant,
          text: assistantText.isEmpty
              ? 'Codex завершил обработку документа.'
              : assistantText,
        ),
      ];
      aiAvailability = DocumentAiAvailability.ready;
    } on CodexException catch (error) {
      aiError = error.message;
      if (error.code == 'CodexAuthRequired') {
        aiAvailability = DocumentAiAvailability.authRequired;
      }
    } on LocalApiException catch (error) {
      aiError = error.code == 'RevisionConflict'
          ? 'Документ изменился. Повторите запрос для актуальной версии.'
          : error.message;
    } finally {
      aiRunning = false;
      notifyListeners();
    }
  }

  Future<void> cancelDocumentAi() async {
    try {
      await _documentAi?.cancel();
    } on CodexException catch (error) {
      aiError = error.message;
    }
  }

  Future<void> undoAiEdit() async {
    final _AiUndoSnapshot? undo = _aiUndo;
    if (undo == null) {
      return;
    }
    await flushPendingChanges();
    final JsonMap? current = selectedDocument;
    if (current == null ||
        requireString(current, 'document_id') != undo.documentId ||
        requireInt(current, 'revision') != undo.appliedRevision) {
      _aiUndo = null;
      aiError = 'Документ уже изменился, поэтому AI-правку нельзя отменить.';
      notifyListeners();
      return;
    }
    await saveDocument(
      documentId: undo.documentId,
      title: undo.title,
      text: undo.text,
      expectedRevision: undo.appliedRevision,
      blockId: undo.blockId,
      documentType: undo.documentType,
      preserveAiUndo: true,
    );
    _aiUndo = null;
    notifyListeners();
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

  Future<void> _resetAiSession() async {
    try {
      await _documentAi?.reset();
    } on CodexException {
      // Selection must remain available even if Codex has stopped.
    }
    aiMessages = <AiConversationMessage>[];
    aiError = null;
    aiRunning = false;
    _aiUndo = null;
  }

  static String _documentText(JsonMap document) {
    final List<JsonMap> blocks = requireMapList(document, 'blocks');
    if (blocks.isEmpty) {
      return '';
    }
    final Object? text = requireMap(blocks.first, 'payload')['text'];
    return text is String ? text : '';
  }

  static String? _documentBlockId(JsonMap document) {
    final List<JsonMap> blocks = requireMapList(document, 'blocks');
    return blocks.isEmpty ? null : blocks.first['block_id'] as String?;
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
    final DocumentAi? ai = _documentAi;
    if (ai != null) {
      unawaited(ai.close());
    }
    super.dispose();
  }
}

final class _AiUndoSnapshot {
  const _AiUndoSnapshot({
    required this.documentId,
    required this.documentType,
    required this.title,
    required this.text,
    required this.blockId,
    required this.appliedRevision,
  });

  final String documentId;
  final String documentType;
  final String title;
  final String text;
  final String? blockId;
  final int appliedRevision;
}
