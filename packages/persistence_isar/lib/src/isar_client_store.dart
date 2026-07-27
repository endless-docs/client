import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:isar_community/isar.dart';

import 'records.dart';

enum IsarWriteStep {
  workspaceRecord,
  documentRecord,
  blockDelete,
  blockPut,
  searchProjectionPut,
  searchProjectionDelete,
  searchProjectionReplace,
  searchProjectionReplacePut,
  attachmentRecord,
  attachmentCommitMarker,
  attachmentCommitMarkerDelete,
  searchCheckpoint,
  eventSequence,
  commandOutcome,
  operationRecord,
}

typedef IsarFaultInjector = void Function(IsarWriteStep step);

final class IsarClientStore implements ClientStore {
  IsarClientStore._(this._isar, this._faultInjector);

  final Isar _isar;
  final IsarFaultInjector? _faultInjector;

  static bool _coreInitialized = false;

  static Future<IsarClientStore> open({
    required String directory,
    String? nativeLibraryPath,
    bool allowDevelopmentDownload = false,
    String instanceName = 'endless',
    IsarFaultInjector? faultInjector,
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
        SearchProjectionRecordSchema,
        AttachmentRecordSchema,
        AttachmentCommitRecordSchema,
        RuntimeStateRecordSchema,
      ],
      directory: directory,
      name: instanceName,
      relaxedDurability: false,
      inspector: false,
    );
    return IsarClientStore._(isar, faultInjector);
  }

  Future<void> close() => _isar.close();

  @override
  Future<T> read<T>(FutureOr<T> Function(ClientStoreReader reader) operation) =>
      _isar.txn<T>(() async => operation(_IsarReader(_isar)));

  @override
  Future<T> write<T>(
    FutureOr<T> Function(ClientStoreWriter writer) operation,
  ) => _isar.writeTxn<T>(
    () async => operation(_IsarWriter(_isar, _faultInjector)),
  );

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
  Future<List<Workspace>> listWorkspaces({
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    final List<WorkspaceRecord> records = await isar.workspaceRecords
        .where()
        .findAll();
    final List<Workspace> result = records
        .map(_workspaceFromRecord)
        .where(
          (Workspace workspace) =>
              (includeDeleted ||
                  workspace.lifecycle != WorkspaceLifecycle.deleted) &&
              (includeArchived ||
                  includeDeleted ||
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
  Future<Attachment?> getAttachment(String attachmentId) async {
    final AttachmentRecord? record = await isar.attachmentRecords
        .filter()
        .attachmentIdEqualTo(attachmentId)
        .findFirst();
    return record == null ? null : _attachmentFromRecord(record);
  }

  @override
  Future<List<Attachment>> listAttachments(
    String documentId, {
    bool includeDeleted = false,
  }) async {
    final List<Attachment> result =
        (await isar.attachmentRecords
                .filter()
                .documentIdEqualTo(documentId)
                .findAll())
            .map(_attachmentFromRecord)
            .where((Attachment attachment) {
              return includeDeleted || !attachment.isDeleted;
            })
            .toList();
    result.sort(
      (Attachment left, Attachment right) =>
          left.createdAt.compareTo(right.createdAt),
    );
    return result;
  }

  @override
  Future<AttachmentCommitMarker?> getAttachmentCommitMarker(
    String attachmentId,
  ) async {
    final AttachmentCommitRecord? record = await isar.attachmentCommitRecords
        .filter()
        .attachmentIdEqualTo(attachmentId)
        .findFirst();
    return record == null ? null : _attachmentMarkerFromRecord(record);
  }

  @override
  Future<List<AttachmentCommitMarker>> listPendingAttachmentCommits() async =>
      (await isar.attachmentCommitRecords.where().findAll())
          .map(_attachmentMarkerFromRecord)
          .toList(growable: false);

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
    return _outcomeFromRecord(record);
  }

  @override
  Future<List<CommandOutcome>> listCommandOutcomes() async {
    final List<CommandOutcome> result =
        (await isar.commandOutcomeRecords.where().findAll())
            .map(_outcomeFromRecord)
            .toList();
    result.sort(
      (CommandOutcome left, CommandOutcome right) =>
          left.commandId.compareTo(right.commandId),
    );
    return result;
  }

  @override
  Future<List<Operation>> listOperations() async {
    final List<Operation> result =
        (await isar.operationRecords.where().findAll())
            .map(_operationFromRecord)
            .toList();
    result.sort(
      (Operation left, Operation right) =>
          left.sequence.compareTo(right.sequence),
    );
    return result;
  }

  @override
  Future<List<SearchHit>> searchDocuments(
    String workspaceId,
    String query, {
    required int limit,
  }) async {
    final RuntimeStateRecord? state = await isar.runtimeStateRecords.get(1);
    final int indexedSequence = _sequenceOrZero(state?.searchIndexedSequence);
    final List<String> terms = _normalizeSearchText(
      query,
    ).split(' ').where((String term) => term.isNotEmpty).toList();
    final List<_RankedProjection> ranked = <_RankedProjection>[];
    for (final SearchProjectionRecord projection
        in await isar.searchProjectionRecords.where().findAll()) {
      if (projection.workspaceId != workspaceId ||
          !terms.every(projection.normalizedText.contains)) {
        continue;
      }
      final String normalizedTitle = _normalizeSearchText(projection.title);
      int score = 10;
      for (final String term in terms) {
        if (normalizedTitle == term) {
          score += 100;
        } else if (normalizedTitle.startsWith(term)) {
          score += 50;
        } else if (normalizedTitle.contains(term)) {
          score += 25;
        }
      }
      ranked.add(_RankedProjection(projection, score));
    }
    ranked.sort((_RankedProjection left, _RankedProjection right) {
      final int score = right.score.compareTo(left.score);
      return score != 0
          ? score
          : left.projection.title.compareTo(right.projection.title);
    });
    return ranked
        .take(limit)
        .map(
          (_RankedProjection ranked) => SearchHit(
            documentId: ranked.projection.documentId,
            workspaceId: ranked.projection.workspaceId,
            title: ranked.projection.title,
            snippet: _searchSnippet(ranked.projection.content, terms),
            score: ranked.score,
            observedRevision: ranked.projection.revision,
            indexedSequence: indexedSequence,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SearchStatus> getSearchStatus() async {
    final RuntimeStateRecord? state = await isar.runtimeStateRecords.get(1);
    return SearchStatus(
      eventSequence: state?.eventSequence ?? 0,
      indexedSequence: _sequenceOrZero(state?.searchIndexedSequence),
      documentCount: await isar.searchProjectionRecords.count(),
    );
  }

  @override
  Future<int> currentEventSequence() async =>
      (await isar.runtimeStateRecords.get(1))?.eventSequence ?? 0;

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
      documentType: record.documentType.isEmpty
          ? DocumentType.plain
          : documentTypeFromWireName(record.documentType),
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

  static CommandOutcome _outcomeFromRecord(CommandOutcomeRecord record) =>
      CommandOutcome(
        commandId: record.commandId,
        method: record.method,
        fingerprint: record.fingerprint,
        result: _decodeMap(record.resultJson),
        commitSequence: record.commitSequence,
      );

  static Operation _operationFromRecord(OperationRecord record) => Operation(
    id: record.operationId,
    workspaceId: record.workspaceId,
    objectId: record.objectId,
    sequence: record.sequence,
    type: record.type,
    baseRevision: record.baseRevision,
    resultRevision: record.resultRevision,
    payload: _decodeMap(record.payloadJson),
    createdAt: record.createdAt,
  );
}

final class _IsarWriter extends _IsarReader implements ClientStoreWriter {
  const _IsarWriter(super.isar, this.faultInjector);

  final IsarFaultInjector? faultInjector;

  void _hit(IsarWriteStep step) => faultInjector?.call(step);

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
    _hit(IsarWriteStep.workspaceRecord);
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
      ..documentType = document.documentType.wireName
      ..position = document.position
      ..revision = document.revision
      ..isDeleted = document.isDeleted
      ..createdAt = document.createdAt
      ..updatedAt = document.updatedAt;
    _hit(IsarWriteStep.documentRecord);
    await isar.documentRecords.put(record);

    final List<BlockRecord> allBlocks = await isar.blockRecords
        .where()
        .findAll();
    final List<int> staleIds = allBlocks
        .where((BlockRecord block) => block.documentId == document.id)
        .map((BlockRecord block) => block.id)
        .toList();
    _hit(IsarWriteStep.blockDelete);
    await isar.blockRecords.deleteAll(staleIds);
    _hit(IsarWriteStep.blockPut);
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
  Future<void> putAttachment(Attachment attachment) async {
    final AttachmentRecord record =
        await isar.attachmentRecords
            .filter()
            .attachmentIdEqualTo(attachment.id)
            .findFirst() ??
        AttachmentRecord();
    record
      ..attachmentId = attachment.id
      ..workspaceId = attachment.workspaceId
      ..documentId = attachment.documentId
      ..sha256 = attachment.sha256
      ..fileName = attachment.fileName
      ..mediaType = attachment.mediaType
      ..size = attachment.size
      ..revision = attachment.revision
      ..isDeleted = attachment.isDeleted
      ..createdAt = attachment.createdAt
      ..updatedAt = attachment.updatedAt;
    _hit(IsarWriteStep.attachmentRecord);
    await isar.attachmentRecords.put(record);
  }

  @override
  Future<void> putAttachmentCommitMarker(AttachmentCommitMarker marker) async {
    final AttachmentCommitRecord record =
        await isar.attachmentCommitRecords
            .filter()
            .attachmentIdEqualTo(marker.attachmentId)
            .findFirst() ??
        AttachmentCommitRecord();
    record
      ..attachmentId = marker.attachmentId
      ..stagingToken = marker.stagingToken
      ..sha256 = marker.sha256
      ..size = marker.size
      ..createdAt = marker.createdAt;
    _hit(IsarWriteStep.attachmentCommitMarker);
    await isar.attachmentCommitRecords.put(record);
  }

  @override
  Future<void> removeAttachmentCommitMarker(String attachmentId) async {
    final AttachmentCommitRecord? record = await isar.attachmentCommitRecords
        .filter()
        .attachmentIdEqualTo(attachmentId)
        .findFirst();
    if (record != null) {
      _hit(IsarWriteStep.attachmentCommitMarkerDelete);
      await isar.attachmentCommitRecords.delete(record.id);
    }
  }

  @override
  Future<void> putSearchProjection(SearchProjection projection) async {
    final SearchProjectionRecord record =
        await isar.searchProjectionRecords
            .filter()
            .documentIdEqualTo(projection.documentId)
            .findFirst() ??
        SearchProjectionRecord();
    _writeSearchProjection(record, projection);
    _hit(IsarWriteStep.searchProjectionPut);
    await isar.searchProjectionRecords.put(record);
  }

  @override
  Future<void> removeSearchProjection(String documentId) async {
    final SearchProjectionRecord? record = await isar.searchProjectionRecords
        .filter()
        .documentIdEqualTo(documentId)
        .findFirst();
    if (record != null) {
      _hit(IsarWriteStep.searchProjectionDelete);
      await isar.searchProjectionRecords.delete(record.id);
    }
  }

  @override
  Future<void> replaceSearchProjections(
    List<SearchProjection> projections,
  ) async {
    final List<int> ids = (await isar.searchProjectionRecords.where().findAll())
        .map((SearchProjectionRecord record) => record.id)
        .toList();
    _hit(IsarWriteStep.searchProjectionReplace);
    await isar.searchProjectionRecords.deleteAll(ids);
    _hit(IsarWriteStep.searchProjectionReplacePut);
    await isar.searchProjectionRecords.putAll(
      projections
          .map(
            (SearchProjection projection) =>
                _writeSearchProjection(SearchProjectionRecord(), projection),
          )
          .toList(),
    );
  }

  @override
  Future<void> setSearchIndexedSequence(int sequence) async {
    final RuntimeStateRecord state =
        await isar.runtimeStateRecords.get(1) ??
        (RuntimeStateRecord()
          ..eventSequence = 0
          ..searchIndexedSequence = 0);
    state.searchIndexedSequence = sequence;
    _hit(IsarWriteStep.searchCheckpoint);
    await isar.runtimeStateRecords.put(state);
  }

  @override
  Future<int> nextEventSequence() async {
    final RuntimeStateRecord state =
        await isar.runtimeStateRecords.get(1) ??
        (RuntimeStateRecord()
          ..eventSequence = 0
          ..searchIndexedSequence = 0);
    state.eventSequence += 1;
    _hit(IsarWriteStep.eventSequence);
    await isar.runtimeStateRecords.put(state);
    return state.eventSequence;
  }

  @override
  Future<void> setEventSequence(int sequence) async {
    final RuntimeStateRecord state =
        await isar.runtimeStateRecords.get(1) ??
        (RuntimeStateRecord()
          ..eventSequence = 0
          ..searchIndexedSequence = 0);
    state.eventSequence = sequence;
    _hit(IsarWriteStep.eventSequence);
    await isar.runtimeStateRecords.put(state);
  }

  @override
  Future<void> putCommandOutcome(CommandOutcome outcome) async {
    final CommandOutcomeRecord record = CommandOutcomeRecord()
      ..commandId = outcome.commandId
      ..method = outcome.method
      ..fingerprint = outcome.fingerprint
      ..resultJson = jsonEncode(outcome.result)
      ..commitSequence = outcome.commitSequence;
    _hit(IsarWriteStep.commandOutcome);
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
    _hit(IsarWriteStep.operationRecord);
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

String _normalizeSearchText(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

int _sequenceOrZero(int? value) => value == null || value < 0 ? 0 : value;

String _searchSnippet(String content, List<String> terms) {
  if (content.isEmpty) {
    return '';
  }
  final String normalizedContent = content.toLowerCase();
  int match = content.length;
  for (final String term in terms) {
    final int index = normalizedContent.indexOf(term);
    if (index >= 0 && index < match) {
      match = index;
    }
  }
  final int start = match == content.length
      ? 0
      : (match - 40).clamp(0, content.length);
  final int end = (start + 140).clamp(0, content.length);
  return '${start > 0 ? '…' : ''}${content.substring(start, end).trim()}'
      '${end < content.length ? '…' : ''}';
}

SearchProjectionRecord _writeSearchProjection(
  SearchProjectionRecord record,
  SearchProjection projection,
) => record
  ..documentId = projection.documentId
  ..workspaceId = projection.workspaceId
  ..title = projection.title
  ..content = projection.content
  ..normalizedText = _normalizeSearchText(
    '${projection.title}\n${projection.content}',
  )
  ..revision = projection.revision;

final class _RankedProjection {
  const _RankedProjection(this.projection, this.score);

  final SearchProjectionRecord projection;
  final int score;
}

Attachment _attachmentFromRecord(AttachmentRecord record) => Attachment(
  id: record.attachmentId,
  workspaceId: record.workspaceId,
  documentId: record.documentId,
  fileName: record.fileName,
  mediaType: record.mediaType,
  sha256: record.sha256,
  size: record.size,
  revision: record.revision,
  isDeleted: record.isDeleted,
  createdAt: record.createdAt,
  updatedAt: record.updatedAt,
);

AttachmentCommitMarker _attachmentMarkerFromRecord(
  AttachmentCommitRecord record,
) => AttachmentCommitMarker(
  attachmentId: record.attachmentId,
  stagingToken: record.stagingToken,
  sha256: record.sha256,
  size: record.size,
  createdAt: record.createdAt,
);
