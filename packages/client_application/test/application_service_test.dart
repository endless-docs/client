import 'dart:async';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:test/test.dart';

void main() {
  late _MemoryStore store;
  late ClientApplicationService service;

  setUp(() {
    store = _MemoryStore();
    service = ClientApplicationService(
      store: store,
      clock: _FixedClock(),
      ids: _SequentialIds(),
    );
  });

  test('replaying command_id returns the durable outcome once', () async {
    final CommandReceipt first = await service.createWorkspace(
      commandId: 'command-1',
      name: 'Personal',
    );
    final CommandReceipt replay = await service.createWorkspace(
      commandId: 'command-1',
      name: 'Personal',
    );

    expect(first.wasReplay, isFalse);
    expect(replay.wasReplay, isTrue);
    expect(replay.result, first.result);
    expect(await service.listWorkspaces(), hasLength(1));
    expect(store.operations, hasLength(1));
  });

  test('reusing command_id with another fingerprint is rejected', () async {
    await service.createWorkspace(commandId: 'same', name: 'First');

    await expectLater(
      service.createWorkspace(commandId: 'same', name: 'Second'),
      throwsA(
        isA<ApplicationException>().having(
          (ApplicationException error) => error.code,
          'code',
          'CommandIdReused',
        ),
      ),
    );
    expect(await service.listWorkspaces(), hasLength(1));
  });

  test('revision conflict rolls back aggregate and operation', () async {
    final CommandReceipt workspace = await service.createWorkspace(
      commandId: 'workspace',
      name: 'Personal',
    );
    final CommandReceipt document = await service.createDocument(
      commandId: 'document',
      workspaceId: workspace.result['workspace_id']! as String,
      title: 'Draft',
    );
    final String documentId = document.result['document_id']! as String;

    await expectLater(
      service.saveDocument(
        commandId: 'save-conflict',
        documentId: documentId,
        title: 'Changed',
        blocks: const <BlockDraft>[],
        expectedRevision: 99,
      ),
      throwsA(
        isA<ApplicationException>().having(
          (ApplicationException error) => error.code,
          'code',
          'RevisionConflict',
        ),
      ),
    );

    expect((await service.getDocument(documentId)).title, 'Draft');
    expect(store.outcomes.containsKey('save-conflict'), isFalse);
    expect(store.operations, hasLength(2));
  });

  test('moving a document under its descendant is rejected', () async {
    final CommandReceipt workspace = await service.createWorkspace(
      commandId: 'workspace',
      name: 'Personal',
    );
    final String workspaceId = workspace.result['workspace_id']! as String;
    final CommandReceipt parent = await service.createDocument(
      commandId: 'parent',
      workspaceId: workspaceId,
      title: 'Parent',
    );
    final String parentId = parent.result['document_id']! as String;
    final CommandReceipt child = await service.createDocument(
      commandId: 'child',
      workspaceId: workspaceId,
      title: 'Child',
      parentId: parentId,
    );

    await expectLater(
      service.moveDocument(
        commandId: 'cycle',
        documentId: parentId,
        parentId: child.result['document_id']! as String,
        position: 0,
      ),
      throwsA(
        isA<ApplicationException>().having(
          (ApplicationException error) => error.code,
          'code',
          'InvalidParent',
        ),
      ),
    );
  });
}

final class _FixedClock implements Clock {
  DateTime _value = DateTime.utc(2026, 1, 1);

  @override
  DateTime now() {
    final DateTime result = _value;
    _value = _value.add(const Duration(seconds: 1));
    return result;
  }
}

final class _SequentialIds implements IdGenerator {
  int _value = 0;

  @override
  String nextId() => 'id-${++_value}';
}

final class _MemoryStore implements ClientStore {
  Map<String, Workspace> workspaces = <String, Workspace>{};
  Map<String, Document> documents = <String, Document>{};
  Map<String, CommandOutcome> outcomes = <String, CommandOutcome>{};
  List<Operation> operations = <Operation>[];
  int sequence = 0;

  @override
  Future<T> read<T>(
    FutureOr<T> Function(ClientStoreReader reader) operation,
  ) async => operation(_MemoryTransaction(this));

  @override
  Future<T> write<T>(
    FutureOr<T> Function(ClientStoreWriter writer) operation,
  ) async {
    final _MemoryStore snapshot = _copy();
    try {
      return await operation(_MemoryTransaction(this));
    } on Object {
      workspaces = snapshot.workspaces;
      documents = snapshot.documents;
      outcomes = snapshot.outcomes;
      operations = snapshot.operations;
      sequence = snapshot.sequence;
      rethrow;
    }
  }

  _MemoryStore _copy() => _MemoryStore()
    ..workspaces = Map<String, Workspace>.of(workspaces)
    ..documents = Map<String, Document>.of(documents)
    ..outcomes = Map<String, CommandOutcome>.of(outcomes)
    ..operations = List<Operation>.of(operations)
    ..sequence = sequence;
}

final class _MemoryTransaction implements ClientStoreWriter {
  const _MemoryTransaction(this.store);

  final _MemoryStore store;

  @override
  Future<void> appendOperation(Operation operation) async {
    store.operations.add(operation);
  }

  @override
  Future<CommandOutcome?> getCommandOutcome(String commandId) async =>
      store.outcomes[commandId];

  @override
  Future<Document?> getDocument(String documentId) async =>
      store.documents[documentId];

  @override
  Future<Workspace?> getWorkspace(String workspaceId) async =>
      store.workspaces[workspaceId];

  @override
  Future<List<Document>> listDocuments(
    String workspaceId, {
    bool includeDeleted = false,
  }) async => store.documents.values
      .where(
        (Document document) =>
            document.workspaceId == workspaceId &&
            (includeDeleted || !document.isDeleted),
      )
      .toList();

  @override
  Future<List<Workspace>> listWorkspaces({
    bool includeArchived = false,
  }) async => store.workspaces.values
      .where(
        (Workspace workspace) =>
            workspace.lifecycle != WorkspaceLifecycle.deleted &&
            (includeArchived ||
                workspace.lifecycle == WorkspaceLifecycle.active),
      )
      .toList();

  @override
  Future<int> nextEventSequence() async => ++store.sequence;

  @override
  Future<void> putCommandOutcome(CommandOutcome outcome) async {
    store.outcomes[outcome.commandId] = outcome;
  }

  @override
  Future<void> putDocument(Document document) async {
    store.documents[document.id] = document;
  }

  @override
  Future<void> putWorkspace(Workspace workspace) async {
    store.workspaces[workspace.id] = workspace;
  }
}
