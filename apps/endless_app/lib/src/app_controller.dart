import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';
import 'package:platform_runtime/platform_runtime.dart';

enum AppPhase { starting, ready, failed }

typedef LocalApiBootstrap = Future<EndlessLocalApi> Function();

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

  AppPhase phase = AppPhase.starting;
  String? errorMessage;
  List<JsonMap> workspaces = <JsonMap>[];
  List<JsonMap> documents = <JsonMap>[];
  String? selectedWorkspaceId;
  String? selectedDocumentId;

  JsonMap? get selectedDocument {
    final String? id = selectedDocumentId;
    if (id == null) {
      return null;
    }
    for (final JsonMap document in documents) {
      if (document['document_id'] == id) {
        return document;
      }
    }
    return null;
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

  Future<void> _loadWorkspaces() async {
    workspaces = await _requireClient().listWorkspaces();
    if (workspaces.isEmpty) {
      selectedWorkspaceId = null;
      selectedDocumentId = null;
      documents = <JsonMap>[];
      return;
    }
    final bool selectedStillExists = workspaces.any(
      (JsonMap workspace) => workspace['workspace_id'] == selectedWorkspaceId,
    );
    selectedWorkspaceId = selectedStillExists
        ? selectedWorkspaceId
        : requireString(workspaces.first, 'workspace_id');
    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final String? workspaceId = selectedWorkspaceId;
    if (workspaceId == null) {
      documents = <JsonMap>[];
      selectedDocumentId = null;
      return;
    }
    documents = await _requireClient().listDocuments(workspaceId: workspaceId);
    final bool selectedStillExists = documents.any(
      (JsonMap document) => document['document_id'] == selectedDocumentId,
    );
    selectedDocumentId = selectedStillExists
        ? selectedDocumentId
        : documents.isEmpty
        ? null
        : requireString(documents.first, 'document_id');
  }

  Future<void> selectWorkspace(String workspaceId) async {
    selectedWorkspaceId = workspaceId;
    selectedDocumentId = null;
    await _loadDocuments();
    notifyListeners();
  }

  void selectDocument(String documentId) {
    selectedDocumentId = documentId;
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    final JsonMap created = await _requireClient().createWorkspace(
      commandId: _commandId(),
      name: name,
    );
    await _loadWorkspaces();
    selectedWorkspaceId = requireString(created, 'workspace_id');
    await _loadDocuments();
    notifyListeners();
  }

  Future<void> createDocument(String title) async {
    final String? workspaceId = selectedWorkspaceId;
    if (workspaceId == null) {
      throw StateError('Select a workspace first.');
    }
    final JsonMap created = await _requireClient().createDocument(
      commandId: _commandId(),
      workspaceId: workspaceId,
      title: title,
    );
    await _loadDocuments();
    selectedDocumentId = requireString(created, 'document_id');
    notifyListeners();
  }

  Future<JsonMap> saveDocument({
    required String documentId,
    required String title,
    required String text,
    required int expectedRevision,
    String? blockId,
  }) async {
    final JsonMap saved = await _requireClient().saveDocument(
      commandId: _commandId(),
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
    );
    final int index = documents.indexWhere(
      (JsonMap document) => document['document_id'] == documentId,
    );
    if (index >= 0) {
      documents[index] = saved;
      notifyListeners();
    }
    return saved;
  }

  Future<void> deleteSelectedDocument() async {
    final JsonMap? document = selectedDocument;
    if (document == null) {
      return;
    }
    await _requireClient().deleteDocument(
      commandId: _commandId(),
      documentId: requireString(document, 'document_id'),
      expectedRevision: requireInt(document, 'revision'),
    );
    selectedDocumentId = null;
    await _loadDocuments();
    notifyListeners();
  }

  Future<void> reloadSelectedDocument() async {
    final String? documentId = selectedDocumentId;
    if (documentId == null) {
      return;
    }
    final JsonMap document = await _requireClient().getDocument(documentId);
    final int index = documents.indexWhere(
      (JsonMap candidate) => candidate['document_id'] == documentId,
    );
    if (index >= 0) {
      documents[index] = document;
    }
    notifyListeners();
  }

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

  @override
  void dispose() {
    final EndlessLocalApi? client = _client;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }
}
