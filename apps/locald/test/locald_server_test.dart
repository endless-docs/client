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

  test(
    'streams, deduplicates, downloads, and cold-reopens attachments',
    () async {
      final Directory temporary = await _temporaryProfile('attachments');
      addTearDown(() => _deleteProfile(temporary));
      LocaldServer server = await _startLocald(temporary);
      HttpLocalApiClient client = await _clientFor(server);
      addTearDown(() async {
        await client.close();
        await server.close();
      });

      final JsonMap workspace = await client.createWorkspace(
        commandId: 'workspace',
        name: 'Files',
      );
      final JsonMap document = await client.createDocument(
        commandId: 'document',
        workspaceId: requireString(workspace, 'workspace_id'),
        title: 'Attachment owner',
      );
      final int byteCount = maximumRequestBytes + 256 * 1024;
      final JsonMap firstStage = await client.stageAttachment(
        bytes: _patternBytes(byteCount),
        fileName: 'offline.bin',
        mediaType: 'application/octet-stream',
        contentLength: byteCount,
      );
      final JsonMap first = await client.attachStagedFile(
        commandId: 'attach-first',
        documentId: requireString(document, 'document_id'),
        stagingToken: requireString(firstStage, 'token'),
        expectedDocumentRevision: 1,
      );
      final JsonMap secondStage = await client.stageAttachment(
        bytes: _patternBytes(byteCount),
        fileName: 'duplicate.bin',
        mediaType: 'application/octet-stream',
        contentLength: byteCount,
      );
      final JsonMap second = await client.attachStagedFile(
        commandId: 'attach-second',
        documentId: requireString(document, 'document_id'),
        stagingToken: requireString(secondStage, 'token'),
        expectedDocumentRevision: 1,
      );

      expect(first['sha256'], second['sha256']);
      expect(
        await client.listAttachments(
          documentId: requireString(document, 'document_id'),
        ),
        hasLength(2),
      );
      await _expectPatternDownload(
        await client.downloadAttachment(requireString(first, 'attachment_id')),
        byteCount,
      );
      final List<File> contentFiles = await server.paths.attachments
          .list(recursive: true, followLinks: false)
          .where((FileSystemEntity entity) => entity is File)
          .cast<File>()
          .toList();
      expect(contentFiles, hasLength(1));

      await client.close();
      await server.close();
      server = await _startLocald(temporary);
      client = await _clientFor(server);

      expect(
        await client.listAttachments(
          documentId: requireString(document, 'document_id'),
        ),
        hasLength(2),
      );
      final JsonMap replay = await client.attachStagedFile(
        commandId: 'attach-first',
        documentId: requireString(document, 'document_id'),
        stagingToken: requireString(firstStage, 'token'),
        expectedDocumentRevision: 1,
      );
      expect(replay['was_replay'], isTrue);
      await _expectPatternDownload(
        await client.downloadAttachment(requireString(first, 'attachment_id')),
        byteCount,
      );

      final JsonMap deleted = await client.deleteAttachment(
        commandId: 'delete-first',
        attachmentId: requireString(first, 'attachment_id'),
        expectedRevision: 1,
      );
      expect(deleted['is_deleted'], isTrue);
      expect(
        await client.listAttachments(
          documentId: requireString(document, 'document_id'),
        ),
        hasLength(1),
      );
      await expectLater(
        client.downloadAttachment(requireString(first, 'attachment_id')),
        throwsA(
          isA<LocalApiException>().having(
            (LocalApiException error) => error.code,
            'code',
            'AttachmentNotFound',
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'versioned backup restores a clean profile with history, search, and files',
    () async {
      final Directory sourceProfile = await _temporaryProfile('backup-source');
      final Directory targetProfile = await _temporaryProfile('backup-target');
      addTearDown(() => _deleteProfile(sourceProfile));
      addTearDown(() => _deleteProfile(targetProfile));

      LocaldServer sourceServer = await _startLocald(sourceProfile);
      HttpLocalApiClient sourceClient = await _clientFor(sourceServer);
      final JsonMap workspace = await sourceClient.createWorkspace(
        commandId: 'portable-workspace',
        name: 'Portable',
      );
      final String workspaceId = requireString(workspace, 'workspace_id');
      final JsonMap document = await sourceClient.createDocument(
        commandId: 'portable-document',
        workspaceId: workspaceId,
        title: 'Offline backup',
      );
      final String documentId = requireString(document, 'document_id');
      await sourceClient.saveDocument(
        commandId: 'portable-save',
        documentId: documentId,
        title: 'Offline backup',
        blocks: <JsonMap>[
          <String, Object?>{
            'type': 'paragraph',
            'payload': <String, Object?>{
              'text': 'search survives clean restore',
            },
          },
        ],
        expectedRevision: 1,
      );
      final JsonMap deletedDocument = await sourceClient.createDocument(
        commandId: 'deleted-document',
        workspaceId: workspaceId,
        title: 'Recycle metadata',
      );
      await sourceClient.deleteDocument(
        commandId: 'delete-document',
        documentId: requireString(deletedDocument, 'document_id'),
        expectedRevision: 1,
      );
      final List<int> attachmentBytes = utf8.encode(
        'portable attachment content',
      );
      final JsonMap staged = await sourceClient.stageAttachment(
        bytes: Stream<List<int>>.value(attachmentBytes),
        fileName: 'portable.txt',
        mediaType: 'text/plain',
        contentLength: attachmentBytes.length,
      );
      final JsonMap attachment = await sourceClient.attachStagedFile(
        commandId: 'portable-attachment',
        documentId: documentId,
        stagingToken: requireString(staged, 'token'),
      );
      final ProfileBackupDownload exported = await sourceClient.exportBackup();
      final List<int> archiveBytes = await exported.bytes
          .expand((List<int> chunk) => chunk)
          .toList();
      expect(archiveBytes, hasLength(exported.size));
      await sourceClient.close();
      await sourceServer.close();

      LocaldServer targetServer = await _startLocald(targetProfile);
      HttpLocalApiClient targetClient = await _clientFor(targetServer);
      addTearDown(() async {
        await targetClient.close();
        await targetServer.close();
      });
      final List<int> corrupted = <int>[...archiveBytes]..last ^= 0xff;
      await expectLater(
        targetClient.restoreBackup(
          bytes: Stream<List<int>>.value(corrupted),
          contentLength: corrupted.length,
        ),
        throwsA(
          isA<LocalApiException>().having(
            (LocalApiException error) => error.code,
            'code',
            'BackupAttachmentMismatch',
          ),
        ),
      );
      expect(await targetClient.listWorkspaces(), isEmpty);

      final JsonMap restored = await targetClient.restoreBackup(
        bytes: Stream<List<int>>.value(archiveBytes),
        contentLength: archiveBytes.length,
      );
      expect(restored['format_version'], 1);
      expect(restored['workspaces'], 1);
      expect(restored['documents'], 2);
      expect(restored['attachments'], 1);
      expect(
        await targetClient.listDocuments(
          workspaceId: workspaceId,
          includeDeleted: true,
        ),
        hasLength(2),
      );
      expect(
        await targetClient.searchDocuments(
          workspaceId: workspaceId,
          query: 'clean restore',
        ),
        hasLength(1),
      );
      final AttachmentDownload download = await targetClient.downloadAttachment(
        requireString(attachment, 'attachment_id'),
      );
      expect(
        await download.bytes.expand((List<int> chunk) => chunk).toList(),
        attachmentBytes,
      );
      final JsonMap replay = await targetClient.createWorkspace(
        commandId: 'portable-workspace',
        name: 'Portable',
      );
      expect(replay['was_replay'], isTrue);
      expect(replay['workspace_id'], workspaceId);
      await expectLater(
        targetClient.restoreBackup(
          bytes: Stream<List<int>>.value(archiveBytes),
          contentLength: archiveBytes.length,
        ),
        throwsA(
          isA<LocalApiException>().having(
            (LocalApiException error) => error.code,
            'code',
            'RestoreTargetNotEmpty',
          ),
        ),
      );

      await targetClient.close();
      await targetServer.close();
      targetServer = await _startLocald(targetProfile);
      targetClient = await _clientFor(targetServer);
      expect(
        await targetClient.searchDocuments(
          workspaceId: workspaceId,
          query: 'survives',
        ),
        hasLength(1),
      );
      expect(
        await targetClient.listAttachments(documentId: documentId),
        hasLength(1),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final LocaldWriteStep step in LocaldWriteStep.values) {
    test(
      'startup repairs attachment interrupted at ${step.name}',
      () async {
        final Directory temporary = await _temporaryProfile(
          'attachment-recovery-${step.name}',
        );
        addTearDown(() => _deleteProfile(temporary));
        final _FailLocaldOnce injector = _FailLocaldOnce(step);
        LocaldServer server = await _startLocald(
          temporary,
          faultInjector: injector.call,
        );
        HttpLocalApiClient client = await _clientFor(server);
        addTearDown(() async {
          await client.close();
          await server.close();
        });
        final JsonMap workspace = await client.createWorkspace(
          commandId: 'workspace',
          name: 'Recovery',
        );
        final JsonMap document = await client.createDocument(
          commandId: 'document',
          workspaceId: requireString(workspace, 'workspace_id'),
          title: 'Interrupted attachment',
        );
        final JsonMap staged = await client.stageAttachment(
          bytes: Stream<List<int>>.value(utf8.encode('recover offline bytes')),
          fileName: 'recovery.txt',
          mediaType: 'text/plain',
          contentLength: utf8.encode('recover offline bytes').length,
        );

        await expectLater(
          client.attachStagedFile(
            commandId: 'attach',
            documentId: requireString(document, 'document_id'),
            stagingToken: requireString(staged, 'token'),
          ),
          throwsA(
            isA<LocalApiException>().having(
              (LocalApiException error) => error.code,
              'code',
              'Internal',
            ),
          ),
        );
        expect(
          await client.listAttachments(
            documentId: requireString(document, 'document_id'),
          ),
          isEmpty,
        );
        await client.close();
        await server.close();

        server = await _startLocald(temporary);
        client = await _clientFor(server);
        final List<JsonMap> repaired = await client.listAttachments(
          documentId: requireString(document, 'document_id'),
        );

        expect(repaired, hasLength(1));
        final AttachmentDownload download = await client.downloadAttachment(
          requireString(repaired.single, 'attachment_id'),
        );
        expect(
          utf8.decode(
            await download.bytes.expand((List<int> chunk) => chunk).toList(),
          ),
          'recover offline bytes',
        );
        final JsonMap replay = await client.attachStagedFile(
          commandId: 'attach',
          documentId: requireString(document, 'document_id'),
          stagingToken: requireString(staged, 'token'),
        );
        expect(replay['was_replay'], isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

Future<Directory> _temporaryProfile(String suffix) async {
  final Directory directory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
    '$suffix-${DateTime.now().microsecondsSinceEpoch}',
  );
  await directory.create(recursive: true);
  return directory;
}

Future<void> _deleteProfile(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<LocaldServer> _startLocald(
  Directory profile, {
  LocaldFaultInjector? faultInjector,
}) => LocaldServer.start(
  profileRoot: profile.path,
  nativeLibraryPath:
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}isar${Platform.pathSeparator}isar.dll',
  allowDevelopmentIsarDownload: true,
  faultInjector: faultInjector,
);

Future<HttpLocalApiClient> _clientFor(LocaldServer server) async {
  final EndpointManifest endpoint = (await server.paths.readEndpoint())!;
  final HttpLocalApiClient client = HttpLocalApiClient(endpoint: endpoint);
  await client.handshake(
    clientType: LocalClientType.integration,
    profileId: 'default',
  );
  return client;
}

Stream<List<int>> _patternBytes(int total) async* {
  const int chunkSize = 64 * 1024;
  for (int offset = 0; offset < total; offset += chunkSize) {
    final int length = (total - offset).clamp(0, chunkSize);
    yield List<int>.generate(
      length,
      (int index) => (offset + index) % 251,
      growable: false,
    );
  }
}

Future<void> _expectPatternDownload(
  AttachmentDownload download,
  int expectedSize,
) async {
  int offset = 0;
  await for (final List<int> chunk in download.bytes) {
    for (int index = 0; index < chunk.length; index++) {
      if (chunk[index] != (offset + index) % 251) {
        fail('Attachment content differs at byte ${offset + index}.');
      }
    }
    offset += chunk.length;
  }
  expect(download.size, expectedSize);
  expect(offset, expectedSize);
}

final class _FailLocaldOnce {
  _FailLocaldOnce(this.step);

  final LocaldWriteStep step;
  bool _armed = true;

  void call(LocaldWriteStep candidate) {
    if (_armed && candidate == step) {
      _armed = false;
      throw StateError('Injected locald failure at ${step.name}.');
    }
  }
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
