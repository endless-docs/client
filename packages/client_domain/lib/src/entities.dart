enum WorkspaceLifecycle { active, archived, deleted }

enum BlockType { paragraph, heading, list, code, quote, unsupported }

final class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.lifecycle,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final WorkspaceLifecycle lifecycle;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workspace rename(String value, DateTime now) => Workspace(
    id: id,
    name: value,
    lifecycle: lifecycle,
    revision: revision + 1,
    createdAt: createdAt,
    updatedAt: now,
  );

  Workspace changeLifecycle(WorkspaceLifecycle value, DateTime now) =>
      Workspace(
        id: id,
        name: name,
        lifecycle: value,
        revision: revision + 1,
        createdAt: createdAt,
        updatedAt: now,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'workspace_id': id,
    'name': name,
    'kind': 'local',
    'lifecycle': lifecycle.name,
    'revision': revision,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

final class Document {
  const Document({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.parentId,
    required this.position,
    required this.blocks,
    required this.revision,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? parentId;
  final int position;
  final List<Block> blocks;
  final int revision;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Document updateContent({
    required String title,
    required List<Block> blocks,
    required DateTime now,
  }) => Document(
    id: id,
    workspaceId: workspaceId,
    title: title,
    parentId: parentId,
    position: position,
    blocks: List<Block>.unmodifiable(blocks),
    revision: revision + 1,
    isDeleted: isDeleted,
    createdAt: createdAt,
    updatedAt: now,
  );

  Document move({
    required String? parentId,
    required int position,
    required DateTime now,
  }) => Document(
    id: id,
    workspaceId: workspaceId,
    title: title,
    parentId: parentId,
    position: position,
    blocks: blocks,
    revision: revision + 1,
    isDeleted: isDeleted,
    createdAt: createdAt,
    updatedAt: now,
  );

  Document markDeleted(bool value, DateTime now) => Document(
    id: id,
    workspaceId: workspaceId,
    title: title,
    parentId: parentId,
    position: position,
    blocks: blocks,
    revision: revision + 1,
    isDeleted: value,
    createdAt: createdAt,
    updatedAt: now,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'document_id': id,
    'workspace_id': workspaceId,
    'title': title,
    'parent_id': parentId,
    'position': position,
    'blocks': blocks.map((Block block) => block.toJson()).toList(),
    'revision': revision,
    'is_deleted': isDeleted,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

final class Block {
  const Block({
    required this.id,
    required this.documentId,
    required this.type,
    required this.payload,
    required this.position,
    required this.revision,
  });

  final String id;
  final String documentId;
  final BlockType type;
  final Map<String, Object?> payload;
  final int position;
  final int revision;

  Map<String, Object?> toJson() => <String, Object?>{
    'block_id': id,
    'document_id': documentId,
    'type': type.name,
    'payload': payload,
    'position': position,
    'revision': revision,
  };
}

final class CommandOutcome {
  const CommandOutcome({
    required this.commandId,
    required this.method,
    required this.fingerprint,
    required this.result,
    required this.commitSequence,
  });

  final String commandId;
  final String method;
  final String fingerprint;
  final Map<String, Object?> result;
  final int commitSequence;
}

final class Operation {
  const Operation({
    required this.id,
    required this.workspaceId,
    required this.objectId,
    required this.sequence,
    required this.type,
    required this.baseRevision,
    required this.resultRevision,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String objectId;
  final int sequence;
  final String type;
  final int baseRevision;
  final int resultRevision;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}
