import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:isar_community/isar.dart';

import 'records.dart';

final class IsarClientStore implements ClientStore {
  IsarClientStore._(this._isar);

  final Isar _isar;

  static bool _coreInitialized = false;

  static Future<IsarClientStore> open({
    required String directory,
    String? nativeLibraryPath,
    bool allowDevelopmentDownload = false,
    String instanceName = 'endless',
  }) async {
    await Directory(directory).create(recursive: true);
    if (!_coreInitialized) {
      if (nativeLibraryPath != null) {
        await File(nativeLibraryPath).parent.create(recursive: true);
        await Isar.initializeIsarCore(
          libraries: <Abi, String>{_currentAbi(): nativeLibraryPath},
          download: allowDevelopmentDownload,
        );
      } else {
        await Isar.initializeIsarCore(download: allowDevelopmentDownload);
      }
      _coreInitialized = true;
    }
    final Isar isar = await Isar.open(
      <CollectionSchema<Object>>[
        WorkspaceRecordSchema,
        DocumentRecordSchema,
        BlockRecordSchema,
        CommandOutcomeRecordSchema,
        OperationRecordSchema,
        RuntimeStateRecordSchema,
      ],
      directory: directory,
      name: instanceName,
      relaxedDurability: false,
      inspector: false,
    );
    return IsarClientStore._(isar);
  }

  Future<void> close() => _isar.close();

  @override
  Future<T> read<T>(
    FutureOr<T> Function(ClientStoreReader reader) operation,
  ) async => operation(_IsarReader(_isar));

  @override
  Future<T> write<T>(
    FutureOr<T> Function(ClientStoreWriter writer) operation,
  ) => _isar.writeTxn<T>(() async => operation(_IsarWriter(_isar)));

  static Abi _currentAbi() {
    if (Platform.isWindows) {
      return Abi.windowsX64;
    }
    if (Platform.isLinux) {
      return Abi.linuxX64;
    }
    if (Platform.isMacOS) {
      return Abi.macosArm64;
    }
    throw UnsupportedError('Unsupported locald platform.');
  }
}

class _IsarReader implements ClientStoreReader {
  const _IsarReader(this.isar);

  final Isar isar;

  @override
  Future<Workspace?> getWorkspace(String workspaceId) async {
    final List<WorkspaceRecord> records = await isar.workspaceRecords
        .where()
        .findAll();
    final WorkspaceRecord? record = _firstWhereOrNull(
      records,
      (WorkspaceRecord candidate) => candidate.workspaceId == workspaceId,
    );
    return record == null ? null : _workspaceFromRecord(record);
  }

  @override
  Future<List<Workspace>> listWorkspaces({bool includeArchived = false}) async {
    final List<WorkspaceRecord> records = await isar.workspaceRecords
        .where()
        .findAll();
    final List<Workspace> result = records
        .map(_workspaceFromRecord)
        .where(
          (Workspace workspace) =>
              workspace.lifecycle != WorkspaceLifecycle.deleted &&
              (includeArchived ||
                  workspace.lifecycle == WorkspaceLifecycle.active),
        )
        .toList();
    result.sort(
      (Workspace left, Workspace right) =>
          left.createdAt.compareTo(right.createdAt),
    );
    return result;
  }

  @override
  Future<Document?> getDocument(String documentId) async {
    final List<DocumentRecord> records = await isar.documentRecords
        .where()
        .findAll();
    final DocumentRecord? record = _firstWhereOrNull(
      records,
      (DocumentRecord candidate) => candidate.documentId == documentId,
    );
    return record == null ? null : _documentFromRecord(record);
  }

  @override
  Future<List<Document>> listDocuments(
    String workspaceId, {
    bool includeDeleted = false,
  }) async {
    final List<DocumentRecord> records = await isar.documentRecords
        .where()
        .findAll();
    final List<Document> result = <Document>[];
    for (final DocumentRecord record in records) {
      if (record.workspaceId == workspaceId &&
          (includeDeleted || !record.isDeleted)) {
        result.add(await _documentFromRecord(record));
      }
    }
    result.sort((Document left, Document right) {
      final int parentComparison = (left.parentId ?? '').compareTo(
        right.parentId ?? '',
      );
      return parentComparison != 0
          ? parentComparison
          : left.position.compareTo(right.position);
    });
    return result;
  }

  @override
  Future<CommandOutcome?> getCommandOutcome(String commandId) async {
    final List<CommandOutcomeRecord> records = await isar.commandOutcomeRecords
        .where()
        .findAll();
    final CommandOutcomeRecord? record = _firstWhereOrNull(
      records,
      (CommandOutcomeRecord candidate) => candidate.commandId == commandId,
    );
    if (record == null) {
      return null;
    }
    return CommandOutcome(
      commandId: record.commandId,
      method: record.method,
      fingerprint: record.fingerprint,
      result: _decodeMap(record.resultJson),
      commitSequence: record.commitSequence,
    );
  }

  Future<Document> _documentFromRecord(DocumentRecord record) async {
    final List<BlockRecord> allBlocks = await isar.blockRecords
        .where()
        .findAll();
    final List<Block> blocks =
        allBlocks
            .where((BlockRecord block) => block.documentId == record.documentId)
            .map(
              (BlockRecord block) => Block(
                id: block.blockId,
                documentId: block.documentId,
                type: _blockType(block.type),
                payload: _decodeMap(block.payloadJson),
                position: block.position,
                revision: block.revision,
              ),
            )
            .toList()
          ..sort(
            (Block left, Block right) =>
                left.position.compareTo(right.position),
          );
    return Document(
      id: record.documentId,
      workspaceId: record.workspaceId,
      title: record.title,
      parentId: record.parentId,
      position: record.position,
      blocks: List<Block>.unmodifiable(blocks),
      revision: record.revision,
      isDeleted: record.isDeleted,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  static Workspace _workspaceFromRecord(WorkspaceRecord record) => Workspace(
    id: record.workspaceId,
    name: record.name,
    lifecycle: WorkspaceLifecycle.values.byName(record.lifecycle),
    revision: record.revision,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

final class _IsarWriter extends _IsarReader implements ClientStoreWriter {
  const _IsarWriter(super.isar);

  @override
  Future<void> putWorkspace(Workspace workspace) async {
    final List<WorkspaceRecord> records = await isar.workspaceRecords
        .where()
        .findAll();
    final WorkspaceRecord record =
        _firstWhereOrNull(
          records,
          (WorkspaceRecord candidate) => candidate.workspaceId == workspace.id,
        ) ??
        WorkspaceRecord();
    record
      ..workspaceId = workspace.id
      ..name = workspace.name
      ..lifecycle = workspace.lifecycle.name
      ..revision = workspace.revision
      ..createdAt = workspace.createdAt
      ..updatedAt = workspace.updatedAt;
    await isar.workspaceRecords.put(record);
  }

  @override
  Future<void> putDocument(Document document) async {
    final List<DocumentRecord> records = await isar.documentRecords
        .where()
        .findAll();
    final DocumentRecord record =
        _firstWhereOrNull(
          records,
          (DocumentRecord candidate) => candidate.documentId == document.id,
        ) ??
        DocumentRecord();
    record
      ..documentId = document.id
      ..workspaceId = document.workspaceId
      ..parentId = document.parentId
      ..title = document.title
      ..position = document.position
      ..revision = document.revision
      ..isDeleted = document.isDeleted
      ..createdAt = document.createdAt
      ..updatedAt = document.updatedAt;
    await isar.documentRecords.put(record);

    final List<BlockRecord> allBlocks = await isar.blockRecords
        .where()
        .findAll();
    final List<int> staleIds = allBlocks
        .where((BlockRecord block) => block.documentId == document.id)
        .map((BlockRecord block) => block.id)
        .toList();
    await isar.blockRecords.deleteAll(staleIds);
    await isar.blockRecords.putAll(
      document.blocks
          .map(
            (Block block) => BlockRecord()
              ..blockId = block.id
              ..documentId = block.documentId
              ..type = block.type.name
              ..payloadJson = jsonEncode(block.payload)
              ..position = block.position
              ..revision = block.revision,
          )
          .toList(),
    );
  }

  @override
  Future<int> nextEventSequence() async {
    final RuntimeStateRecord state =
        await isar.runtimeStateRecords.get(1) ??
        (RuntimeStateRecord()..eventSequence = 0);
    state.eventSequence += 1;
    await isar.runtimeStateRecords.put(state);
    return state.eventSequence;
  }

  @override
  Future<void> putCommandOutcome(CommandOutcome outcome) async {
    final CommandOutcomeRecord record = CommandOutcomeRecord()
      ..commandId = outcome.commandId
      ..method = outcome.method
      ..fingerprint = outcome.fingerprint
      ..resultJson = jsonEncode(outcome.result)
      ..commitSequence = outcome.commitSequence;
    await isar.commandOutcomeRecords.put(record);
  }

  @override
  Future<void> appendOperation(Operation operation) async {
    final OperationRecord record = OperationRecord()
      ..operationId = operation.id
      ..workspaceId = operation.workspaceId
      ..objectId = operation.objectId
      ..sequence = operation.sequence
      ..type = operation.type
      ..baseRevision = operation.baseRevision
      ..resultRevision = operation.resultRevision
      ..payloadJson = jsonEncode(operation.payload)
      ..createdAt = operation.createdAt;
    await isar.operationRecords.put(record);
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) predicate) {
  for (final T value in values) {
    if (predicate(value)) {
      return value;
    }
  }
  return null;
}

Map<String, Object?> _decodeMap(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object.');
  }
  return decoded;
}

BlockType _blockType(String value) {
  for (final BlockType type in BlockType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return BlockType.unsupported;
}
