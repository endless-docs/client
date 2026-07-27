import 'dart:async';
import 'dart:convert';

import 'package:client_domain/client_domain.dart';

import 'ports.dart';
import 'search.dart';

final class ApplicationException implements Exception {
  const ApplicationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ApplicationException($code): $message';
}

final class CommandReceipt {
  const CommandReceipt({
    required this.result,
    required this.commitSequence,
    required this.wasReplay,
  });

  final Map<String, Object?> result;
  final int commitSequence;
  final bool wasReplay;
}

final class BlockDraft {
  const BlockDraft({this.id, required this.type, required this.payload});

  final String? id;
  final BlockType type;
  final Map<String, Object?> payload;
}

final class ClientApplicationService {
  const ClientApplicationService({
    required ClientStore store,
    required Clock clock,
    required IdGenerator ids,
  }) : _store = store,
       _clock = clock,
       _ids = ids;

  final ClientStore _store;
  final Clock _clock;
  final IdGenerator _ids;

  Future<List<Workspace>> listWorkspaces({bool includeArchived = false}) =>
      _store.read(
        (ClientStoreReader reader) =>
            reader.listWorkspaces(includeArchived: includeArchived),
      );

  Future<Workspace> getWorkspace(String workspaceId) async {
    final Workspace? workspace = await _store.read(
      (ClientStoreReader reader) => reader.getWorkspace(workspaceId),
    );
    if (workspace == null ||
        workspace.lifecycle == WorkspaceLifecycle.deleted) {
      throw const ApplicationException(
        'WorkspaceNotFound',
        'Workspace was not found.',
      );
    }
    return workspace;
  }

  Future<List<Document>> listDocuments(
    String workspaceId, {
    bool includeDeleted = false,
  }) async {
    await getWorkspace(workspaceId);
    return _store.read(
      (ClientStoreReader reader) =>
          reader.listDocuments(workspaceId, includeDeleted: includeDeleted),
    );
  }

  Future<Document> getDocument(String documentId) async {
    final Document? document = await _store.read(
      (ClientStoreReader reader) => reader.getDocument(documentId),
    );
    if (document == null) {
      throw const ApplicationException(
        'DocumentNotFound',
        'Document was not found.',
      );
    }
    return document;
  }

  Future<List<SearchHit>> searchDocuments({
    required String workspaceId,
    required String query,
    int limit = 50,
  }) async {
    await getWorkspace(workspaceId);
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || normalizedQuery.length > 500) {
      throw const ApplicationException(
        'InvalidArgument',
        'Search query must contain between 1 and 500 characters.',
      );
    }
    if (limit < 1 || limit > 100) {
      throw const ApplicationException(
        'InvalidArgument',
        'Search limit must be between 1 and 100.',
      );
    }
    return _store.read(
      (ClientStoreReader reader) =>
          reader.searchDocuments(workspaceId, normalizedQuery, limit: limit),
    );
  }

  Future<SearchStatus> getSearchStatus() =>
      _store.read((ClientStoreReader reader) => reader.getSearchStatus());

  Future<SearchStatus> ensureSearchIndex() =>
      _store.write((ClientStoreWriter writer) async {
        final SearchStatus status = await writer.getSearchStatus();
        return status.isCurrent ? status : _replaceSearchIndex(writer);
      });

  Future<CommandReceipt> rebuildSearchIndex({required String commandId}) {
    const String method = 'RebuildSearchIndex';
    const String fingerprint = '{}';
    if (commandId.isEmpty || commandId.length > 200) {
      throw const ApplicationException(
        'InvalidArgument',
        'A bounded command_id is required.',
      );
    }
    return _store.write((ClientStoreWriter writer) async {
      final CommandOutcome? existing = await writer.getCommandOutcome(
        commandId,
      );
      if (existing != null) {
        if (existing.method != method || existing.fingerprint != fingerprint) {
          throw const ApplicationException(
            'CommandIdReused',
            'command_id was already used for another request.',
          );
        }
        return CommandReceipt(
          result: existing.result,
          commitSequence: existing.commitSequence,
          wasReplay: true,
        );
      }

      final SearchStatus status = await _replaceSearchIndex(writer);
      final int sequence = status.indexedSequence;
      final Map<String, Object?> result = status.toJson();
      await writer.putCommandOutcome(
        CommandOutcome(
          commandId: commandId,
          method: method,
          fingerprint: fingerprint,
          result: result,
          commitSequence: sequence,
        ),
      );
      return CommandReceipt(
        result: result,
        commitSequence: sequence,
        wasReplay: false,
      );
    });
  }

  Future<CommandReceipt> createWorkspace({
    required String commandId,
    required String name,
  }) {
    final String normalizedName = validateWorkspaceName(name);
    final String workspaceId = _ids.nextId();
    final DateTime now = _clock.now();
    return _execute(
      commandId: commandId,
      method: 'CreateWorkspace',
      fingerprintPayload: <String, Object?>{'name': normalizedName},
      workspaceId: workspaceId,
      objectId: workspaceId,
      baseRevision: 0,
      transition: (ClientStoreWriter writer) async {
        final Workspace workspace = Workspace(
          id: workspaceId,
          name: normalizedName,
          lifecycle: WorkspaceLifecycle.active,
          revision: 1,
          createdAt: now,
          updatedAt: now,
        );
        await writer.putWorkspace(workspace);
        return workspace.toJson();
      },
    );
  }

  Future<CommandReceipt> renameWorkspace({
    required String commandId,
    required String workspaceId,
    required String name,
    int? expectedRevision,
  }) {
    final String normalizedName = validateWorkspaceName(name);
    return _execute(
      commandId: commandId,
      method: 'RenameWorkspace',
      fingerprintPayload: <String, Object?>{
        'workspace_id': workspaceId,
        'name': normalizedName,
        'expected_revision': expectedRevision,
      },
      workspaceId: workspaceId,
      objectId: workspaceId,
      baseRevision: expectedRevision ?? 0,
      transition: (ClientStoreWriter writer) async {
        final Workspace workspace = await _requireWorkspace(
          writer,
          workspaceId,
        );
        _checkRevision(workspace.revision, expectedRevision);
        final Workspace updated = workspace.rename(
          normalizedName,
          _clock.now(),
        );
        await writer.putWorkspace(updated);
        return updated.toJson();
      },
    );
  }

  Future<CommandReceipt> createDocument({
    required String commandId,
    required String workspaceId,
    required String title,
    String? parentId,
  }) {
    final String normalizedTitle = validateDocumentTitle(title);
    final String documentId = _ids.nextId();
    final DateTime now = _clock.now();
    return _execute(
      commandId: commandId,
      method: 'CreateDocument',
      fingerprintPayload: <String, Object?>{
        'workspace_id': workspaceId,
        'title': normalizedTitle,
        'parent_id': parentId,
      },
      workspaceId: workspaceId,
      objectId: documentId,
      baseRevision: 0,
      transition: (ClientStoreWriter writer) async {
        await _requireWorkspace(writer, workspaceId);
        if (parentId != null) {
          final Document parent = await _requireDocument(writer, parentId);
          if (parent.workspaceId != workspaceId || parent.isDeleted) {
            throw const ApplicationException(
              'InvalidParent',
              'Parent document must be active in the same workspace.',
            );
          }
        }
        final List<Document> siblings = await writer.listDocuments(workspaceId);
        final int position = siblings
            .where((Document document) => document.parentId == parentId)
            .length;
        final Document document = Document(
          id: documentId,
          workspaceId: workspaceId,
          title: normalizedTitle,
          parentId: parentId,
          position: position,
          blocks: const <Block>[],
          revision: 1,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );
        await writer.putDocument(document);
        await writer.putSearchProjection(_searchProjection(document));
        return document.toJson();
      },
    );
  }

  Future<CommandReceipt> saveDocument({
    required String commandId,
    required String documentId,
    required String title,
    required List<BlockDraft> blocks,
    int? expectedRevision,
  }) {
    final String normalizedTitle = validateDocumentTitle(title);
    for (final BlockDraft block in blocks) {
      final Object? text = block.payload['text'];
      if (text is String) {
        validateBlockText(text);
      }
    }
    return _execute(
      commandId: commandId,
      method: 'ApplyBlockChanges',
      fingerprintPayload: <String, Object?>{
        'document_id': documentId,
        'title': normalizedTitle,
        'blocks': blocks
            .map(
              (BlockDraft block) => <String, Object?>{
                'block_id': block.id,
                'type': block.type.name,
                'payload': block.payload,
              },
            )
            .toList(),
        'expected_revision': expectedRevision,
      },
      workspaceId: '',
      objectId: documentId,
      baseRevision: expectedRevision ?? 0,
      transition: (ClientStoreWriter writer) async {
        final Document document = await _requireDocument(writer, documentId);
        if (document.isDeleted) {
          throw const ApplicationException(
            'DocumentNotFound',
            'Deleted document cannot be edited.',
          );
        }
        _checkRevision(document.revision, expectedRevision);
        final Map<String, Block> existing = <String, Block>{
          for (final Block block in document.blocks) block.id: block,
        };
        final List<Block> updatedBlocks = <Block>[
          for (int index = 0; index < blocks.length; index++)
            _materializeBlock(
              documentId: documentId,
              draft: blocks[index],
              existing: existing,
              position: index,
            ),
        ];
        final Document updated = document.updateContent(
          title: normalizedTitle,
          blocks: updatedBlocks,
          now: _clock.now(),
        );
        await writer.putDocument(updated);
        await writer.putSearchProjection(_searchProjection(updated));
        return updated.toJson();
      },
    );
  }

  Future<CommandReceipt> moveDocument({
    required String commandId,
    required String documentId,
    required String? parentId,
    required int position,
    int? expectedRevision,
  }) {
    if (position < 0) {
      throw const ApplicationException(
        'InvalidArgument',
        'Document position must not be negative.',
      );
    }
    return _execute(
      commandId: commandId,
      method: 'MoveDocument',
      fingerprintPayload: <String, Object?>{
        'document_id': documentId,
        'parent_id': parentId,
        'position': position,
        'expected_revision': expectedRevision,
      },
      workspaceId: '',
      objectId: documentId,
      baseRevision: expectedRevision ?? 0,
      transition: (ClientStoreWriter writer) async {
        final Document document = await _requireDocument(writer, documentId);
        _checkRevision(document.revision, expectedRevision);
        await _validateParent(writer, document, parentId);
        final Document updated = document.move(
          parentId: parentId,
          position: position,
          now: _clock.now(),
        );
        await writer.putDocument(updated);
        await writer.putSearchProjection(_searchProjection(updated));
        return updated.toJson();
      },
    );
  }

  Future<CommandReceipt> deleteDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) => _setDocumentDeleted(
    commandId: commandId,
    documentId: documentId,
    expectedRevision: expectedRevision,
    deleted: true,
  );

  Future<CommandReceipt> restoreDocument({
    required String commandId,
    required String documentId,
    int? expectedRevision,
  }) => _setDocumentDeleted(
    commandId: commandId,
    documentId: documentId,
    expectedRevision: expectedRevision,
    deleted: false,
  );

  Future<CommandReceipt> _setDocumentDeleted({
    required String commandId,
    required String documentId,
    required int? expectedRevision,
    required bool deleted,
  }) => _execute(
    commandId: commandId,
    method: deleted ? 'DeleteDocument' : 'RestoreDocument',
    fingerprintPayload: <String, Object?>{
      'document_id': documentId,
      'expected_revision': expectedRevision,
    },
    workspaceId: '',
    objectId: documentId,
    baseRevision: expectedRevision ?? 0,
    transition: (ClientStoreWriter writer) async {
      final Document document = await _requireDocument(writer, documentId);
      _checkRevision(document.revision, expectedRevision);
      if (document.isDeleted == deleted) {
        throw ApplicationException(
          deleted ? 'DocumentNotFound' : 'InvalidArgument',
          deleted ? 'Document is already deleted.' : 'Document is not deleted.',
        );
      }
      if (!deleted && document.parentId != null) {
        final Document? parent = await writer.getDocument(document.parentId!);
        if (parent == null || parent.isDeleted) {
          throw const ApplicationException(
            'InvalidParent',
            'Restore the parent document first.',
          );
        }
      }
      final DateTime now = _clock.now();
      final Document updated = document.markDeleted(deleted, now);
      await writer.putDocument(updated);
      if (deleted) {
        await writer.removeSearchProjection(updated.id);
      } else {
        await writer.putSearchProjection(_searchProjection(updated));
      }
      final List<String> affectedIds = <String>[updated.id];
      if (deleted) {
        final List<Document> allDocuments = await writer.listDocuments(
          document.workspaceId,
          includeDeleted: true,
        );
        final List<Document> descendants = _descendantsOf(
          document.id,
          allDocuments,
        );
        for (final Document descendant in descendants) {
          if (!descendant.isDeleted) {
            final Document deletedDescendant = descendant.markDeleted(
              true,
              now,
            );
            await writer.putDocument(deletedDescendant);
            await writer.removeSearchProjection(deletedDescendant.id);
            affectedIds.add(deletedDescendant.id);
          }
        }
      }
      return <String, Object?>{
        ...updated.toJson(),
        'affected_document_ids': affectedIds,
      };
    },
  );

  Future<CommandReceipt> _execute({
    required String commandId,
    required String method,
    required Map<String, Object?> fingerprintPayload,
    required String workspaceId,
    required String objectId,
    required int baseRevision,
    required Future<Map<String, Object?>> Function(ClientStoreWriter writer)
    transition,
  }) {
    if (commandId.isEmpty || commandId.length > 200) {
      throw const ApplicationException(
        'InvalidArgument',
        'A bounded command_id is required.',
      );
    }
    final String fingerprint = jsonEncode(fingerprintPayload);
    return _store.write((ClientStoreWriter writer) async {
      final CommandOutcome? existing = await writer.getCommandOutcome(
        commandId,
      );
      if (existing != null) {
        if (existing.method != method || existing.fingerprint != fingerprint) {
          throw const ApplicationException(
            'CommandIdReused',
            'command_id was already used for another request.',
          );
        }
        return CommandReceipt(
          result: existing.result,
          commitSequence: existing.commitSequence,
          wasReplay: true,
        );
      }

      final Map<String, Object?> result = await transition(writer);
      final String resolvedWorkspaceId =
          (result['workspace_id'] as String?) ?? workspaceId;
      final int resultRevision = (result['revision'] as int?) ?? baseRevision;
      final int sequence = await writer.nextEventSequence();
      await writer.setSearchIndexedSequence(sequence);
      await writer.appendOperation(
        Operation(
          id: _ids.nextId(),
          workspaceId: resolvedWorkspaceId,
          objectId: objectId,
          sequence: sequence,
          type: method,
          baseRevision: baseRevision,
          resultRevision: resultRevision,
          payload: fingerprintPayload,
          createdAt: _clock.now(),
        ),
      );
      await writer.putCommandOutcome(
        CommandOutcome(
          commandId: commandId,
          method: method,
          fingerprint: fingerprint,
          result: result,
          commitSequence: sequence,
        ),
      );
      return CommandReceipt(
        result: result,
        commitSequence: sequence,
        wasReplay: false,
      );
    });
  }

  Block _materializeBlock({
    required String documentId,
    required BlockDraft draft,
    required Map<String, Block> existing,
    required int position,
  }) {
    final Block? previous = draft.id == null ? null : existing[draft.id];
    if (previous != null && previous.documentId != documentId) {
      throw const ApplicationException(
        'InvalidArgument',
        'Block belongs to another document.',
      );
    }
    return Block(
      id: previous?.id ?? _ids.nextId(),
      documentId: documentId,
      type: draft.type,
      payload: Map<String, Object?>.unmodifiable(draft.payload),
      position: position,
      revision: (previous?.revision ?? 0) + 1,
    );
  }

  Future<void> _validateParent(
    ClientStoreReader reader,
    Document document,
    String? parentId,
  ) async {
    String? currentId = parentId;
    final Set<String> visited = <String>{};
    while (currentId != null) {
      if (currentId == document.id || !visited.add(currentId)) {
        throw const ApplicationException(
          'InvalidParent',
          'Document tree cannot contain a cycle.',
        );
      }
      final Document parent = await _requireDocument(reader, currentId);
      if (parent.workspaceId != document.workspaceId || parent.isDeleted) {
        throw const ApplicationException(
          'InvalidParent',
          'Parent document must be active in the same workspace.',
        );
      }
      currentId = parent.parentId;
    }
  }

  static Future<Workspace> _requireWorkspace(
    ClientStoreReader reader,
    String workspaceId,
  ) async {
    final Workspace? workspace = await reader.getWorkspace(workspaceId);
    if (workspace == null || workspace.lifecycle != WorkspaceLifecycle.active) {
      throw const ApplicationException(
        'WorkspaceNotFound',
        'Active workspace was not found.',
      );
    }
    return workspace;
  }

  static Future<Document> _requireDocument(
    ClientStoreReader reader,
    String documentId,
  ) async {
    final Document? document = await reader.getDocument(documentId);
    if (document == null) {
      throw const ApplicationException(
        'DocumentNotFound',
        'Document was not found.',
      );
    }
    return document;
  }

  static void _checkRevision(int actual, int? expected) {
    if (expected != null && expected != actual) {
      throw const ApplicationException(
        'RevisionConflict',
        'Document changed since it was loaded.',
      );
    }
  }

  static List<Document> _descendantsOf(
    String documentId,
    List<Document> documents,
  ) {
    final List<Document> result = <Document>[];
    final List<String> pending = <String>[documentId];
    final Set<String> visited = <String>{documentId};
    while (pending.isNotEmpty) {
      final String parentId = pending.removeLast();
      for (final Document candidate in documents) {
        if (candidate.parentId == parentId && visited.add(candidate.id)) {
          result.add(candidate);
          pending.add(candidate.id);
        }
      }
    }
    return result;
  }

  static Future<SearchStatus> _replaceSearchIndex(
    ClientStoreWriter writer,
  ) async {
    final List<SearchProjection> projections = <SearchProjection>[];
    for (final Workspace workspace in await writer.listWorkspaces(
      includeArchived: true,
    )) {
      for (final Document document in await writer.listDocuments(
        workspace.id,
      )) {
        projections.add(_searchProjection(document));
      }
    }
    await writer.replaceSearchProjections(projections);
    final int sequence = await writer.currentEventSequence();
    await writer.setSearchIndexedSequence(sequence);
    return writer.getSearchStatus();
  }

  static SearchProjection _searchProjection(Document document) =>
      SearchProjection(
        documentId: document.id,
        workspaceId: document.workspaceId,
        title: document.title,
        content: document.blocks
            .expand((Block block) => _stringValues(block.payload))
            .join('\n'),
        revision: document.revision,
      );

  static Iterable<String> _stringValues(Object? value) sync* {
    if (value is String) {
      yield value;
    } else if (value is Map<Object?, Object?>) {
      for (final Object? nested in value.values) {
        yield* _stringValues(nested);
      }
    } else if (value is Iterable<Object?>) {
      for (final Object? nested in value) {
        yield* _stringValues(nested);
      }
    }
  }
}
