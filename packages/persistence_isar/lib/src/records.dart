import 'package:isar_community/isar.dart';

part 'records.g.dart';

@collection
class WorkspaceRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String workspaceId;

  late String name;
  late String lifecycle;
  late int revision;
  late DateTime createdAt;
  late DateTime updatedAt;
}

@collection
class DocumentRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String documentId;

  @Index()
  late String workspaceId;

  String? parentId;
  late String title;
  late int position;
  late int revision;
  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;
}

@collection
class BlockRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String blockId;

  @Index()
  late String documentId;

  late String type;
  late String payloadJson;
  late int position;
  late int revision;
}

@collection
class CommandOutcomeRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String commandId;

  late String method;
  late String fingerprint;
  late String resultJson;
  late int commitSequence;
}

@collection
class OperationRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String operationId;

  @Index()
  late String workspaceId;

  late String objectId;

  @Index(unique: true)
  late int sequence;

  late String type;
  late int baseRevision;
  late int resultRevision;
  late String payloadJson;
  late DateTime createdAt;
}

@collection
class RuntimeStateRecord {
  Id id = 1;

  late int eventSequence;
}
