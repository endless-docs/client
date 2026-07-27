import 'dart:convert';
import 'dart:io';

import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';
import 'package:locald/locald.dart';
import 'package:persistence_isar/persistence_isar.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cold restart preserves offline document and duplicate command outcome',
    () async {
      final Directory temporary = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
        'locald-${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporary.create(recursive: true);
      addTearDown(() async {
        if (await temporary.exists()) {
          await temporary.delete(recursive: true);
        }
      });

      LocaldServer server = await LocaldServer.start(
        profileRoot: temporary.path,
        nativeLibraryPath:
            '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
        allowDevelopmentIsarDownload: true,
      );
      EndpointManifest endpoint = (await server.paths.readEndpoint())!;
      HttpLocalApiClient client = HttpLocalApiClient(endpoint: endpoint);
      await client.handshake(
        clientType: LocalClientType.integration,
        profileId: 'default',
      );

      final JsonMap workspace = await client.createWorkspace(
        commandId: 'workspace-command',
        name: 'Offline',
      );
      final JsonMap replay = await client.createWorkspace(
        commandId: 'workspace-command',
        name: 'Offline',
      );
      expect(replay['was_replay'], isTrue);
      expect(replay['workspace_id'], workspace['workspace_id']);

      final JsonMap document = await client.createDocument(
        commandId: 'document-command',
        workspaceId: requireString(workspace, 'workspace_id'),
        title: 'First note',
      );
      final JsonMap saved = await client.saveDocument(
        commandId: 'save-command',
        documentId: requireString(document, 'document_id'),
        title: 'First note',
        blocks: <JsonMap>[
          <String, Object?>{
            'type': 'paragraph',
            'payload': <String, Object?>{'text': 'Available without cloud'},
          },
        ],
        expectedRevision: requireInt(document, 'revision'),
      );
      final JsonMap child = await client.createDocument(
        commandId: 'child-command',
        workspaceId: requireString(workspace, 'workspace_id'),
        title: 'Nested note',
        parentId: requireString(saved, 'document_id'),
      );
      expect(
        await client.searchDocuments(
          workspaceId: requireString(workspace, 'workspace_id'),
          query: 'cloud',
        ),
        hasLength(1),
      );
      final JsonMap deletedParent = await client.deleteDocument(
        commandId: 'delete-tree-command',
        documentId: requireString(saved, 'document_id'),
        expectedRevision: requireInt(saved, 'revision'),
      );
      final List<JsonMap> recycle = await client.listDocuments(
        workspaceId: requireString(workspace, 'workspace_id'),
        includeDeleted: true,
      );
      expect(recycle, hasLength(2));
      expect(
        recycle,
        everyElement(
          isA<JsonMap>().having(
            (JsonMap item) => item['is_deleted'],
            'is_deleted',
            isTrue,
          ),
        ),
      );
      expect(
        await client.searchDocuments(
          workspaceId: requireString(workspace, 'workspace_id'),
          query: 'cloud',
        ),
        isEmpty,
      );
      await expectLater(
        client.restoreDocument(
          commandId: 'restore-child-too-early',
          documentId: requireString(child, 'document_id'),
        ),
        throwsA(
          isA<LocalApiException>().having(
            (LocalApiException error) => error.code,
            'code',
            'InvalidParent',
          ),
        ),
      );
      await client.restoreDocument(
        commandId: 'restore-parent-command',
        documentId: requireString(saved, 'document_id'),
        expectedRevision: requireInt(deletedParent, 'revision'),
      );
      final JsonMap deletedChild = await client.getDocument(
        requireString(child, 'document_id'),
      );
      await client.restoreDocument(
        commandId: 'restore-child-command',
        documentId: requireString(child, 'document_id'),
        expectedRevision: requireInt(deletedChild, 'revision'),
      );
      final JsonMap rebuilt = await client.rebuildSearchIndex(
        commandId: 'rebuild-search-command',
      );
      expect(rebuilt['is_current'], isTrue);
      expect(rebuilt['document_count'], 2);

      expect(await _unauthenticatedStatus(endpoint), HttpStatus.unauthorized);
      final String databasePath = server.paths.database.path;
      await client.close();
      await server.close();

      final IsarClientStore postUpgradeStore = await IsarClientStore.open(
        directory: databasePath,
        nativeLibraryPath:
            '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
        allowDevelopmentDownload: true,
      );
      await postUpgradeStore.write((writer) async {
        await writer.removeSearchProjection(
          requireString(saved, 'document_id'),
        );
        await writer.setSearchIndexedSequence(0);
      });
      await postUpgradeStore.close();

      server = await LocaldServer.start(
        profileRoot: temporary.path,
        nativeLibraryPath:
            '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
        allowDevelopmentIsarDownload: true,
      );
      addTearDown(server.close);
      endpoint = (await server.paths.readEndpoint())!;
      client = HttpLocalApiClient(endpoint: endpoint);
      addTearDown(client.close);
      await client.handshake(
        clientType: LocalClientType.integration,
        profileId: 'default',
      );

      final JsonMap restored = await client.getDocument(
        requireString(saved, 'document_id'),
      );
      final JsonMap payload = requireMap(
        requireMapList(restored, 'blocks').single,
        'payload',
      );
      expect(payload['text'], 'Available without cloud');
      expect(
        await client.listDocuments(
          workspaceId: requireString(workspace, 'workspace_id'),
        ),
        hasLength(2),
      );
      final List<JsonMap> search = await client.searchDocuments(
        workspaceId: requireString(workspace, 'workspace_id'),
        query: 'cloud',
      );
      expect(search, hasLength(1));
      expect(search.single['document_id'], saved['document_id']);
      expect(search.single['indexed_sequence'], isA<int>());
      final JsonMap repairedStatus = await client.getSearchStatus();
      expect(repairedStatus['is_current'], isTrue);
      expect(repairedStatus['document_count'], 2);

      final JsonMap lifecycleWorkspace = await client.createWorkspace(
        commandId: 'lifecycle-workspace',
        name: 'Lifecycle',
      );
      final JsonMap lifecycleDocument = await client.createDocument(
        commandId: 'lifecycle-document',
        workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
        title: 'Will be tombstoned',
      );
      final JsonMap archived = await client.archiveWorkspace(
        commandId: 'archive-workspace',
        workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
        archived: true,
        expectedRevision: 1,
      );
      expect(archived['lifecycle'], 'archived');
      await expectLater(
        client.createDocument(
          commandId: 'archive-write-rejected',
          workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
          title: 'Rejected',
        ),
        throwsA(
          isA<LocalApiException>().having(
            (LocalApiException error) => error.code,
            'code',
            'WorkspaceNotFound',
          ),
        ),
      );
      final JsonMap renamed = await client.renameWorkspace(
        commandId: 'rename-archived-workspace',
        workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
        name: 'Reference',
        expectedRevision: requireInt(archived, 'revision'),
      );
      final JsonMap active = await client.archiveWorkspace(
        commandId: 'restore-workspace',
        workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
        archived: false,
        expectedRevision: requireInt(renamed, 'revision'),
      );
      final JsonMap deletedWorkspace = await client.deleteWorkspace(
        commandId: 'delete-workspace',
        workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
        expectedRevision: requireInt(active, 'revision'),
      );
      expect(deletedWorkspace['lifecycle'], 'deleted');
      expect(
        (await client.getDocument(
          requireString(lifecycleDocument, 'document_id'),
        ))['is_deleted'],
        isTrue,
      );
      expect(
        (await client.deleteWorkspace(
          commandId: 'delete-workspace',
          workspaceId: requireString(lifecycleWorkspace, 'workspace_id'),
          expectedRevision: requireInt(active, 'revision'),
        ))['was_replay'],
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<int> _unauthenticatedStatus(EndpointManifest endpoint) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.postUrl(
      endpoint.baseUri.resolve('/v1/health'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(const <String, Object?>{}));
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}
