import 'dart:io';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:persistence_isar/persistence_isar.dart';
import 'package:test/test.dart';

void main() {
  test(
    'durable command survives close and cold reopen',
    () async {
      final Directory temporary = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
        'isar-${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporary.create(recursive: true);
      addTearDown(() async {
        if (await temporary.exists()) {
          await temporary.delete(recursive: true);
        }
      });

      IsarClientStore store = await IsarClientStore.open(
        directory: temporary.path,
        nativeLibraryPath:
            '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
        allowDevelopmentDownload: true,
        instanceName: 'persistence-test',
      );
      ClientApplicationService service = ClientApplicationService(
        store: store,
        clock: const _TestClock(),
        ids: _TestIds(),
      );
      final CommandReceipt created = await service.createWorkspace(
        commandId: 'durable-workspace',
        name: 'Offline',
      );
      final String workspaceId = created.result['workspace_id']! as String;
      final CommandReceipt document = await service.createDocument(
        commandId: 'durable-document',
        workspaceId: workspaceId,
        title: 'Searchable note',
      );
      await service.saveDocument(
        commandId: 'durable-save',
        documentId: document.result['document_id']! as String,
        title: 'Searchable note',
        blocks: const <BlockDraft>[
          BlockDraft(
            type: BlockType.paragraph,
            payload: <String, Object?>{'text': 'survives cold restart'},
          ),
        ],
        expectedRevision: 1,
      );
      await store.close();

      store = await IsarClientStore.open(
        directory: temporary.path,
        nativeLibraryPath:
            '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
        allowDevelopmentDownload: true,
        instanceName: 'persistence-test',
      );
      service = ClientApplicationService(
        store: store,
        clock: const _TestClock(),
        ids: _TestIds(),
      );
      addTearDown(store.close);

      expect((await service.getWorkspace(workspaceId)).name, 'Offline');
      final CommandReceipt replay = await service.createWorkspace(
        commandId: 'durable-workspace',
        name: 'Offline',
      );
      expect(replay.wasReplay, isTrue);
      expect(replay.result['workspace_id'], workspaceId);
      expect(await service.listWorkspaces(), hasLength(1));
      final List<SearchHit> search = await service.searchDocuments(
        workspaceId: workspaceId,
        query: 'cold restart',
      );
      expect(search, hasLength(1));
      expect(search.single.title, 'Searchable note');
      expect((await service.getSearchStatus()).isCurrent, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

final class _TestClock implements Clock {
  const _TestClock();

  @override
  DateTime now() => DateTime.utc(2026, 1, 1);
}

final class _TestIds implements IdGenerator {
  int _next = 0;

  @override
  String nextId() => 'test-${++_next}';
}
