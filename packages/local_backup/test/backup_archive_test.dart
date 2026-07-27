import 'dart:convert';
import 'dart:io';

import 'package:client_application/client_application.dart';
import 'package:client_domain/client_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:local_backup/local_backup.dart';
import 'package:test/test.dart';

void main() {
  late Directory staging;
  late List<int> contentBytes;
  late String contentHash;
  late ClientBackupSnapshot snapshot;

  Future<List<int>> collect(Stream<List<int>> stream) =>
      stream.expand((List<int> chunk) => chunk).toList();

  setUp(() async {
    staging = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}local_backup_test',
    );
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    contentBytes = utf8.encode('portable attachment bytes');
    contentHash = sha256.convert(contentBytes).toString();
    final DateTime now = DateTime.utc(2026, 1, 1);
    snapshot = ClientBackupSnapshot(
      exportedAt: now,
      eventSequence: 0,
      workspaces: <Workspace>[
        Workspace(
          id: 'workspace',
          name: 'Portable',
          lifecycle: WorkspaceLifecycle.active,
          revision: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      documents: <Document>[
        Document(
          id: 'document',
          workspaceId: 'workspace',
          title: 'Offline',
          parentId: null,
          position: 0,
          blocks: const <Block>[],
          revision: 1,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      attachments: <Attachment>[
        Attachment(
          id: 'attachment',
          workspaceId: 'workspace',
          documentId: 'document',
          fileName: 'portable.txt',
          mediaType: 'text/plain',
          sha256: contentHash,
          size: contentBytes.length,
          revision: 1,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      operations: const <Operation>[],
      commandOutcomes: const <CommandOutcome>[],
    );
  });

  tearDown(() async {
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
  });

  test('streaming archive round-trips snapshot and verified content', () async {
    final BackupArchiveWriter writer = await BackupArchiveWriter.prepare(
      snapshot: snapshot,
      openContent: (String hash, int size) async => BackupContent(
        sha256: hash,
        size: size,
        bytes: Stream<List<int>>.fromIterable(<List<int>>[
          contentBytes.sublist(0, 5),
          contentBytes.sublist(5),
        ]),
      ),
    );

    final List<int> archiveBytes = await collect(writer.openRead());
    expect(archiveBytes, hasLength(writer.contentLength));
    final BackupArchiveReader reader = await BackupArchiveReader.stage(
      bytes: Stream<List<int>>.value(archiveBytes),
      stagingDirectory: staging.path,
    );

    expect(reader.snapshot.toJson(), snapshot.toJson());
    expect(reader.contentHashes, <String>[contentHash]);
    expect(await collect(reader.openContent(contentHash).bytes), contentBytes);
    await reader.dispose();
    expect(await staging.list().toList(), isEmpty);
  });

  test('reader rejects corrupted, truncated, and trailing content', () async {
    final BackupArchiveWriter writer = await BackupArchiveWriter.prepare(
      snapshot: snapshot,
      openContent: (String hash, int size) async => BackupContent(
        sha256: hash,
        size: size,
        bytes: Stream<List<int>>.value(contentBytes),
      ),
    );
    final List<int> archiveBytes = await collect(writer.openRead());
    final List<List<int>> invalidArchives = <List<int>>[
      <int>[...archiveBytes]..last ^= 0xff,
      archiveBytes.sublist(0, archiveBytes.length - 1),
      <int>[...archiveBytes, 0],
    ];

    for (final List<int> invalid in invalidArchives) {
      await expectLater(
        BackupArchiveReader.stage(
          bytes: Stream<List<int>>.value(invalid),
          stagingDirectory: staging.path,
        ),
        throwsA(isA<BackupArchiveException>()),
      );
      expect(await staging.list().toList(), isEmpty);
    }
  });

  test('writer detects content mutation while streaming', () async {
    final BackupArchiveWriter writer = await BackupArchiveWriter.prepare(
      snapshot: snapshot,
      openContent: (String hash, int size) async => BackupContent(
        sha256: hash,
        size: size,
        bytes: Stream<List<int>>.value(<int>[...contentBytes]..last ^= 0xff),
      ),
    );

    await expectLater(
      collect(writer.openRead()),
      throwsA(
        isA<BackupArchiveException>().having(
          (BackupArchiveException error) => error.code,
          'code',
          'BackupAttachmentMismatch',
        ),
      ),
    );
  });

  test('writer enforces the total archive limit before responding', () async {
    await expectLater(
      BackupArchiveWriter.prepare(
        snapshot: snapshot,
        maximumArchiveBytes: 1,
        openContent: (String hash, int size) async => BackupContent(
          sha256: hash,
          size: size,
          bytes: Stream<List<int>>.value(contentBytes),
        ),
      ),
      throwsA(
        isA<BackupArchiveException>().having(
          (BackupArchiveException error) => error.code,
          'code',
          'BackupArchiveTooLarge',
        ),
      ),
    );
  });

  test('reader enforces archive size before parsing', () async {
    await expectLater(
      BackupArchiveReader.stage(
        bytes: Stream<List<int>>.value(<int>[1, 2, 3, 4]),
        stagingDirectory: staging.path,
        maximumArchiveBytes: 3,
      ),
      throwsA(
        isA<BackupArchiveException>().having(
          (BackupArchiveException error) => error.code,
          'code',
          'BackupArchiveTooLarge',
        ),
      ),
    );
    expect(await staging.list().toList(), isEmpty);
  });
}
