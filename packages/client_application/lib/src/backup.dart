import 'package:client_domain/client_domain.dart';

const int clientBackupFormatVersion = 1;
const int _maximumSignedInt64 = 0x7fffffffffffffff;

final class BackupSnapshotException implements Exception {
  const BackupSnapshotException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'BackupSnapshotException($code): $message';
}

final class ClientBackupSnapshot {
  ClientBackupSnapshot({
    required this.exportedAt,
    required this.eventSequence,
    required List<Workspace> workspaces,
    required List<Document> documents,
    required List<Attachment> attachments,
    required List<Operation> operations,
    required List<CommandOutcome> commandOutcomes,
  }) : workspaces = List<Workspace>.unmodifiable(workspaces),
       documents = List<Document>.unmodifiable(documents),
       attachments = List<Attachment>.unmodifiable(attachments),
       operations = List<Operation>.unmodifiable(operations),
       commandOutcomes = List<CommandOutcome>.unmodifiable(commandOutcomes) {
    _validate();
  }

  final DateTime exportedAt;
  final int eventSequence;
  final List<Workspace> workspaces;
  final List<Document> documents;
  final List<Attachment> attachments;
  final List<Operation> operations;
  final List<CommandOutcome> commandOutcomes;

  Map<String, Object?> toJson() => <String, Object?>{
    'format_version': clientBackupFormatVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'event_sequence': eventSequence,
    'workspaces': workspaces
        .map((Workspace workspace) => workspace.toJson())
        .toList(),
    'documents': documents
        .map((Document document) => document.toJson())
        .toList(),
    'attachments': attachments
        .map((Attachment attachment) => attachment.toJson())
        .toList(),
    'operations': operations.map(_operationToJson).toList(),
    'command_outcomes': commandOutcomes.map(_outcomeToJson).toList(),
  };

  factory ClientBackupSnapshot.fromJson(Map<String, Object?> json) {
    try {
      if (_requiredInt(json, 'format_version') != clientBackupFormatVersion) {
        throw const BackupSnapshotException(
          'BackupVersionUnsupported',
          'Backup format version is unsupported.',
        );
      }
      return ClientBackupSnapshot(
        exportedAt: _requiredDateTime(json, 'exported_at'),
        eventSequence: _requiredInt(json, 'event_sequence'),
        workspaces: _requiredMaps(
          json,
          'workspaces',
        ).map(_workspaceFromJson).toList(),
        documents: _requiredMaps(
          json,
          'documents',
        ).map(_documentFromJson).toList(),
        attachments: _requiredMaps(
          json,
          'attachments',
        ).map(_attachmentFromJson).toList(),
        operations: _requiredMaps(
          json,
          'operations',
        ).map(_operationFromJson).toList(),
        commandOutcomes: _requiredMaps(
          json,
          'command_outcomes',
        ).map(_outcomeFromJson).toList(),
      );
    } on BackupSnapshotException {
      rethrow;
    } on Object {
      throw const BackupSnapshotException(
        'BackupInvalid',
        'Backup contains invalid domain data.',
      );
    }
  }

  void _validate() {
    if (eventSequence < 0) {
      throw const BackupSnapshotException(
        'BackupInvalid',
        'Backup event sequence must not be negative.',
      );
    }
    final Set<String> workspaceIds = _uniqueIds(
      workspaces.map((Workspace value) => value.id),
      'workspace',
    );
    final Set<String> documentIds = _uniqueIds(
      documents.map((Document value) => value.id),
      'document',
    );
    _uniqueIds(attachments.map((Attachment value) => value.id), 'attachment');
    _uniqueIds(operations.map((Operation value) => value.id), 'operation');
    _uniqueIds(
      commandOutcomes.map((CommandOutcome value) => value.commandId),
      'command outcome',
    );

    for (final Document document in documents) {
      if (document.updatedAt.isBefore(document.createdAt)) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup document timestamps are inconsistent.',
        );
      }
      if (!workspaceIds.contains(document.workspaceId) ||
          (document.parentId != null &&
              !documentIds.contains(document.parentId))) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup document references an unknown owner or parent.',
        );
      }
      final Set<String> blockIds = <String>{};
      final Set<int> blockPositions = <int>{};
      for (final Block block in document.blocks) {
        if (block.documentId != document.id ||
            !blockIds.add(block.id) ||
            !blockPositions.add(block.position)) {
          throw const BackupSnapshotException(
            'BackupInvalid',
            'Backup contains invalid or duplicate document blocks or positions.',
          );
        }
        _validateJsonValue(block.payload);
      }
    }
    for (final Workspace workspace in workspaces) {
      if (workspace.updatedAt.isBefore(workspace.createdAt)) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup workspace timestamps are inconsistent.',
        );
      }
    }
    final Map<String, Document> documentsById = <String, Document>{
      for (final Document document in documents) document.id: document,
    };
    for (final Document document in documents) {
      final Set<String> ancestors = <String>{document.id};
      Document current = document;
      while (current.parentId != null) {
        final Document parent = documentsById[current.parentId]!;
        if (parent.workspaceId != document.workspaceId ||
            !ancestors.add(parent.id)) {
          throw const BackupSnapshotException(
            'BackupInvalid',
            'Backup document tree contains a cycle or crosses workspaces.',
          );
        }
        current = parent;
      }
    }
    for (final Attachment attachment in attachments) {
      final Document? document = documentsById[attachment.documentId];
      if (document == null ||
          document.workspaceId != attachment.workspaceId ||
          !workspaceIds.contains(attachment.workspaceId) ||
          attachment.updatedAt.isBefore(attachment.createdAt)) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup attachment metadata is inconsistent.',
        );
      }
    }
    final Set<int> operationSequences = <int>{};
    for (final Operation operation in operations) {
      if (!workspaceIds.contains(operation.workspaceId) ||
          operation.sequence < 1 ||
          operation.sequence > eventSequence ||
          operation.createdAt.isAfter(exportedAt) ||
          !operationSequences.add(operation.sequence)) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup contains an invalid operation sequence or workspace.',
        );
      }
      _validateJsonValue(operation.payload);
    }
    for (final CommandOutcome outcome in commandOutcomes) {
      if (outcome.commitSequence < 0 ||
          outcome.commitSequence > eventSequence) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup contains an invalid command outcome sequence.',
        );
      }
      _validateJsonValue(outcome.result);
    }
  }
}

Workspace _workspaceFromJson(Map<String, Object?> json) => Workspace(
  id: _identifier(json, 'workspace_id'),
  name: validateWorkspaceName(_requiredString(json, 'name')),
  lifecycle: _enumByName(
    WorkspaceLifecycle.values,
    _requiredString(json, 'lifecycle'),
    'workspace lifecycle',
  ),
  revision: _positiveInt(json, 'revision'),
  createdAt: _requiredDateTime(json, 'created_at'),
  updatedAt: _requiredDateTime(json, 'updated_at'),
);

Document _documentFromJson(Map<String, Object?> json) {
  final String documentId = _identifier(json, 'document_id');
  return Document(
    id: documentId,
    workspaceId: _identifier(json, 'workspace_id'),
    title: validateDocumentTitle(_requiredString(json, 'title')),
    parentId: _optionalIdentifier(json, 'parent_id'),
    position: _nonNegativeInt(json, 'position'),
    blocks: _requiredMaps(json, 'blocks')
        .map((Map<String, Object?> block) => _blockFromJson(block, documentId))
        .toList(growable: false),
    revision: _positiveInt(json, 'revision'),
    isDeleted: _requiredBool(json, 'is_deleted'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

Block _blockFromJson(Map<String, Object?> json, String documentId) {
  final String ownerId = _identifier(json, 'document_id');
  if (ownerId != documentId) {
    throw const BackupSnapshotException(
      'BackupInvalid',
      'Backup block belongs to another document.',
    );
  }
  return Block(
    id: _identifier(json, 'block_id'),
    documentId: ownerId,
    type: _enumByName(
      BlockType.values,
      _requiredString(json, 'type'),
      'block type',
    ),
    payload: Map<String, Object?>.unmodifiable(_requiredMap(json, 'payload')),
    position: _nonNegativeInt(json, 'position'),
    revision: _positiveInt(json, 'revision'),
  );
}

Attachment _attachmentFromJson(Map<String, Object?> json) => Attachment(
  id: _identifier(json, 'attachment_id'),
  workspaceId: _identifier(json, 'workspace_id'),
  documentId: _identifier(json, 'document_id'),
  fileName: validateAttachmentFileName(_requiredString(json, 'file_name')),
  mediaType: validateAttachmentMediaType(_requiredString(json, 'media_type')),
  sha256: validateAttachmentHash(_requiredString(json, 'sha256')),
  size: validateAttachmentSize(_requiredInt(json, 'size')),
  revision: _positiveInt(json, 'revision'),
  isDeleted: _requiredBool(json, 'is_deleted'),
  createdAt: _requiredDateTime(json, 'created_at'),
  updatedAt: _requiredDateTime(json, 'updated_at'),
);

Operation _operationFromJson(Map<String, Object?> json) => Operation(
  id: _identifier(json, 'operation_id'),
  workspaceId: _identifier(json, 'workspace_id'),
  objectId: _identifier(json, 'object_id'),
  sequence: _positiveInt(json, 'sequence'),
  type: _requiredString(json, 'type'),
  baseRevision: _nonNegativeInt(json, 'base_revision'),
  resultRevision: _nonNegativeInt(json, 'result_revision'),
  payload: Map<String, Object?>.unmodifiable(_requiredMap(json, 'payload')),
  createdAt: _requiredDateTime(json, 'created_at'),
);

CommandOutcome _outcomeFromJson(Map<String, Object?> json) => CommandOutcome(
  commandId: _identifier(json, 'command_id'),
  method: _requiredString(json, 'method'),
  fingerprint: _requiredString(json, 'fingerprint'),
  result: Map<String, Object?>.unmodifiable(_requiredMap(json, 'result')),
  commitSequence: _nonNegativeInt(json, 'commit_sequence'),
);

Map<String, Object?> _operationToJson(Operation operation) => <String, Object?>{
  'operation_id': operation.id,
  'workspace_id': operation.workspaceId,
  'object_id': operation.objectId,
  'sequence': operation.sequence,
  'type': operation.type,
  'base_revision': operation.baseRevision,
  'result_revision': operation.resultRevision,
  'payload': operation.payload,
  'created_at': operation.createdAt.toUtc().toIso8601String(),
};

Map<String, Object?> _outcomeToJson(CommandOutcome outcome) =>
    <String, Object?>{
      'command_id': outcome.commandId,
      'method': outcome.method,
      'fingerprint': outcome.fingerprint,
      'result': outcome.result,
      'commit_sequence': outcome.commitSequence,
    };

Set<String> _uniqueIds(Iterable<String> values, String kind) {
  final Set<String> result = <String>{};
  for (final String value in values) {
    if (!result.add(value)) {
      throw BackupSnapshotException(
        'BackupInvalid',
        'Backup contains a duplicate $kind identifier.',
      );
    }
  }
  return result;
}

String _identifier(Map<String, Object?> json, String key) {
  final String value = _requiredString(json, key);
  if (value.isEmpty ||
      value.length > 200 ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" is not a valid identifier.',
    );
  }
  return value;
}

String? _optionalIdentifier(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  return _identifier(json, key);
}

T _enumByName<T extends Enum>(List<T> values, String name, String label) {
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw BackupSnapshotException(
    'BackupInvalid',
    'Backup contains an unknown $label.',
  );
}

List<Map<String, Object?>> _requiredMaps(
  Map<String, Object?> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be a list.',
    );
  }
  return value
      .map((Object? item) {
        if (item is! Map<String, Object?>) {
          throw BackupSnapshotException(
            'BackupInvalid',
            'Backup field "$key" contains a non-object value.',
          );
        }
        return item;
      })
      .toList(growable: false);
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! Map<String, Object?>) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be an object.',
    );
  }
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.length > 1000000) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be a bounded string.',
    );
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int ||
      value < -_maximumSignedInt64 - 1 ||
      value > _maximumSignedInt64) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be an integer.',
    );
  }
  return value;
}

void _validateJsonValue(Object? value, [int depth = 0]) {
  if (depth > 64) {
    throw const BackupSnapshotException(
      'BackupInvalid',
      'Backup JSON data exceeds the supported nesting depth.',
    );
  }
  if (value == null || value is bool) {
    return;
  }
  if (value is int) {
    if (value < -_maximumSignedInt64 - 1 || value > _maximumSignedInt64) {
      throw const BackupSnapshotException(
        'BackupInvalid',
        'Backup JSON data contains an out-of-range integer.',
      );
    }
    return;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const BackupSnapshotException(
        'BackupInvalid',
        'Backup JSON data contains a non-finite number.',
      );
    }
    return;
  }
  if (value is String) {
    if (value.length > maxBlockTextLength) {
      throw const BackupSnapshotException(
        'BackupInvalid',
        'Backup JSON data contains an oversized string.',
      );
    }
    return;
  }
  if (value is List<Object?>) {
    for (final Object? item in value) {
      _validateJsonValue(item, depth + 1);
    }
    return;
  }
  if (value is Map<String, Object?>) {
    for (final MapEntry<String, Object?> entry in value.entries) {
      if (entry.key.length > 1000) {
        throw const BackupSnapshotException(
          'BackupInvalid',
          'Backup JSON data contains an oversized key.',
        );
      }
      _validateJsonValue(entry.value, depth + 1);
    }
    return;
  }
  throw const BackupSnapshotException(
    'BackupInvalid',
    'Backup contains a value that cannot be represented as JSON.',
  );
}

int _positiveInt(Map<String, Object?> json, String key) {
  final int value = _requiredInt(json, key);
  if (value < 1) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be positive.',
    );
  }
  return value;
}

int _nonNegativeInt(Map<String, Object?> json, String key) {
  final int value = _requiredInt(json, key);
  if (value < 0) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must not be negative.',
    );
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! bool) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be a boolean.',
    );
  }
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final DateTime? value = DateTime.tryParse(_requiredString(json, key));
  if (value == null) {
    throw BackupSnapshotException(
      'BackupInvalid',
      'Backup field "$key" must be a timestamp.',
    );
  }
  return value.toUtc();
}
