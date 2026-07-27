import 'dart:async';

import 'package:endless_app/src/app_controller.dart';
import 'package:endless_app/src/endless_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';

void main() {
  testWidgets('creates and autosaves a document entirely through Local API', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));

    unawaited(controller.initialize());
    await tester.pumpAndSettle();
    expect(find.text('Создайте локальное пространство'), findsOneWidget);

    await tester.tap(find.text('Создать пространство'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Личное');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Личное'), findsOneWidget);

    await tester.tap(find.byTooltip('Новый документ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Заметка');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Заметка'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'Работает без сервера');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(api.savedTextByDocument['document-1'], 'Работает без сервера');
    expect(find.text('Сохранено локально'), findsOneWidget);
  });

  testWidgets('flushes pending text before document navigation', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Первый');
    final String firstId = controller.selectedDocumentId!;
    await controller.createDocument('Второй');
    final String secondId = controller.selectedDocumentId!;
    await controller.selectDocument(firstId);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Не потерять при переходе',
    );
    await tester.tap(find.text('Второй'));
    await tester.pumpAndSettle();

    expect(api.savedTextByDocument[firstId], 'Не потерять при переходе');
    expect(controller.selectedDocumentId, secondId);
  });

  testWidgets('renders a tree and restores documents from recycle bin', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Родитель');
    final String parentId = controller.selectedDocumentId!;
    await controller.createDocument('Дочерний', parentId: parentId);
    final String childId = controller.selectedDocumentId!;
    await tester.pumpAndSettle();

    expect(
      controller.documentTree.map((DocumentTreeEntry entry) => entry.depth),
      <int>[0, 1],
    );

    await controller.deleteDocument(parentId);
    await controller.setRecycleBin(true);
    await tester.pumpAndSettle();
    expect(controller.deletedDocuments, hasLength(2));
    expect(find.text('Родитель'), findsOneWidget);
    expect(find.text('Дочерний'), findsOneWidget);

    await controller.restoreDocument(parentId);
    await controller.restoreDocument(childId);
    await controller.setRecycleBin(false);
    await tester.pumpAndSettle();

    expect(controller.deletedDocuments, isEmpty);
    expect(
      controller.documentTree.map((DocumentTreeEntry entry) => entry.depth),
      <int>[0, 1],
    );
  });

  test('reconnect retries a mutation with the original command_id', () async {
    final _FakeLocalApi api = _FakeLocalApi();
    int bootstrapCalls = 0;
    final AppController controller = AppController(
      bootstrap: () async {
        bootstrapCalls += 1;
        return api;
      },
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Заметка');
    final JsonMap document = controller.selectedDocument!;
    api.failNextSave = true;

    await controller.saveDocument(
      documentId: requireString(document, 'document_id'),
      title: 'Заметка',
      text: 'После reconnect',
      expectedRevision: requireInt(document, 'revision'),
    );

    expect(api.saveCommandIds, hasLength(2));
    expect(api.saveCommandIds.toSet(), hasLength(1));
    expect(bootstrapCalls, 2);
  });

  testWidgets('finds an offline document and opens the result', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Полевые заметки');
    final JsonMap document = controller.selectedDocument!;
    await controller.saveDocument(
      documentId: requireString(document, 'document_id'),
      title: 'Полевые заметки',
      text: 'Автономная поисковая иголка',
      expectedRevision: requireInt(document, 'revision'),
    );

    await controller.search('иголка');
    await tester.pumpAndSettle();

    expect(controller.searchResults, hasLength(1));
    expect(find.text('Полевые заметки'), findsWidgets);
    expect(find.text('Автономная поисковая иголка'), findsWidgets);
    expect(find.byTooltip('Очистить поиск'), findsOneWidget);
  });

  testWidgets('shows a recoverable startup error', (WidgetTester tester) async {
    final AppController controller = AppController(
      bootstrap: () async => throw const LocalApiException(
        code: 'LocaldUnavailable',
        message: 'Локальный процесс не запустился.',
        retryable: true,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));

    unawaited(controller.initialize());
    await tester.pumpAndSettle();

    expect(find.text('Локальное хранилище недоступно'), findsOneWidget);
    expect(find.text('Локальный процесс не запустился.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });
}

final class _FakeLocalApi implements EndlessLocalApi {
  final List<JsonMap> _workspaces = <JsonMap>[];
  final List<JsonMap> _documents = <JsonMap>[];
  final Map<String, String> savedTextByDocument = <String, String>{};
  final List<String> saveCommandIds = <String>[];
  bool failNextSave = false;

  @override
  Future<JsonMap> createWorkspace({
    required String commandId,
    required String name,
  }) async {
    final String id = 'workspace-${_workspaces.length + 1}';
    final JsonMap workspace = <String, Object?>{
      'workspace_id': id,
      'name': name,
      'kind': 'local',
      'lifecycle': 'active',
      'revision': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    _workspaces.add(workspace);
    return workspace;
  }

  @override
  Future<JsonMap> createDocument({
    required String commandId,
    required String workspaceId,
    required String title,
    String? parentId,
  }) async {
    final String id = 'document-${_documents.length + 1}';
    final int position = _documents
        .where(
          (JsonMap document) =>
              document['workspace_id'] == workspaceId &&
              document['parent_id'] == parentId,
        )
        .length;
    final JsonMap document = <String, Object?>{
      'document_id': id,
      'workspace_id': workspaceId,
      'title': title,
      'parent_id': parentId,
      'position': position,
      'blocks': <JsonMap>[],
      'revision': 1,
      'is_deleted': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    _documents.add(document);
    return document;
  }

  @override
  Future<JsonMap> saveDocument({
    required String commandId,
    required String documentId,
    required String title,
    required List<JsonMap> blocks,
    int? expectedRevision,
  }) async {
    saveCommandIds.add(commandId);
    if (failNextSave) {
      failNextSave = false;
      throw const LocalApiException(
        code: 'LocaldUnavailable',
        message: 'Daemon restarted after commit.',
        retryable: true,
      );
    }
    final int index = _indexOf(documentId);
    savedTextByDocument[documentId] =
        requireMap(blocks.single, 'payload')['text']! as String;
    final JsonMap saved = <String, Object?>{
      ..._documents[index],
      'title': title,
      'blocks': <JsonMap>[
        <String, Object?>{
          ...blocks.single,
          'block_id': blocks.single['block_id'] ?? 'block-$documentId',
          'document_id': documentId,
          'position': 0,
          'revision': 1,
        },
      ],
      'revision': requireInt(_documents[index], 'revision') + 1,
      'updated_at': '2026-01-01T00:00:01Z',
    };
    _documents[index] = saved;
    return saved;
  }

  @override
  Future<void> close() async {}

  @override
  Future<JsonMap> deleteDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) async {
    final Set<String> affected = <String>{documentId};
    bool changed;
    do {
      changed = false;
      for (final JsonMap document in _documents) {
        final String id = requireString(document, 'document_id');
        if (!affected.contains(id) &&
            affected.contains(document['parent_id'])) {
          affected.add(id);
          changed = true;
        }
      }
    } while (changed);
    for (final String id in affected) {
      final int index = _indexOf(id);
      _documents[index] = <String, Object?>{
        ..._documents[index],
        'is_deleted': true,
        'revision': requireInt(_documents[index], 'revision') + 1,
        'updated_at': '2026-01-01T00:00:02Z',
      };
    }
    return _documents[_indexOf(documentId)];
  }

  @override
  Future<JsonMap> getDocument(String documentId) async =>
      _documents[_indexOf(documentId)];

  @override
  Future<JsonMap> handshake({
    required LocalClientType clientType,
    required String profileId,
  }) async => <String, Object?>{'compatibility': 'compatible'};

  @override
  Future<JsonMap> health() async => <String, Object?>{'status': 'ready'};

  @override
  Future<List<JsonMap>> listDocuments({
    required String workspaceId,
    bool includeDeleted = false,
  }) async => _documents
      .where(
        (JsonMap document) =>
            document['workspace_id'] == workspaceId &&
            (includeDeleted || document['is_deleted'] != true),
      )
      .map((JsonMap document) => Map<String, Object?>.of(document))
      .toList();

  @override
  Future<List<JsonMap>> listWorkspaces() async =>
      _workspaces.map(Map<String, Object?>.of).toList();

  @override
  Future<JsonMap> moveDocument({
    required String commandId,
    required String documentId,
    required String? parentId,
    required int position,
    int? expectedRevision,
  }) async {
    final int index = _indexOf(documentId);
    final JsonMap moved = <String, Object?>{
      ..._documents[index],
      'parent_id': parentId,
      'position': position,
      'revision': requireInt(_documents[index], 'revision') + 1,
    };
    _documents[index] = moved;
    return moved;
  }

  @override
  Future<JsonMap> restoreDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) async {
    final int index = _indexOf(documentId);
    final String? parentId = _documents[index]['parent_id'] as String?;
    if (parentId != null &&
        _documents[_indexOf(parentId)]['is_deleted'] == true) {
      throw const LocalApiException(
        code: 'InvalidParent',
        message: 'Restore the parent first.',
        retryable: false,
      );
    }
    final JsonMap restored = <String, Object?>{
      ..._documents[index],
      'is_deleted': false,
      'revision': requireInt(_documents[index], 'revision') + 1,
      'updated_at': '2026-01-01T00:00:03Z',
    };
    _documents[index] = restored;
    return restored;
  }

  @override
  Future<List<JsonMap>> searchDocuments({
    required String workspaceId,
    required String query,
    int limit = 50,
  }) async {
    final String normalized = query.toLowerCase();
    return _documents
        .where(
          (JsonMap document) =>
              document['workspace_id'] == workspaceId &&
              document['is_deleted'] != true &&
              '${document['title']} ${savedTextByDocument[document['document_id']] ?? ''}'
                  .toLowerCase()
                  .contains(normalized),
        )
        .take(limit)
        .map(
          (JsonMap document) => <String, Object?>{
            'document_id': document['document_id'],
            'workspace_id': workspaceId,
            'title': document['title'],
            'snippet': savedTextByDocument[document['document_id']] ?? '',
            'score': 1,
            'observed_revision': document['revision'],
            'indexed_sequence': 1,
          },
        )
        .toList();
  }

  @override
  Future<JsonMap> getSearchStatus() async => <String, Object?>{
    'event_sequence': 1,
    'indexed_sequence': 1,
    'document_count': _documents.length,
    'is_current': true,
  };

  @override
  Future<JsonMap> rebuildSearchIndex({required String commandId}) =>
      getSearchStatus();

  int _indexOf(String documentId) {
    final int index = _documents.indexWhere(
      (JsonMap document) => document['document_id'] == documentId,
    );
    if (index < 0) {
      throw StateError('Missing fake document $documentId.');
    }
    return index;
  }
}
