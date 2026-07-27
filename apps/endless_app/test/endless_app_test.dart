import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:codex_app_server/codex_app_server.dart';
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

  testWidgets('flushes pending text before a desktop exit request', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Перед выходом');
    final String documentId = controller.selectedDocumentId!;
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Сохранить при выходе');
    final AppExitResponse response = await tester.binding
        .handleRequestAppExit();
    await tester.pumpAndSettle();

    expect(response, AppExitResponse.exit);
    expect(api.savedTextByDocument[documentId], 'Сохранить при выходе');
  });

  testWidgets('cancels a desktop exit when pending state cannot commit', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    final Object failingEditor = Object();
    controller.attachEditor(
      failingEditor,
      () async => throw StateError('local commit failed'),
    );

    final AppExitResponse response = await tester.binding
        .handleRequestAppExit();

    expect(response, AppExitResponse.cancel);
    controller.detachEditor(failingEditor);
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

  testWidgets('archives workspace as read-only and restores or deletes it', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Заметка');

    await controller.setSelectedWorkspaceArchived(true);
    await tester.pumpAndSettle();
    expect(controller.isSelectedWorkspaceWritable, isFalse);
    expect(find.text('Личное (архив)'), findsOneWidget);
    expect(find.text('Только чтение'), findsOneWidget);

    await controller.renameSelectedWorkspace('Справочник');
    await controller.setSelectedWorkspaceArchived(false);
    await tester.pumpAndSettle();
    expect(controller.isSelectedWorkspaceWritable, isTrue);
    expect(find.text('Справочник'), findsOneWidget);

    await controller.deleteSelectedWorkspace();
    await tester.pumpAndSettle();
    expect(controller.workspaces, isEmpty);
    expect(controller.documents, isEmpty);
    expect(api._documents.single['is_deleted'], isTrue);
    expect(find.text('Создайте локальное пространство'), findsOneWidget);
  });

  testWidgets('adds, downloads, and deletes a managed attachment', (
    WidgetTester tester,
  ) async {
    late Directory temporary;
    late File source;
    late File downloaded;
    await tester.runAsync(() async {
      temporary = await Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
        'widget-attachment-${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      source = File('${temporary.path}${Platform.pathSeparator}offline.txt');
      downloaded = File(
        '${temporary.path}${Platform.pathSeparator}downloaded.txt',
      );
      await source.writeAsString('available without a server', flush: true);
    });
    addTearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });
    final _FakeLocalApi api = _FakeLocalApi();
    final AppController controller = AppController(bootstrap: () async => api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('С файлами');

    await tester.runAsync(
      () => controller.addAttachmentFromPath(
        source.path,
        mediaType: 'text/plain',
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.attachments, hasLength(1));
    expect(find.text('offline.txt'), findsOneWidget);
    expect(find.byTooltip('Сохранить вложение'), findsOneWidget);
    final String attachmentId = requireString(
      controller.attachments.single,
      'attachment_id',
    );
    await tester.runAsync(
      () => controller.downloadAttachmentToPath(attachmentId, downloaded.path),
    );
    expect(
      await tester.runAsync(downloaded.readAsString),
      'available without a server',
    );

    await tester.tap(find.byTooltip('Удалить вложение'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(controller.attachments, isEmpty);
    expect(find.text('Нет вложений'), findsOneWidget);
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

  testWidgets('applies and undoes an AI document replacement', (
    WidgetTester tester,
  ) async {
    final _FakeLocalApi api = _FakeLocalApi();
    final _FakeDocumentAi ai = _FakeDocumentAi();
    final AppController controller = AppController(
      bootstrap: () async => api,
      documentAi: ai,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(EndlessApp(controller: controller));
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Черновик', documentType: 'adr');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI-помощник'));
    await tester.pumpAndSettle();
    expect(find.text('Codex готов'), findsOneWidget);

    controller.acceptAiDisclosure();
    await controller.runDocumentAi('Сформируй ADR');
    await tester.pumpAndSettle();

    expect(controller.selectedDocument!['title'], 'ADR: Решение');
    expect(
      api.savedTextByDocument[controller.selectedDocumentId],
      '## Context\nКонтекст решения.',
    );
    expect(controller.canUndoAiEdit, isTrue);

    await controller.undoAiEdit();
    await tester.pumpAndSettle();

    expect(controller.selectedDocument!['title'], 'Черновик');
    expect(api.savedTextByDocument[controller.selectedDocumentId], '');
  });

  test('does not apply an AI result over a newer manual revision', () async {
    final _FakeLocalApi api = _FakeLocalApi();
    final _BlockingDocumentAi ai = _BlockingDocumentAi();
    final AppController controller = AppController(
      bootstrap: () async => api,
      documentAi: ai,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.createWorkspace('Личное');
    await controller.createDocument('Черновик', documentType: 'adr');
    controller.acceptAiDisclosure();

    final Future<void> aiRun = controller.runDocumentAi('Обнови');
    await ai.started.future;
    final JsonMap source = controller.selectedDocument!;
    await controller.saveDocument(
      documentId: requireString(source, 'document_id'),
      title: 'Ручная версия',
      text: 'Пользовательский текст',
      expectedRevision: requireInt(source, 'revision'),
    );
    ai.complete();
    await aiRun;

    expect(controller.selectedDocument!['title'], 'Ручная версия');
    expect(controller.aiError, contains('Документ изменился'));
  });
}

class _FakeDocumentAi implements DocumentAi {
  @override
  Future<void> cancel() async {}

  @override
  Future<DocumentAiAvailability> checkAvailability() async =>
      DocumentAiAvailability.ready;

  @override
  Future<void> close() async {}

  @override
  Future<void> reset() async {}

  @override
  Future<DocumentAiResult> run({
    required DocumentAiSnapshot snapshot,
    required String instruction,
  }) async => const DocumentAiResult(
    action: DocumentAiAction.replaceDocument,
    message: 'Документ обновлён.',
    questions: <String>[],
    title: 'ADR: Решение',
    content: '## Context\nКонтекст решения.',
  );
}

final class _BlockingDocumentAi extends _FakeDocumentAi {
  final Completer<void> started = Completer<void>();
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<DocumentAiResult> run({
    required DocumentAiSnapshot snapshot,
    required String instruction,
  }) async {
    started.complete();
    await _release.future;
    return super.run(snapshot: snapshot, instruction: instruction);
  }
}

final class _FakeLocalApi implements EndlessLocalApi {
  final List<JsonMap> _workspaces = <JsonMap>[];
  final List<JsonMap> _documents = <JsonMap>[];
  final List<JsonMap> _attachments = <JsonMap>[];
  final Map<String, List<int>> _attachmentBytes = <String, List<int>>{};
  final Map<String, JsonMap> _stagedAttachments = <String, JsonMap>{};
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
  Future<JsonMap> getWorkspace(String workspaceId) async =>
      _workspaces.firstWhere(
        (JsonMap workspace) => workspace['workspace_id'] == workspaceId,
      );

  @override
  Future<JsonMap> renameWorkspace({
    required String commandId,
    required String workspaceId,
    required String name,
    int? expectedRevision,
  }) async {
    final int index = _workspaces.indexWhere(
      (JsonMap workspace) => workspace['workspace_id'] == workspaceId,
    );
    final JsonMap renamed = <String, Object?>{
      ..._workspaces[index],
      'name': name,
      'revision': requireInt(_workspaces[index], 'revision') + 1,
    };
    _workspaces[index] = renamed;
    return renamed;
  }

  @override
  Future<JsonMap> archiveWorkspace({
    required String commandId,
    required String workspaceId,
    required bool archived,
    int? expectedRevision,
  }) async {
    final int index = _workspaces.indexWhere(
      (JsonMap workspace) => workspace['workspace_id'] == workspaceId,
    );
    final JsonMap changed = <String, Object?>{
      ..._workspaces[index],
      'lifecycle': archived ? 'archived' : 'active',
      'revision': requireInt(_workspaces[index], 'revision') + 1,
    };
    _workspaces[index] = changed;
    return changed;
  }

  @override
  Future<JsonMap> deleteWorkspace({
    required String commandId,
    required String workspaceId,
    int? expectedRevision,
  }) async {
    final int index = _workspaces.indexWhere(
      (JsonMap workspace) => workspace['workspace_id'] == workspaceId,
    );
    final JsonMap deleted = <String, Object?>{
      ..._workspaces[index],
      'lifecycle': 'deleted',
      'revision': requireInt(_workspaces[index], 'revision') + 1,
    };
    _workspaces[index] = deleted;
    for (
      int documentIndex = 0;
      documentIndex < _documents.length;
      documentIndex++
    ) {
      if (_documents[documentIndex]['workspace_id'] == workspaceId) {
        _documents[documentIndex] = <String, Object?>{
          ..._documents[documentIndex],
          'is_deleted': true,
          'revision': requireInt(_documents[documentIndex], 'revision') + 1,
        };
      }
    }
    return deleted;
  }

  @override
  Future<JsonMap> createDocument({
    required String commandId,
    required String workspaceId,
    required String title,
    String? parentId,
    String documentType = 'plain',
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
      'document_type': documentType,
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
    String? documentType,
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
      'document_type':
          documentType ?? _documents[index]['document_type'] ?? 'plain',
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
  Future<List<JsonMap>> listWorkspaces({bool includeArchived = false}) async =>
      _workspaces
          .where(
            (JsonMap workspace) =>
                workspace['lifecycle'] != 'deleted' &&
                (includeArchived || workspace['lifecycle'] == 'active'),
          )
          .map(Map<String, Object?>.of)
          .toList();

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
  Future<JsonMap> stageAttachment({
    required Stream<List<int>> bytes,
    required String fileName,
    required String mediaType,
    int? contentLength,
  }) async {
    final List<int> collected = await bytes
        .expand((List<int> chunk) => chunk)
        .toList();
    final String token = 'staging-token-${_stagedAttachments.length + 1}-xxxx';
    final JsonMap staged = <String, Object?>{
      'token': token,
      'file_name': fileName,
      'media_type': mediaType,
      'sha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'size': collected.length,
      'bytes': collected,
    };
    _stagedAttachments[token] = staged;
    return staged;
  }

  @override
  Future<JsonMap> attachStagedFile({
    required String commandId,
    required String documentId,
    required String stagingToken,
    int? expectedDocumentRevision,
  }) async {
    final JsonMap staged = _stagedAttachments[stagingToken]!;
    final String id = 'attachment-${_attachments.length + 1}';
    final JsonMap document = await getDocument(documentId);
    final JsonMap attachment = <String, Object?>{
      'attachment_id': id,
      'workspace_id': document['workspace_id'],
      'document_id': documentId,
      'file_name': staged['file_name'],
      'media_type': staged['media_type'],
      'sha256': staged['sha256'],
      'size': staged['size'],
      'revision': 1,
      'is_deleted': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    _attachments.add(attachment);
    _attachmentBytes[id] = List<int>.of(staged['bytes']! as List<int>);
    return attachment;
  }

  @override
  Future<List<JsonMap>> listAttachments({
    required String documentId,
    bool includeDeleted = false,
  }) async => _attachments
      .where(
        (JsonMap attachment) =>
            attachment['document_id'] == documentId &&
            (includeDeleted || attachment['is_deleted'] != true),
      )
      .map(Map<String, Object?>.of)
      .toList();

  @override
  Future<JsonMap> getAttachment(String attachmentId) async =>
      _attachments.firstWhere(
        (JsonMap attachment) => attachment['attachment_id'] == attachmentId,
      );

  @override
  Future<AttachmentDownload> downloadAttachment(String attachmentId) async {
    final JsonMap attachment = await getAttachment(attachmentId);
    final List<int> bytes = _attachmentBytes[attachmentId]!;
    return AttachmentDownload(
      attachmentId: attachmentId,
      fileName: requireString(attachment, 'file_name'),
      mediaType: requireString(attachment, 'media_type'),
      sha256: requireString(attachment, 'sha256'),
      size: bytes.length,
      bytes: Stream<List<int>>.value(bytes),
    );
  }

  @override
  Future<JsonMap> deleteAttachment({
    required String commandId,
    required String attachmentId,
    int? expectedRevision,
  }) async {
    final int index = _attachments.indexWhere(
      (JsonMap attachment) => attachment['attachment_id'] == attachmentId,
    );
    final JsonMap deleted = <String, Object?>{
      ..._attachments[index],
      'is_deleted': true,
      'revision': requireInt(_attachments[index], 'revision') + 1,
    };
    _attachments[index] = deleted;
    return deleted;
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

  @override
  Future<ProfileBackupDownload> exportBackup() async =>
      ProfileBackupDownload(size: 1, bytes: Stream<List<int>>.value(<int>[0]));

  @override
  Future<JsonMap> restoreBackup({
    required Stream<List<int>> bytes,
    int? contentLength,
  }) async {
    await bytes.drain<void>();
    return <String, Object?>{'format_version': 2};
  }

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
