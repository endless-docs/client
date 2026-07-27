import 'package:isar_community/isar.dart';

part 'schema_v1.g.dart';

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
class RuntimeStateRecord {
  Id id = 1;

  late int eventSequence;
}
