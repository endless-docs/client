import 'dart:convert';
import 'dart:io';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:isar_community/isar.dart';
import 'package:persistence_isar/persistence_isar.dart';
import 'package:test/test.dart';

import 'fixtures/schema_v1.dart' as v1;
import 'fixtures/schema_v2.dart' as v2;

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

  test(
    'schema v1 fixture migrates and repairs search projection',
    _verifySchemaV1Migration,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'schema v2 fixture opens with empty attachment collections',
    _verifySchemaV2Migration,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final IsarWriteStep step in <IsarWriteStep>[
    IsarWriteStep.documentRecord,
    IsarWriteStep.blockDelete,
    IsarWriteStep.blockPut,
    IsarWriteStep.searchProjectionPut,
    IsarWriteStep.eventSequence,
    IsarWriteStep.searchCheckpoint,
    IsarWriteStep.operationRecord,
    IsarWriteStep.commandOutcome,
  ]) {
    test(
      'document command rolls back at ${step.name}',
      () => _verifyDocumentRollback(step),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  for (final IsarWriteStep step in <IsarWriteStep>[
    IsarWriteStep.attachmentRecord,
    IsarWriteStep.attachmentCommitMarker,
    IsarWriteStep.eventSequence,
    IsarWriteStep.searchCheckpoint,
    IsarWriteStep.operationRecord,
    IsarWriteStep.commandOutcome,
  ]) {
    test(
      'attachment command rolls back at ${step.name}',
      () => _verifyAttachmentRollback(step),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  test(
    'attachment marker completion is durably retryable',
    _verifyAttachmentCompletionRetry,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'workspace record failure rolls back rename',
    _verifyWorkspaceRollback,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'search projection delete failure rolls back tombstone',
    _verifySearchDeleteRollback,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final IsarWriteStep step in <IsarWriteStep>[
    IsarWriteStep.searchProjectionReplace,
    IsarWriteStep.searchProjectionReplacePut,
  ]) {
    test(
      'search rebuild rolls back at ${step.name}',
      () => _verifySearchRebuildRollback(step),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

Future<void> _verifySchemaV1Migration() async {
  final Directory temporary = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
    'migration-v1-${DateTime.now().microsecondsSinceEpoch}',
  );
  final Directory bootstrap = Directory(
    '${temporary.path}${Platform.pathSeparator}bootstrap',
  );
  final Directory profile = Directory(
    '${temporary.path}${Platform.pathSeparator}profile',
  );
  await temporary.create(recursive: true);
  await profile.create(recursive: true);
  IsarClientStore? currentStore;
  try {
    final IsarClientStore bootstrapStore = await IsarClientStore.open(
      directory: bootstrap.path,
      nativeLibraryPath:
          '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
          '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
      allowDevelopmentDownload: true,
      instanceName: 'migration-bootstrap',
    );
    await bootstrapStore.close();

    final Isar legacy = await Isar.open(
      <CollectionSchema<Object>>[
        v1.WorkspaceRecordSchema,
        v1.DocumentRecordSchema,
        v1.BlockRecordSchema,
        v1.RuntimeStateRecordSchema,
      ],
      directory: profile.path,
      name: 'migration-fixture',
      relaxedDurability: false,
      inspector: false,
    );
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    await legacy.writeTxn(() async {
      await legacy.collection<v1.WorkspaceRecord>().put(
        v1.WorkspaceRecord()
          ..workspaceId = 'legacy-workspace'
          ..name = 'Legacy'
          ..lifecycle = 'active'
          ..revision = 1
          ..createdAt = createdAt
          ..updatedAt = createdAt,
      );
      await legacy.collection<v1.DocumentRecord>().put(
        v1.DocumentRecord()
          ..documentId = 'legacy-document'
          ..workspaceId = 'legacy-workspace'
          ..parentId = null
          ..title = 'Migrated note'
          ..position = 0
          ..revision = 1
          ..isDeleted = false
          ..createdAt = createdAt
          ..updatedAt = createdAt,
      );
      await legacy.collection<v1.BlockRecord>().put(
        v1.BlockRecord()
          ..blockId = 'legacy-block'
          ..documentId = 'legacy-document'
          ..type = 'paragraph'
          ..payloadJson = jsonEncode(<String, Object?>{
            'text': 'legacy searchable payload',
          })
          ..position = 0
          ..revision = 1,
      );
      await legacy.collection<v1.RuntimeStateRecord>().put(
        v1.RuntimeStateRecord()..eventSequence = 3,
      );
    });
    await legacy.close();

    currentStore = await IsarClientStore.open(
      directory: profile.path,
      nativeLibraryPath:
          '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
          '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
      allowDevelopmentDownload: true,
      instanceName: 'migration-fixture',
    );
    final ClientApplicationService service = ClientApplicationService(
      store: currentStore,
      clock: const _TestClock(),
      ids: _TestIds(),
    );
    final SearchStatus migrated = await service.getSearchStatus();
    expect(migrated.eventSequence, 3);
    expect(migrated.indexedSequence, 0);
    expect(migrated.isCurrent, isFalse);

    final SearchStatus repaired = await service.ensureSearchIndex();
    expect(repaired.isCurrent, isTrue);
    expect(repaired.documentCount, 1);
    expect((await service.getWorkspace('legacy-workspace')).name, 'Legacy');
    final Document document = await service.getDocument('legacy-document');
    expect(document.blocks.single.payload['text'], 'legacy searchable payload');
    expect(
      await service.searchDocuments(
        workspaceId: 'legacy-workspace',
        query: 'searchable',
      ),
      hasLength(1),
    );
  } finally {
    await currentStore?.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  }
}

Future<void> _verifySchemaV2Migration() async {
  final Directory temporary = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
    'migration-v2-${DateTime.now().microsecondsSinceEpoch}',
  );
  final Directory bootstrap = Directory(
    '${temporary.path}${Platform.pathSeparator}bootstrap',
  );
  final Directory profile = Directory(
    '${temporary.path}${Platform.pathSeparator}profile',
  );
  await temporary.create(recursive: true);
  await profile.create(recursive: true);
  IsarClientStore? currentStore;
  try {
    final IsarClientStore bootstrapStore = await IsarClientStore.open(
      directory: bootstrap.path,
      nativeLibraryPath:
          '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
          '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
      allowDevelopmentDownload: true,
      instanceName: 'migration-v2-bootstrap',
    );
    await bootstrapStore.close();

    final Isar legacy = await Isar.open(
      <CollectionSchema<Object>>[
        v2.WorkspaceRecordSchema,
        v2.DocumentRecordSchema,
        v2.BlockRecordSchema,
        v2.CommandOutcomeRecordSchema,
        v2.OperationRecordSchema,
        v2.SearchProjectionRecordSchema,
        v2.RuntimeStateRecordSchema,
      ],
      directory: profile.path,
      name: 'migration-v2-fixture',
      relaxedDurability: false,
      inspector: false,
    );
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    await legacy.writeTxn(() async {
      await legacy.collection<v2.WorkspaceRecord>().put(
        v2.WorkspaceRecord()
          ..workspaceId = 'v2-workspace'
          ..name = 'Before attachments'
          ..lifecycle = 'active'
          ..revision = 1
          ..createdAt = createdAt
          ..updatedAt = createdAt,
      );
      await legacy.collection<v2.DocumentRecord>().put(
        v2.DocumentRecord()
          ..documentId = 'v2-document'
          ..workspaceId = 'v2-workspace'
          ..parentId = null
          ..title = 'Existing note'
          ..position = 0
          ..revision = 1
          ..isDeleted = false
          ..createdAt = createdAt
          ..updatedAt = createdAt,
      );
      await legacy.collection<v2.SearchProjectionRecord>().put(
        v2.SearchProjectionRecord()
          ..documentId = 'v2-document'
          ..workspaceId = 'v2-workspace'
          ..title = 'Existing note'
          ..content = ''
          ..normalizedText = 'existing note'
          ..revision = 1,
      );
      await legacy.collection<v2.RuntimeStateRecord>().put(
        v2.RuntimeStateRecord()
          ..eventSequence = 2
          ..searchIndexedSequence = 2,
      );
    });
    await legacy.close();

    currentStore = await IsarClientStore.open(
      directory: profile.path,
      nativeLibraryPath:
          '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
          '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
      allowDevelopmentDownload: true,
      instanceName: 'migration-v2-fixture',
    );
    final ClientApplicationService service = ClientApplicationService(
      store: currentStore,
      clock: const _TestClock(),
      ids: _TestIds(),
    );

    expect(
      (await service.getWorkspace('v2-workspace')).name,
      'Before attachments',
    );
    expect((await service.getDocument('v2-document')).title, 'Existing note');
    expect((await service.getSearchStatus()).isCurrent, isTrue);
    expect(await service.listAttachments('v2-document'), isEmpty);
    expect(await service.pendingAttachmentCommits(), isEmpty);
  } finally {
    await currentStore?.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  }
}

Future<void> _verifyAttachmentRollback(IsarWriteStep step) async {
  final _StoreFixture fixture = await _StoreFixture.open(
    'attachment-${step.name}',
  );
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Atomic',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    final CommandReceipt document = await fixture.service.createDocument(
      commandId: 'document',
      workspaceId: workspaceId,
      title: 'With attachment',
    );
    final String documentId = document.result['document_id']! as String;
    fixture.injector.arm(step);

    await expectLater(
      fixture.service.attachStagedFile(
        commandId: 'attach',
        documentId: documentId,
        staged: _stagedDraft,
        expectedDocumentRevision: 1,
      ),
      throwsStateError,
    );

    expect(await fixture.service.pendingAttachmentCommits(), isEmpty);
    expect(await fixture.service.listAttachments(documentId), isEmpty);
    expect(
      await fixture.store.read(
        (ClientStoreReader reader) => reader.getCommandOutcome('attach'),
      ),
      isNull,
    );

    fixture.injector.disarm();
    final CommandReceipt attached = await fixture.service.attachStagedFile(
      commandId: 'attach',
      documentId: documentId,
      staged: _stagedDraft,
      expectedDocumentRevision: 1,
    );
    final AttachmentCommitMarker marker =
        (await fixture.service.pendingAttachmentCommits()).single;
    await fixture.service.completeAttachmentCommit(marker);
    await fixture.reopen();

    expect(await fixture.service.listAttachments(documentId), hasLength(1));
    expect(
      (await fixture.service.attachStagedFile(
        commandId: 'attach',
        documentId: documentId,
        staged: _stagedDraft,
        expectedDocumentRevision: 1,
      )).result['attachment_id'],
      attached.result['attachment_id'],
    );
  } finally {
    await fixture.dispose();
  }
}

Future<void> _verifyAttachmentCompletionRetry() async {
  final _StoreFixture fixture = await _StoreFixture.open(
    'attachment-completion',
  );
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Atomic',
    );
    final CommandReceipt document = await fixture.service.createDocument(
      commandId: 'document',
      workspaceId: workspace.result['workspace_id']! as String,
      title: 'With attachment',
    );
    final String documentId = document.result['document_id']! as String;
    await fixture.service.attachStagedFile(
      commandId: 'attach',
      documentId: documentId,
      staged: _stagedDraft,
    );
    final AttachmentCommitMarker marker =
        (await fixture.service.pendingAttachmentCommits()).single;
    fixture.injector.arm(IsarWriteStep.attachmentCommitMarkerDelete);

    await expectLater(
      fixture.service.completeAttachmentCommit(marker),
      throwsStateError,
    );
    expect(await fixture.service.pendingAttachmentCommits(), hasLength(1));
    fixture.injector.disarm();
    await fixture.service.completeAttachmentCommit(marker);
    await fixture.reopen();

    expect(await fixture.service.pendingAttachmentCommits(), isEmpty);
    expect(await fixture.service.listAttachments(documentId), hasLength(1));
  } finally {
    await fixture.dispose();
  }
}

const StagedAttachmentDraft _stagedDraft = StagedAttachmentDraft(
  stagingToken: 'abcdefghijklmnopqrstuvwx',
  fileName: 'notes.txt',
  mediaType: 'text/plain',
  sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  size: 12,
);

Future<void> _verifyDocumentRollback(IsarWriteStep step) async {
  final _StoreFixture fixture = await _StoreFixture.open(
    'document-${step.name}',
  );
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Atomic',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    final SearchStatus before = await fixture.service.getSearchStatus();
    fixture.injector.arm(step);

    await expectLater(
      fixture.service.createDocument(
        commandId: 'fault-command',
        workspaceId: workspaceId,
        title: 'Atomic note',
      ),
      throwsStateError,
    );

    expect(await fixture.service.listDocuments(workspaceId), isEmpty);
    final SearchStatus after = await fixture.service.getSearchStatus();
    expect(after.eventSequence, before.eventSequence);
    expect(after.indexedSequence, before.indexedSequence);
    expect(
      await fixture.store.read(
        (ClientStoreReader reader) => reader.getCommandOutcome('fault-command'),
      ),
      isNull,
    );

    fixture.injector.disarm();
    await fixture.service.createDocument(
      commandId: 'fault-command',
      workspaceId: workspaceId,
      title: 'Atomic note',
    );
    await fixture.reopen();
    expect(await fixture.service.listDocuments(workspaceId), hasLength(1));
    expect(
      (await fixture.service.createDocument(
        commandId: 'fault-command',
        workspaceId: workspaceId,
        title: 'Atomic note',
      )).wasReplay,
      isTrue,
    );
  } finally {
    await fixture.dispose();
  }
}

Future<void> _verifyWorkspaceRollback() async {
  final _StoreFixture fixture = await _StoreFixture.open('workspace-record');
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Before',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    fixture.injector.arm(IsarWriteStep.workspaceRecord);
    await expectLater(
      fixture.service.renameWorkspace(
        commandId: 'rename',
        workspaceId: workspaceId,
        name: 'After',
        expectedRevision: 1,
      ),
      throwsStateError,
    );
    expect((await fixture.service.getWorkspace(workspaceId)).name, 'Before');
    fixture.injector.disarm();
    expect(
      (await fixture.service.renameWorkspace(
        commandId: 'rename',
        workspaceId: workspaceId,
        name: 'After',
        expectedRevision: 1,
      )).result['name'],
      'After',
    );
  } finally {
    await fixture.dispose();
  }
}

Future<void> _verifySearchDeleteRollback() async {
  final _StoreFixture fixture = await _StoreFixture.open('search-delete');
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Atomic',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    final CommandReceipt document = await fixture.service.createDocument(
      commandId: 'document',
      workspaceId: workspaceId,
      title: 'Needle',
    );
    final String documentId = document.result['document_id']! as String;
    fixture.injector.arm(IsarWriteStep.searchProjectionDelete);
    await expectLater(
      fixture.service.deleteDocument(
        commandId: 'delete',
        documentId: documentId,
        expectedRevision: 1,
      ),
      throwsStateError,
    );
    expect((await fixture.service.getDocument(documentId)).isDeleted, isFalse);
    expect(
      await fixture.service.searchDocuments(
        workspaceId: workspaceId,
        query: 'Needle',
      ),
      hasLength(1),
    );
  } finally {
    await fixture.dispose();
  }
}

Future<void> _verifySearchRebuildRollback(IsarWriteStep step) async {
  final _StoreFixture fixture = await _StoreFixture.open(
    'rebuild-${step.name}',
  );
  try {
    final CommandReceipt workspace = await fixture.service.createWorkspace(
      commandId: 'workspace',
      name: 'Atomic',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    await fixture.service.createDocument(
      commandId: 'document',
      workspaceId: workspaceId,
      title: 'Needle',
    );
    fixture.injector.arm(step);
    await expectLater(
      fixture.service.rebuildSearchIndex(commandId: 'rebuild'),
      throwsStateError,
    );
    expect(
      await fixture.service.searchDocuments(
        workspaceId: workspaceId,
        query: 'Needle',
      ),
      hasLength(1),
    );
    expect(
      await fixture.store.read(
        (ClientStoreReader reader) => reader.getCommandOutcome('rebuild'),
      ),
      isNull,
    );
  } finally {
    await fixture.dispose();
  }
}

final class _StoreFixture {
  _StoreFixture._({
    required this.directory,
    required this.instanceName,
    required this.injector,
    required this.store,
    required this.service,
  });

  final Directory directory;
  final String instanceName;
  final _FailOnceInjector injector;
  IsarClientStore store;
  ClientApplicationService service;

  static Future<_StoreFixture> open(String suffix) async {
    final Directory directory = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
      'fault-$suffix-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    final String instanceName = 'fault-$suffix';
    final _FailOnceInjector injector = _FailOnceInjector();
    final IsarClientStore store = await _openStore(
      directory,
      instanceName,
      injector,
    );
    return _StoreFixture._(
      directory: directory,
      instanceName: instanceName,
      injector: injector,
      store: store,
      service: ClientApplicationService(
        store: store,
        clock: const _TestClock(),
        ids: _TestIds(),
      ),
    );
  }

  Future<void> reopen() async {
    await store.close();
    store = await _openStore(directory, instanceName, injector);
    service = ClientApplicationService(
      store: store,
      clock: const _TestClock(),
      ids: _TestIds(),
    );
  }

  Future<void> dispose() async {
    await store.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<IsarClientStore> _openStore(
    Directory directory,
    String instanceName,
    _FailOnceInjector injector,
  ) => IsarClientStore.open(
    directory: directory.path,
    nativeLibraryPath:
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
    allowDevelopmentDownload: true,
    instanceName: instanceName,
    faultInjector: injector.call,
  );
}

final class _FailOnceInjector {
  IsarWriteStep? _armed;

  void arm(IsarWriteStep step) => _armed = step;

  void disarm() => _armed = null;

  void call(IsarWriteStep step) {
    if (_armed == step) {
      _armed = null;
      throw StateError('Injected failure at ${step.name}.');
    }
  }
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
