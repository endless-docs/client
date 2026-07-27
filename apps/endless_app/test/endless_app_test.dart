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
    await tester.enterText(find.byType(TextField), 'Личное');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Личное'), findsOneWidget);

    await tester.tap(find.byTooltip('Новый документ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Заметка');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Заметка'), findsWidgets);
    final Finder editorFields = find.byType(TextField);
    await tester.enterText(editorFields.last, 'Работает без сервера');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(api.savedText, 'Работает без сервера');
    expect(find.text('Сохранено локально'), findsOneWidget);
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
  String? savedText;

  @override
  Future<JsonMap> createWorkspace({
    required String commandId,
    required String name,
  }) async {
    final JsonMap workspace = <String, Object?>{
      'workspace_id': 'workspace-1',
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
    final JsonMap document = <String, Object?>{
      'document_id': 'document-1',
      'workspace_id': workspaceId,
      'title': title,
      'parent_id': parentId,
      'position': 0,
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
    savedText = requireMap(blocks.single, 'payload')['text'] as String?;
    final JsonMap saved = <String, Object?>{
      ..._documents.single,
      'title': title,
      'blocks': <JsonMap>[
        <String, Object?>{
          ...blocks.single,
          'block_id': 'block-1',
          'document_id': documentId,
          'position': 0,
          'revision': 1,
        },
      ],
      'revision': 2,
    };
    _documents[0] = saved;
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
    _documents.clear();
    return <String, Object?>{'document_id': documentId, 'is_deleted': true};
  }

  @override
  Future<JsonMap> getDocument(String documentId) async => _documents.single;

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
  }) async => List<JsonMap>.from(_documents);

  @override
  Future<List<JsonMap>> listWorkspaces() async =>
      List<JsonMap>.from(_workspaces);

  @override
  Future<JsonMap> restoreDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) async => throw UnimplementedError();
}
