// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_v1.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkspaceRecordCollection on Isar {
  IsarCollection<WorkspaceRecord> get workspaceRecords => this.collection();
}

const WorkspaceRecordSchema = CollectionSchema(
  name: r'WorkspaceRecord',
  id: -8698354352574925957,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'lifecycle': PropertySchema(
      id: 1,
      name: r'lifecycle',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 2, name: r'name', type: IsarType.string),
    r'revision': PropertySchema(id: 3, name: r'revision', type: IsarType.long),
    r'updatedAt': PropertySchema(
      id: 4,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'workspaceId': PropertySchema(
      id: 5,
      name: r'workspaceId',
      type: IsarType.string,
    ),
  },

  estimateSize: _workspaceRecordEstimateSize,
  serialize: _workspaceRecordSerialize,
  deserialize: _workspaceRecordDeserialize,
  deserializeProp: _workspaceRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'workspaceId': IndexSchema(
      id: 4360577223095013563,
      name: r'workspaceId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workspaceId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _workspaceRecordGetId,
  getLinks: _workspaceRecordGetLinks,
  attach: _workspaceRecordAttach,
  version: '3.3.2',
);

int _workspaceRecordEstimateSize(
  WorkspaceRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.lifecycle.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.workspaceId.length * 3;
  return bytesCount;
}

void _workspaceRecordSerialize(
  WorkspaceRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.lifecycle);
  writer.writeString(offsets[2], object.name);
  writer.writeLong(offsets[3], object.revision);
  writer.writeDateTime(offsets[4], object.updatedAt);
  writer.writeString(offsets[5], object.workspaceId);
}

WorkspaceRecord _workspaceRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkspaceRecord();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.lifecycle = reader.readString(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.revision = reader.readLong(offsets[3]);
  object.updatedAt = reader.readDateTime(offsets[4]);
  object.workspaceId = reader.readString(offsets[5]);
  return object;
}

P _workspaceRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workspaceRecordGetId(WorkspaceRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workspaceRecordGetLinks(WorkspaceRecord object) {
  return [];
}

void _workspaceRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  WorkspaceRecord object,
) {
  object.id = id;
}

extension WorkspaceRecordByIndex on IsarCollection<WorkspaceRecord> {
  Future<WorkspaceRecord?> getByWorkspaceId(String workspaceId) {
    return getByIndex(r'workspaceId', [workspaceId]);
  }

  WorkspaceRecord? getByWorkspaceIdSync(String workspaceId) {
    return getByIndexSync(r'workspaceId', [workspaceId]);
  }

  Future<bool> deleteByWorkspaceId(String workspaceId) {
    return deleteByIndex(r'workspaceId', [workspaceId]);
  }

  bool deleteByWorkspaceIdSync(String workspaceId) {
    return deleteByIndexSync(r'workspaceId', [workspaceId]);
  }

  Future<List<WorkspaceRecord?>> getAllByWorkspaceId(
    List<String> workspaceIdValues,
  ) {
    final values = workspaceIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'workspaceId', values);
  }

  List<WorkspaceRecord?> getAllByWorkspaceIdSync(
    List<String> workspaceIdValues,
  ) {
    final values = workspaceIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'workspaceId', values);
  }

  Future<int> deleteAllByWorkspaceId(List<String> workspaceIdValues) {
    final values = workspaceIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'workspaceId', values);
  }

  int deleteAllByWorkspaceIdSync(List<String> workspaceIdValues) {
    final values = workspaceIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'workspaceId', values);
  }

  Future<Id> putByWorkspaceId(WorkspaceRecord object) {
    return putByIndex(r'workspaceId', object);
  }

  Id putByWorkspaceIdSync(WorkspaceRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'workspaceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByWorkspaceId(List<WorkspaceRecord> objects) {
    return putAllByIndex(r'workspaceId', objects);
  }

  List<Id> putAllByWorkspaceIdSync(
    List<WorkspaceRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'workspaceId', objects, saveLinks: saveLinks);
  }
}

extension WorkspaceRecordQueryWhereSort
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QWhere> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkspaceRecordQueryWhere
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QWhereClause> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause>
  workspaceIdEqualTo(String workspaceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'workspaceId',
          value: [workspaceId],
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterWhereClause>
  workspaceIdNotEqualTo(String workspaceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [],
                upper: [workspaceId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [workspaceId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [workspaceId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [],
                upper: [workspaceId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension WorkspaceRecordQueryFilter
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QFilterCondition> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lifecycle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lifecycle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lifecycle',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lifecycle', value: ''),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  lifecycleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lifecycle', value: ''),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  revisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'revision', value: value),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  revisionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  revisionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  revisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'revision',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workspaceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workspaceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workspaceId', value: ''),
      );
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterFilterCondition>
  workspaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workspaceId', value: ''),
      );
    });
  }
}

extension WorkspaceRecordQueryObject
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QFilterCondition> {}

extension WorkspaceRecordQueryLinks
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QFilterCondition> {}

extension WorkspaceRecordQuerySortBy
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QSortBy> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByLifecycle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycle', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByLifecycleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycle', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  sortByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension WorkspaceRecordQuerySortThenBy
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QSortThenBy> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByLifecycle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycle', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByLifecycleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycle', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QAfterSortBy>
  thenByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension WorkspaceRecordQueryWhereDistinct
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct> {
  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct>
  distinctByLifecycle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lifecycle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct>
  distinctByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revision');
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<WorkspaceRecord, WorkspaceRecord, QDistinct>
  distinctByWorkspaceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workspaceId', caseSensitive: caseSensitive);
    });
  }
}

extension WorkspaceRecordQueryProperty
    on QueryBuilder<WorkspaceRecord, WorkspaceRecord, QQueryProperty> {
  QueryBuilder<WorkspaceRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkspaceRecord, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<WorkspaceRecord, String, QQueryOperations> lifecycleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lifecycle');
    });
  }

  QueryBuilder<WorkspaceRecord, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<WorkspaceRecord, int, QQueryOperations> revisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revision');
    });
  }

  QueryBuilder<WorkspaceRecord, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<WorkspaceRecord, String, QQueryOperations>
  workspaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workspaceId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDocumentRecordCollection on Isar {
  IsarCollection<DocumentRecord> get documentRecords => this.collection();
}

const DocumentRecordSchema = CollectionSchema(
  name: r'DocumentRecord',
  id: -6659274952819810601,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'documentId': PropertySchema(
      id: 1,
      name: r'documentId',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 2,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'parentId': PropertySchema(
      id: 3,
      name: r'parentId',
      type: IsarType.string,
    ),
    r'position': PropertySchema(id: 4, name: r'position', type: IsarType.long),
    r'revision': PropertySchema(id: 5, name: r'revision', type: IsarType.long),
    r'title': PropertySchema(id: 6, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 7,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'workspaceId': PropertySchema(
      id: 8,
      name: r'workspaceId',
      type: IsarType.string,
    ),
  },

  estimateSize: _documentRecordEstimateSize,
  serialize: _documentRecordSerialize,
  deserialize: _documentRecordDeserialize,
  deserializeProp: _documentRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'documentId': IndexSchema(
      id: 4187168439921340405,
      name: r'documentId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'documentId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'workspaceId': IndexSchema(
      id: 4360577223095013563,
      name: r'workspaceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workspaceId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _documentRecordGetId,
  getLinks: _documentRecordGetLinks,
  attach: _documentRecordAttach,
  version: '3.3.2',
);

int _documentRecordEstimateSize(
  DocumentRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.documentId.length * 3;
  {
    final value = object.parentId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.workspaceId.length * 3;
  return bytesCount;
}

void _documentRecordSerialize(
  DocumentRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.documentId);
  writer.writeBool(offsets[2], object.isDeleted);
  writer.writeString(offsets[3], object.parentId);
  writer.writeLong(offsets[4], object.position);
  writer.writeLong(offsets[5], object.revision);
  writer.writeString(offsets[6], object.title);
  writer.writeDateTime(offsets[7], object.updatedAt);
  writer.writeString(offsets[8], object.workspaceId);
}

DocumentRecord _documentRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DocumentRecord();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.documentId = reader.readString(offsets[1]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[2]);
  object.parentId = reader.readStringOrNull(offsets[3]);
  object.position = reader.readLong(offsets[4]);
  object.revision = reader.readLong(offsets[5]);
  object.title = reader.readString(offsets[6]);
  object.updatedAt = reader.readDateTime(offsets[7]);
  object.workspaceId = reader.readString(offsets[8]);
  return object;
}

P _documentRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _documentRecordGetId(DocumentRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _documentRecordGetLinks(DocumentRecord object) {
  return [];
}

void _documentRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  DocumentRecord object,
) {
  object.id = id;
}

extension DocumentRecordByIndex on IsarCollection<DocumentRecord> {
  Future<DocumentRecord?> getByDocumentId(String documentId) {
    return getByIndex(r'documentId', [documentId]);
  }

  DocumentRecord? getByDocumentIdSync(String documentId) {
    return getByIndexSync(r'documentId', [documentId]);
  }

  Future<bool> deleteByDocumentId(String documentId) {
    return deleteByIndex(r'documentId', [documentId]);
  }

  bool deleteByDocumentIdSync(String documentId) {
    return deleteByIndexSync(r'documentId', [documentId]);
  }

  Future<List<DocumentRecord?>> getAllByDocumentId(
    List<String> documentIdValues,
  ) {
    final values = documentIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'documentId', values);
  }

  List<DocumentRecord?> getAllByDocumentIdSync(List<String> documentIdValues) {
    final values = documentIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'documentId', values);
  }

  Future<int> deleteAllByDocumentId(List<String> documentIdValues) {
    final values = documentIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'documentId', values);
  }

  int deleteAllByDocumentIdSync(List<String> documentIdValues) {
    final values = documentIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'documentId', values);
  }

  Future<Id> putByDocumentId(DocumentRecord object) {
    return putByIndex(r'documentId', object);
  }

  Id putByDocumentIdSync(DocumentRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'documentId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDocumentId(List<DocumentRecord> objects) {
    return putAllByIndex(r'documentId', objects);
  }

  List<Id> putAllByDocumentIdSync(
    List<DocumentRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'documentId', objects, saveLinks: saveLinks);
  }
}

extension DocumentRecordQueryWhereSort
    on QueryBuilder<DocumentRecord, DocumentRecord, QWhere> {
  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DocumentRecordQueryWhere
    on QueryBuilder<DocumentRecord, DocumentRecord, QWhereClause> {
  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause>
  documentIdEqualTo(String documentId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'documentId', value: [documentId]),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause>
  documentIdNotEqualTo(String documentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [],
                upper: [documentId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [documentId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [documentId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [],
                upper: [documentId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause>
  workspaceIdEqualTo(String workspaceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'workspaceId',
          value: [workspaceId],
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterWhereClause>
  workspaceIdNotEqualTo(String workspaceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [],
                upper: [workspaceId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [workspaceId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [workspaceId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workspaceId',
                lower: [],
                upper: [workspaceId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension DocumentRecordQueryFilter
    on QueryBuilder<DocumentRecord, DocumentRecord, QFilterCondition> {
  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'documentId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'documentId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'documentId', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  documentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'documentId', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isDeleted', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parentId'),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parentId'),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parentId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'parentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'parentId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'parentId', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  parentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'parentId', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  positionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'position', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  positionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'position',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  positionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'position',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  positionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'position',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  revisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'revision', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  revisionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  revisionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  revisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'revision',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workspaceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workspaceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workspaceId', value: ''),
      );
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterFilterCondition>
  workspaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workspaceId', value: ''),
      );
    });
  }
}

extension DocumentRecordQueryObject
    on QueryBuilder<DocumentRecord, DocumentRecord, QFilterCondition> {}

extension DocumentRecordQueryLinks
    on QueryBuilder<DocumentRecord, DocumentRecord, QFilterCondition> {}

extension DocumentRecordQuerySortBy
    on QueryBuilder<DocumentRecord, DocumentRecord, QSortBy> {
  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByDocumentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByDocumentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByParentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByParentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  sortByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension DocumentRecordQuerySortThenBy
    on QueryBuilder<DocumentRecord, DocumentRecord, QSortThenBy> {
  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByDocumentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByDocumentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByParentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByParentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QAfterSortBy>
  thenByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension DocumentRecordQueryWhereDistinct
    on QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> {
  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> distinctByDocumentId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'documentId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct>
  distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> distinctByParentId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> distinctByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'position');
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> distinctByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revision');
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<DocumentRecord, DocumentRecord, QDistinct>
  distinctByWorkspaceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workspaceId', caseSensitive: caseSensitive);
    });
  }
}

extension DocumentRecordQueryProperty
    on QueryBuilder<DocumentRecord, DocumentRecord, QQueryProperty> {
  QueryBuilder<DocumentRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DocumentRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<DocumentRecord, String, QQueryOperations> documentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'documentId');
    });
  }

  QueryBuilder<DocumentRecord, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<DocumentRecord, String?, QQueryOperations> parentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentId');
    });
  }

  QueryBuilder<DocumentRecord, int, QQueryOperations> positionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'position');
    });
  }

  QueryBuilder<DocumentRecord, int, QQueryOperations> revisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revision');
    });
  }

  QueryBuilder<DocumentRecord, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<DocumentRecord, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<DocumentRecord, String, QQueryOperations> workspaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workspaceId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBlockRecordCollection on Isar {
  IsarCollection<BlockRecord> get blockRecords => this.collection();
}

const BlockRecordSchema = CollectionSchema(
  name: r'BlockRecord',
  id: -386041948165604815,
  properties: {
    r'blockId': PropertySchema(id: 0, name: r'blockId', type: IsarType.string),
    r'documentId': PropertySchema(
      id: 1,
      name: r'documentId',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 2,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'position': PropertySchema(id: 3, name: r'position', type: IsarType.long),
    r'revision': PropertySchema(id: 4, name: r'revision', type: IsarType.long),
    r'type': PropertySchema(id: 5, name: r'type', type: IsarType.string),
  },

  estimateSize: _blockRecordEstimateSize,
  serialize: _blockRecordSerialize,
  deserialize: _blockRecordDeserialize,
  deserializeProp: _blockRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'blockId': IndexSchema(
      id: -413886092950911832,
      name: r'blockId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'blockId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'documentId': IndexSchema(
      id: 4187168439921340405,
      name: r'documentId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'documentId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _blockRecordGetId,
  getLinks: _blockRecordGetLinks,
  attach: _blockRecordAttach,
  version: '3.3.2',
);

int _blockRecordEstimateSize(
  BlockRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.blockId.length * 3;
  bytesCount += 3 + object.documentId.length * 3;
  bytesCount += 3 + object.payloadJson.length * 3;
  bytesCount += 3 + object.type.length * 3;
  return bytesCount;
}

void _blockRecordSerialize(
  BlockRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.blockId);
  writer.writeString(offsets[1], object.documentId);
  writer.writeString(offsets[2], object.payloadJson);
  writer.writeLong(offsets[3], object.position);
  writer.writeLong(offsets[4], object.revision);
  writer.writeString(offsets[5], object.type);
}

BlockRecord _blockRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BlockRecord();
  object.blockId = reader.readString(offsets[0]);
  object.documentId = reader.readString(offsets[1]);
  object.id = id;
  object.payloadJson = reader.readString(offsets[2]);
  object.position = reader.readLong(offsets[3]);
  object.revision = reader.readLong(offsets[4]);
  object.type = reader.readString(offsets[5]);
  return object;
}

P _blockRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _blockRecordGetId(BlockRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _blockRecordGetLinks(BlockRecord object) {
  return [];
}

void _blockRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  BlockRecord object,
) {
  object.id = id;
}

extension BlockRecordByIndex on IsarCollection<BlockRecord> {
  Future<BlockRecord?> getByBlockId(String blockId) {
    return getByIndex(r'blockId', [blockId]);
  }

  BlockRecord? getByBlockIdSync(String blockId) {
    return getByIndexSync(r'blockId', [blockId]);
  }

  Future<bool> deleteByBlockId(String blockId) {
    return deleteByIndex(r'blockId', [blockId]);
  }

  bool deleteByBlockIdSync(String blockId) {
    return deleteByIndexSync(r'blockId', [blockId]);
  }

  Future<List<BlockRecord?>> getAllByBlockId(List<String> blockIdValues) {
    final values = blockIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'blockId', values);
  }

  List<BlockRecord?> getAllByBlockIdSync(List<String> blockIdValues) {
    final values = blockIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'blockId', values);
  }

  Future<int> deleteAllByBlockId(List<String> blockIdValues) {
    final values = blockIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'blockId', values);
  }

  int deleteAllByBlockIdSync(List<String> blockIdValues) {
    final values = blockIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'blockId', values);
  }

  Future<Id> putByBlockId(BlockRecord object) {
    return putByIndex(r'blockId', object);
  }

  Id putByBlockIdSync(BlockRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'blockId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBlockId(List<BlockRecord> objects) {
    return putAllByIndex(r'blockId', objects);
  }

  List<Id> putAllByBlockIdSync(
    List<BlockRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'blockId', objects, saveLinks: saveLinks);
  }
}

extension BlockRecordQueryWhereSort
    on QueryBuilder<BlockRecord, BlockRecord, QWhere> {
  QueryBuilder<BlockRecord, BlockRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BlockRecordQueryWhere
    on QueryBuilder<BlockRecord, BlockRecord, QWhereClause> {
  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> blockIdEqualTo(
    String blockId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'blockId', value: [blockId]),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> blockIdNotEqualTo(
    String blockId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockId',
                lower: [],
                upper: [blockId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockId',
                lower: [blockId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockId',
                lower: [blockId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockId',
                lower: [],
                upper: [blockId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause> documentIdEqualTo(
    String documentId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'documentId', value: [documentId]),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterWhereClause>
  documentIdNotEqualTo(String documentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [],
                upper: [documentId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [documentId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [documentId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'documentId',
                lower: [],
                upper: [documentId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension BlockRecordQueryFilter
    on QueryBuilder<BlockRecord, BlockRecord, QFilterCondition> {
  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  blockIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'blockId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  blockIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'blockId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> blockIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'blockId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  blockIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'blockId', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  blockIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'blockId', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'documentId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'documentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'documentId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'documentId', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  documentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'documentId', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payloadJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payloadJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> positionEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'position', value: value),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  positionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'position',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  positionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'position',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> positionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'position',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> revisionEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'revision', value: value),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  revisionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  revisionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'revision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> revisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'revision',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: ''),
      );
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterFilterCondition>
  typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'type', value: ''),
      );
    });
  }
}

extension BlockRecordQueryObject
    on QueryBuilder<BlockRecord, BlockRecord, QFilterCondition> {}

extension BlockRecordQueryLinks
    on QueryBuilder<BlockRecord, BlockRecord, QFilterCondition> {}

extension BlockRecordQuerySortBy
    on QueryBuilder<BlockRecord, BlockRecord, QSortBy> {
  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByBlockId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockId', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByBlockIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockId', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByDocumentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByDocumentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension BlockRecordQuerySortThenBy
    on QueryBuilder<BlockRecord, BlockRecord, QSortThenBy> {
  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByBlockId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockId', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByBlockIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockId', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByDocumentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByDocumentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'documentId', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension BlockRecordQueryWhereDistinct
    on QueryBuilder<BlockRecord, BlockRecord, QDistinct> {
  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByBlockId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'blockId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByDocumentId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'documentId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByPayloadJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'position');
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revision');
    });
  }

  QueryBuilder<BlockRecord, BlockRecord, QDistinct> distinctByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }
}

extension BlockRecordQueryProperty
    on QueryBuilder<BlockRecord, BlockRecord, QQueryProperty> {
  QueryBuilder<BlockRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BlockRecord, String, QQueryOperations> blockIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'blockId');
    });
  }

  QueryBuilder<BlockRecord, String, QQueryOperations> documentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'documentId');
    });
  }

  QueryBuilder<BlockRecord, String, QQueryOperations> payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<BlockRecord, int, QQueryOperations> positionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'position');
    });
  }

  QueryBuilder<BlockRecord, int, QQueryOperations> revisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revision');
    });
  }

  QueryBuilder<BlockRecord, String, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRuntimeStateRecordCollection on Isar {
  IsarCollection<RuntimeStateRecord> get runtimeStateRecords =>
      this.collection();
}

const RuntimeStateRecordSchema = CollectionSchema(
  name: r'RuntimeStateRecord',
  id: -1743164305870107799,
  properties: {
    r'eventSequence': PropertySchema(
      id: 0,
      name: r'eventSequence',
      type: IsarType.long,
    ),
  },

  estimateSize: _runtimeStateRecordEstimateSize,
  serialize: _runtimeStateRecordSerialize,
  deserialize: _runtimeStateRecordDeserialize,
  deserializeProp: _runtimeStateRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _runtimeStateRecordGetId,
  getLinks: _runtimeStateRecordGetLinks,
  attach: _runtimeStateRecordAttach,
  version: '3.3.2',
);

int _runtimeStateRecordEstimateSize(
  RuntimeStateRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _runtimeStateRecordSerialize(
  RuntimeStateRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.eventSequence);
}

RuntimeStateRecord _runtimeStateRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RuntimeStateRecord();
  object.eventSequence = reader.readLong(offsets[0]);
  object.id = id;
  return object;
}

P _runtimeStateRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _runtimeStateRecordGetId(RuntimeStateRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _runtimeStateRecordGetLinks(
  RuntimeStateRecord object,
) {
  return [];
}

void _runtimeStateRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  RuntimeStateRecord object,
) {
  object.id = id;
}

extension RuntimeStateRecordQueryWhereSort
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QWhere> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RuntimeStateRecordQueryWhere
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QWhereClause> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RuntimeStateRecordQueryFilter
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QFilterCondition> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  eventSequenceEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eventSequence', value: value),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  eventSequenceGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'eventSequence',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  eventSequenceLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'eventSequence',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  eventSequenceBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'eventSequence',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RuntimeStateRecordQueryObject
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QFilterCondition> {}

extension RuntimeStateRecordQueryLinks
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QFilterCondition> {}

extension RuntimeStateRecordQuerySortBy
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QSortBy> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  sortByEventSequence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventSequence', Sort.asc);
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  sortByEventSequenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventSequence', Sort.desc);
    });
  }
}

extension RuntimeStateRecordQuerySortThenBy
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QSortThenBy> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  thenByEventSequence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventSequence', Sort.asc);
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  thenByEventSequenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventSequence', Sort.desc);
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension RuntimeStateRecordQueryWhereDistinct
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QDistinct> {
  QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QDistinct>
  distinctByEventSequence() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventSequence');
    });
  }
}

extension RuntimeStateRecordQueryProperty
    on QueryBuilder<RuntimeStateRecord, RuntimeStateRecord, QQueryProperty> {
  QueryBuilder<RuntimeStateRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RuntimeStateRecord, int, QQueryOperations>
  eventSequenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventSequence');
    });
  }
}
