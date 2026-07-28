import 'dart:async';
import 'dart:convert';

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

  test(
    'document type is created and updated with content atomically',
    () async {
      final CommandReceipt workspace = await service.createWorkspace(
        commandId: 'typed-workspace',
        name: 'Architecture',
      );
      final CommandReceipt created = await service.createDocument(
        commandId: 'typed-document',
        workspaceId: workspace.result['workspace_id']! as String,
        title: 'Decision',
        documentType: DocumentType.adr,
      );
      final String documentId = created.result['document_id']! as String;

      expect(created.result['document_type'], 'adr');
      final CommandReceipt saved = await service.saveDocument(
        commandId: 'typed-save',
        documentId: documentId,
        title: 'Proposal',
        blocks: const <BlockDraft>[],
        documentType: DocumentType.rfc,
        expectedRevision: created.result['revision']! as int,
      );

      expect(saved.result['document_type'], 'rfc');
      expect(
        (await service.getDocument(documentId)).documentType,
        DocumentType.rfc,
      );
    },
  );

  test('document versions project durable full-text history', () async {
    final CommandReceipt workspace = await service.createWorkspace(
      commandId: 'versions-workspace',
      name: 'Writing',
    );
    final CommandReceipt created = await service.createDocument(
      commandId: 'versions-document',
      workspaceId: workspace.result['workspace_id']! as String,
      title: 'Draft',
      documentType: DocumentType.adr,
    );
    final String documentId = created.result['document_id']! as String;
    final CommandReceipt second = await service.saveDocument(
      commandId: 'versions-save-2',
      documentId: documentId,
      title: 'Decision',
      blocks: const <BlockDraft>[
        BlockDraft(
          type: BlockType.paragraph,
          payload: <String, Object?>{'text': '# First'},
        ),
      ],
      expectedRevision: 1,
    );
    await service.saveDocument(
      commandId: 'versions-save-3',
      documentId: documentId,
      title: 'Decision final',
      blocks: const <BlockDraft>[
        BlockDraft(
          type: BlockType.paragraph,
          payload: <String, Object?>{'text': '# Final'},
        ),
      ],
      documentType: DocumentType.rfc,
      expectedRevision: second.result['revision']! as int,
    );

    final List<DocumentVersion> versions = await service.listDocumentVersions(
      documentId,
    );

    expect(versions.map((DocumentVersion version) => version.revision), <int>[
      3,
      2,
      1,
    ]);
    expect(versions.first.content, '# Final');
    expect(versions.first.documentType, DocumentType.rfc);
    expect(versions.first.isCurrent, isTrue);
    expect(versions[1].content, '# First');
    expect(versions[1].documentType, DocumentType.adr);
    expect(versions.last.title, 'Draft');
    expect(versions.last.content, isEmpty);
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

  test(
    'workspace archive is read-only and delete tombstones local data',
    () async {
      final CommandReceipt workspace = await service.createWorkspace(
        commandId: 'workspace',
        name: 'Personal',
      );
      final String workspaceId = workspace.result['workspace_id']! as String;
      final CommandReceipt document = await service.createDocument(
        commandId: 'document',
        workspaceId: workspaceId,
        title: 'Local note',
      );
      final String documentId = document.result['document_id']! as String;

      final CommandReceipt archived = await service.archiveWorkspace(
        commandId: 'archive',
        workspaceId: workspaceId,
        archived: true,
        expectedRevision: 1,
      );
      expect(archived.result['lifecycle'], 'archived');
      expect(await service.listWorkspaces(), isEmpty);
      expect(await service.listWorkspaces(includeArchived: true), hasLength(1));
      await expectLater(
        service.createDocument(
          commandId: 'create-in-archive',
          workspaceId: workspaceId,
          title: 'Rejected',
        ),
        throwsA(
          isA<ApplicationException>().having(
            (ApplicationException error) => error.code,
            'code',
            'WorkspaceNotFound',
          ),
        ),
      );
      await expectLater(
        service.saveDocument(
          commandId: 'edit-in-archive',
          documentId: documentId,
          title: 'Rejected',
          blocks: const <BlockDraft>[],
          expectedRevision: 1,
        ),
        throwsA(
          isA<ApplicationException>().having(
            (ApplicationException error) => error.code,
            'code',
            'WorkspaceNotFound',
          ),
        ),
      );

      final CommandReceipt renamed = await service.renameWorkspace(
        commandId: 'rename-archive',
        workspaceId: workspaceId,
        name: 'Reference',
        expectedRevision: 2,
      );
      final CommandReceipt restored = await service.archiveWorkspace(
        commandId: 'restore-archive',
        workspaceId: workspaceId,
        archived: false,
        expectedRevision: renamed.result['revision']! as int,
      );
      expect(restored.result['lifecycle'], 'active');

      final CommandReceipt deleted = await service.deleteWorkspace(
        commandId: 'delete-workspace',
        workspaceId: workspaceId,
        expectedRevision: restored.result['revision']! as int,
      );
      expect(deleted.result['lifecycle'], 'deleted');
      expect(deleted.result['affected_document_ids'], <String>[documentId]);
      expect(store.documents[documentId]!.isDeleted, isTrue);
      expect(store.searchProjections, isEmpty);
      expect(await service.listWorkspaces(includeArchived: true), isEmpty);
      expect(
        (await service.deleteWorkspace(
          commandId: 'delete-workspace',
          workspaceId: workspaceId,
          expectedRevision: restored.result['revision']! as int,
        )).wasReplay,
        isTrue,
      );
    },
  );

  test(
    'deleting a parent tombstones its subtree and restores in order',
    () async {
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
      final String childId = child.result['document_id']! as String;

      final CommandReceipt deleted = await service.deleteDocument(
        commandId: 'delete-tree',
        documentId: parentId,
        expectedRevision: 1,
      );

      expect(
        deleted.result['affected_document_ids'],
        containsAll(<String>[parentId, childId]),
      );
      expect(
        await service.listDocuments(workspaceId, includeDeleted: true),
        everyElement(
          isA<Document>().having(
            (Document document) => document.isDeleted,
            'isDeleted',
            isTrue,
          ),
        ),
      );
      await expectLater(
        service.restoreDocument(
          commandId: 'restore-child-too-early',
          documentId: childId,
        ),
        throwsA(
          isA<ApplicationException>().having(
            (ApplicationException error) => error.code,
            'code',
            'InvalidParent',
          ),
        ),
      );

      await service.restoreDocument(
        commandId: 'restore-parent',
        documentId: parentId,
      );
      await service.restoreDocument(
        commandId: 'restore-child',
        documentId: childId,
      );

      expect(await service.listDocuments(workspaceId), hasLength(2));
    },
  );

  test(
    'search projection follows update, delete, restore, and rebuild',
    () async {
      final CommandReceipt workspace = await service.createWorkspace(
        commandId: 'workspace',
        name: 'Personal',
      );
      final String workspaceId = workspace.result['workspace_id']! as String;
      final CommandReceipt created = await service.createDocument(
        commandId: 'document',
        workspaceId: workspaceId,
        title: 'Field notes',
      );
      final String documentId = created.result['document_id']! as String;

      await service.saveDocument(
        commandId: 'save',
        documentId: documentId,
        title: 'Field notes',
        blocks: const <BlockDraft>[
          BlockDraft(
            type: BlockType.paragraph,
            payload: <String, Object?>{'text': 'Offline search needle'},
          ),
        ],
        expectedRevision: 1,
      );
      expect(
        await service.searchDocuments(
          workspaceId: workspaceId,
          query: 'needle',
        ),
        hasLength(1),
      );

      await service.deleteDocument(
        commandId: 'delete',
        documentId: documentId,
        expectedRevision: 2,
      );
      expect(
        await service.searchDocuments(
          workspaceId: workspaceId,
          query: 'needle',
        ),
        isEmpty,
      );
      await service.restoreDocument(
        commandId: 'restore',
        documentId: documentId,
        expectedRevision: 3,
      );
      expect(
        await service.searchDocuments(
          workspaceId: workspaceId,
          query: 'needle',
        ),
        hasLength(1),
      );

      store.searchProjections.clear();
      final CommandReceipt rebuilt = await service.rebuildSearchIndex(
        commandId: 'rebuild',
      );
      expect(rebuilt.result['is_current'], isTrue);
      expect(rebuilt.result['document_count'], 1);
      expect(
        await service.searchDocuments(
          workspaceId: workspaceId,
          query: 'needle',
        ),
        hasLength(1),
      );
      expect(
        (await service.rebuildSearchIndex(commandId: 'rebuild')).wasReplay,
        isTrue,
      );

      store.searchProjections.clear();
      store.searchIndexedSequence = 0;
      final SearchStatus repaired = await service.ensureSearchIndex();
      expect(repaired.isCurrent, isTrue);
      expect(repaired.documentCount, 1);
    },
  );

  test(
    'attachment metadata stays hidden until commit marker is completed',
    () async {
      final CommandReceipt workspace = await service.createWorkspace(
        commandId: 'workspace',
        name: 'Personal',
      );
      final String workspaceId = workspace.result['workspace_id']! as String;
      final CommandReceipt document = await service.createDocument(
        commandId: 'document',
        workspaceId: workspaceId,
        title: 'With file',
      );
      final String documentId = document.result['document_id']! as String;
      const StagedAttachmentDraft staged = StagedAttachmentDraft(
        stagingToken: 'abcdefghijklmnopqrstuvwx',
        fileName: ' notes.txt ',
        mediaType: 'Text/Plain',
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        size: 12,
      );

      final CommandReceipt attached = await service.attachStagedFile(
        commandId: 'attach',
        documentId: documentId,
        staged: staged,
        expectedDocumentRevision: 1,
      );
      final String attachmentId = attached.result['attachment_id']! as String;
      final AttachmentCommitMarker marker =
          (await service.pendingAttachmentCommits()).single;

      expect(await service.listAttachments(documentId), isEmpty);
      expect(marker.attachmentId, attachmentId);
      expect(attached.result['file_name'], 'notes.txt');
      expect(attached.result['media_type'], 'text/plain');
      await service.completeAttachmentCommit(marker);

      expect(await service.listAttachments(documentId), hasLength(1));
      expect((await service.getAttachment(attachmentId)).size, 12);
      expect(
        (await service.attachStagedFile(
          commandId: 'attach',
          documentId: documentId,
          staged: staged,
          expectedDocumentRevision: 1,
        )).wasReplay,
        isTrue,
      );

      final CommandReceipt deleted = await service.deleteAttachment(
        commandId: 'delete-attachment',
        attachmentId: attachmentId,
        expectedRevision: 1,
      );
      expect(deleted.result['is_deleted'], isTrue);
      expect(await service.listAttachments(documentId), isEmpty);
      expect(
        await service.listAttachments(documentId, includeDeleted: true),
        hasLength(1),
      );
    },
  );

  test('attachment marker and metadata roll back with command failure', () async {
    final CommandReceipt workspace = await service.createWorkspace(
      commandId: 'workspace',
      name: 'Personal',
    );
    final CommandReceipt document = await service.createDocument(
      commandId: 'document',
      workspaceId: workspace.result['workspace_id']! as String,
      title: 'With file',
    );
    store.failAfterAttachmentMarker = true;

    await expectLater(
      service.attachStagedFile(
        commandId: 'attach',
        documentId: document.result['document_id']! as String,
        staged: const StagedAttachmentDraft(
          stagingToken: 'abcdefghijklmnopqrstuvwx',
          fileName: 'notes.txt',
          mediaType: 'text/plain',
          sha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          size: 12,
        ),
      ),
      throwsStateError,
    );

    expect(store.attachments, isEmpty);
    expect(store.attachmentMarkers, isEmpty);
    expect(store.outcomes.containsKey('attach'), isFalse);
  });

  test(
    'backup snapshot round-trips tombstones, history, outcomes, and search',
    () async {
      final CommandReceipt workspace = await service.createWorkspace(
        commandId: 'workspace',
        name: 'Portable',
      );
      final String workspaceId = workspace.result['workspace_id']! as String;
      final CommandReceipt document = await service.createDocument(
        commandId: 'document',
        workspaceId: workspaceId,
        title: 'Offline source',
        documentType: DocumentType.businessNeed,
      );
      final String documentId = document.result['document_id']! as String;
      await service.saveDocument(
        commandId: 'save-document',
        documentId: documentId,
        title: 'Offline source',
        blocks: const <BlockDraft>[
          BlockDraft(
            type: BlockType.paragraph,
            payload: <String, Object?>{'text': 'restored searchable content'},
          ),
        ],
      );
      final CommandReceipt attached = await service.attachStagedFile(
        commandId: 'attach',
        documentId: documentId,
        staged: const StagedAttachmentDraft(
          stagingToken: 'abcdefghijklmnopqrstuvwx',
          fileName: 'portable.txt',
          mediaType: 'text/plain',
          sha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          size: 12,
        ),
      );
      await service.completeAttachmentCommit(
        (await service.pendingAttachmentCommits()).single,
      );
      await service.deleteAttachment(
        commandId: 'delete-attachment',
        attachmentId: attached.result['attachment_id']! as String,
      );
      await service.archiveWorkspace(
        commandId: 'archive',
        workspaceId: workspaceId,
        archived: true,
      );

      final ClientBackupSnapshot original = await service
          .createBackupSnapshot();
      final ClientBackupSnapshot decoded = ClientBackupSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );
      expect(decoded.documents.single.documentType, DocumentType.businessNeed);
      final Map<String, Object?> legacyJson =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>;
      legacyJson['format_version'] = 1;
      for (final Map<String, Object?> document
          in (legacyJson['documents']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        document.remove('document_type');
      }
      expect(
        ClientBackupSnapshot.fromJson(legacyJson).documents.single.documentType,
        DocumentType.plain,
      );
      final _MemoryStore restoredStore = _MemoryStore();
      final ClientApplicationService restored = ClientApplicationService(
        store: restoredStore,
        clock: _FixedClock(),
        ids: _SequentialIds(),
      );
      await restored.restoreBackupSnapshot(decoded);

      expect(restoredStore.sequence, original.eventSequence);
      expect(restoredStore.operations, hasLength(original.operations.length));
      expect(
        restoredStore.outcomes,
        hasLength(original.commandOutcomes.length),
      );
      expect(restoredStore.searchIndexedSequence, original.eventSequence);
      expect(
        await restored.listWorkspaces(includeArchived: true),
        hasLength(1),
      );
      expect(
        await restored.searchDocuments(
          workspaceId: workspaceId,
          query: 'searchable',
        ),
        hasLength(1),
      );
      expect(
        await restored.listAttachments(documentId, includeDeleted: true),
        hasLength(1),
      );
      expect(
        (await restored.createWorkspace(
          commandId: 'workspace',
          name: 'Portable',
        )).wasReplay,
        isTrue,
      );
      await expectLater(
        restored.restoreBackupSnapshot(decoded),
        throwsA(
          isA<ApplicationException>().having(
            (ApplicationException error) => error.code,
            'code',
            'RestoreTargetNotEmpty',
          ),
        ),
      );
    },
  );

  test('backup snapshot rejects cyclic document trees', () {
    final DateTime now = DateTime.utc(2026, 1, 1);
    expect(
      () => ClientBackupSnapshot(
        exportedAt: now,
        eventSequence: 0,
        workspaces: <Workspace>[
          Workspace(
            id: 'workspace',
            name: 'Invalid',
            lifecycle: WorkspaceLifecycle.active,
            revision: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        documents: <Document>[
          Document(
            id: 'first',
            workspaceId: 'workspace',
            title: 'First',
            parentId: 'second',
            position: 0,
            blocks: const <Block>[],
            revision: 1,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
          ),
          Document(
            id: 'second',
            workspaceId: 'workspace',
            title: 'Second',
            parentId: 'first',
            position: 1,
            blocks: const <Block>[],
            revision: 1,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        attachments: const <Attachment>[],
        operations: const <Operation>[],
        commandOutcomes: const <CommandOutcome>[],
      ),
      throwsA(
        isA<BackupSnapshotException>().having(
          (BackupSnapshotException error) => error.code,
          'code',
          'BackupInvalid',
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
  Map<String, Attachment> attachments = <String, Attachment>{};
  Map<String, AttachmentCommitMarker> attachmentMarkers =
      <String, AttachmentCommitMarker>{};
  Map<String, CommandOutcome> outcomes = <String, CommandOutcome>{};
  List<Operation> operations = <Operation>[];
  Map<String, SearchProjection> searchProjections =
      <String, SearchProjection>{};
  int sequence = 0;
  int searchIndexedSequence = 0;
  bool failAfterAttachmentMarker = false;

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
      attachments = snapshot.attachments;
      attachmentMarkers = snapshot.attachmentMarkers;
      outcomes = snapshot.outcomes;
      operations = snapshot.operations;
      searchProjections = snapshot.searchProjections;
      sequence = snapshot.sequence;
      searchIndexedSequence = snapshot.searchIndexedSequence;
      rethrow;
    }
  }

  _MemoryStore _copy() => _MemoryStore()
    ..workspaces = Map<String, Workspace>.of(workspaces)
    ..documents = Map<String, Document>.of(documents)
    ..attachments = Map<String, Attachment>.of(attachments)
    ..attachmentMarkers = Map<String, AttachmentCommitMarker>.of(
      attachmentMarkers,
    )
    ..outcomes = Map<String, CommandOutcome>.of(outcomes)
    ..operations = List<Operation>.of(operations)
    ..searchProjections = Map<String, SearchProjection>.of(searchProjections)
    ..sequence = sequence
    ..searchIndexedSequence = searchIndexedSequence
    ..failAfterAttachmentMarker = failAfterAttachmentMarker;
}

final class _MemoryTransaction implements ClientStoreWriter {
  const _MemoryTransaction(this.store);

  final _MemoryStore store;

  @override
  Future<void> appendOperation(Operation operation) async {
    store.operations.add(operation);
  }

  @override
  Future<Attachment?> getAttachment(String attachmentId) async =>
      store.attachments[attachmentId];

  @override
  Future<AttachmentCommitMarker?> getAttachmentCommitMarker(
    String attachmentId,
  ) async => store.attachmentMarkers[attachmentId];

  @override
  Future<List<AttachmentCommitMarker>> listPendingAttachmentCommits() async =>
      store.attachmentMarkers.values.toList();

  @override
  Future<CommandOutcome?> getCommandOutcome(String commandId) async =>
      store.outcomes[commandId];

  @override
  Future<int> currentEventSequence() async => store.sequence;

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
  Future<List<Attachment>> listAttachments(
    String documentId, {
    bool includeDeleted = false,
  }) async => store.attachments.values
      .where(
        (Attachment attachment) =>
            attachment.documentId == documentId &&
            (includeDeleted || !attachment.isDeleted),
      )
      .toList();

  @override
  Future<List<Workspace>> listWorkspaces({
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async => store.workspaces.values
      .where(
        (Workspace workspace) =>
            (includeDeleted ||
                workspace.lifecycle != WorkspaceLifecycle.deleted) &&
            (includeArchived ||
                includeDeleted ||
                workspace.lifecycle == WorkspaceLifecycle.active),
      )
      .toList();

  @override
  Future<List<Operation>> listOperations() async =>
      List<Operation>.of(store.operations);

  @override
  Future<List<CommandOutcome>> listCommandOutcomes() async =>
      store.outcomes.values.toList();

  @override
  Future<SearchStatus> getSearchStatus() async => SearchStatus(
    eventSequence: store.sequence,
    indexedSequence: store.searchIndexedSequence,
    documentCount: store.searchProjections.length,
  );

  @override
  Future<int> nextEventSequence() async => ++store.sequence;

  @override
  Future<void> putCommandOutcome(CommandOutcome outcome) async {
    store.outcomes[outcome.commandId] = outcome;
  }

  @override
  Future<void> putAttachment(Attachment attachment) async {
    store.attachments[attachment.id] = attachment;
  }

  @override
  Future<void> putAttachmentCommitMarker(AttachmentCommitMarker marker) async {
    store.attachmentMarkers[marker.attachmentId] = marker;
    if (store.failAfterAttachmentMarker) {
      store.failAfterAttachmentMarker = false;
      throw StateError('Injected attachment marker failure.');
    }
  }

  @override
  Future<void> putDocument(Document document) async {
    store.documents[document.id] = document;
  }

  @override
  Future<void> putSearchProjection(SearchProjection projection) async {
    store.searchProjections[projection.documentId] = projection;
  }

  @override
  Future<void> putWorkspace(Workspace workspace) async {
    store.workspaces[workspace.id] = workspace;
  }

  @override
  Future<void> removeSearchProjection(String documentId) async {
    store.searchProjections.remove(documentId);
  }

  @override
  Future<void> removeAttachmentCommitMarker(String attachmentId) async {
    store.attachmentMarkers.remove(attachmentId);
  }

  @override
  Future<void> replaceSearchProjections(
    List<SearchProjection> projections,
  ) async {
    store.searchProjections = <String, SearchProjection>{
      for (final SearchProjection projection in projections)
        projection.documentId: projection,
    };
  }

  @override
  Future<List<SearchHit>> searchDocuments(
    String workspaceId,
    String query, {
    required int limit,
  }) async {
    final String term = query.toLowerCase();
    return store.searchProjections.values
        .where(
          (SearchProjection projection) =>
              projection.workspaceId == workspaceId &&
              '${projection.title}\n${projection.content}'
                  .toLowerCase()
                  .contains(term),
        )
        .take(limit)
        .map(
          (SearchProjection projection) => SearchHit(
            documentId: projection.documentId,
            workspaceId: projection.workspaceId,
            title: projection.title,
            snippet: projection.content,
            score: 1,
            observedRevision: projection.revision,
            indexedSequence: store.searchIndexedSequence,
          ),
        )
        .toList();
  }

  @override
  Future<void> setSearchIndexedSequence(int sequence) async {
    store.searchIndexedSequence = sequence;
  }

  @override
  Future<void> setEventSequence(int sequence) async {
    store.sequence = sequence;
  }
}
