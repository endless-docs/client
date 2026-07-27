import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_attachments/local_attachments.dart';
import 'package:test/test.dart';

void main() {
  late Directory profile;
  late Directory attachments;
  late Directory staging;
  late LocalAttachmentStore store;

  Stream<List<int>> chunked(List<int> bytes, int size) async* {
    for (int offset = 0; offset < bytes.length; offset += size) {
      yield bytes.sublist(offset, min(offset + size, bytes.length));
    }
  }

  Future<List<int>> collect(Stream<List<int>> bytes) =>
      bytes.expand((List<int> chunk) => chunk).toList();

  File part(String token) =>
      File('${staging.path}${Platform.pathSeparator}$token.part');

  File stagedJournal(String token) =>
      File('${staging.path}${Platform.pathSeparator}$token.staged.json');

  File commitJournal(String token) =>
      File('${staging.path}${Platform.pathSeparator}$token.commit.json');

  File committedJournal(String token) =>
      File('${staging.path}${Platform.pathSeparator}$token.committed.json');

  String contentPath(String hash) =>
      '${attachments.path}${Platform.pathSeparator}${hash.substring(0, 2)}'
      '${Platform.pathSeparator}$hash';

  setUp(() async {
    final Directory testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}local_attachments_test',
    );
    await testRoot.create(recursive: true);
    profile = await Directory(
      '${testRoot.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
    ).create();
    attachments = Directory(
      '${profile.path}${Platform.pathSeparator}attachments',
    );
    staging = Directory('${profile.path}${Platform.pathSeparator}staging');
    store = await LocalAttachmentStore.open(
      attachmentsRoot: attachments.path,
      stagingRoot: staging.path,
    );
  });

  tearDown(() async {
    if (await profile.exists()) {
      await profile.delete(recursive: true);
    }
  });

  test('stages, commits, opens, and idempotently replays by token', () async {
    final List<int> bytes = utf8.encode('offline attachment');
    final String expectedHash = sha256.convert(bytes).toString();

    final StagedAttachment staged = await store.stage(
      bytes: chunked(bytes, 3),
      fileName: 'notes.txt',
      mediaType: 'Text/Plain',
    );

    expect(staged.sha256, expectedHash);
    expect(staged.size, bytes.length);
    expect(staged.mediaType, 'text/plain');
    expect(staged.token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(await part(staged.token).exists(), isTrue);
    expect(await stagedJournal(staged.token).exists(), isTrue);

    final StagedAttachment committed = await store.commit(staged.token);
    final StagedAttachment replayed = await store.commit(staged.token);
    final AttachmentContent content = await store.openContent(expectedHash);

    expect(committed.toJson(), staged.toJson());
    expect(replayed.toJson(), staged.toJson());
    expect(content.size, bytes.length);
    expect(await collect(content.bytes), bytes);
    expect(await part(staged.token).exists(), isFalse);
    expect(await stagedJournal(staged.token).exists(), isFalse);
    expect(await committedJournal(staged.token).exists(), isTrue);
    expect(
      await File(contentPath(expectedHash)).exists(),
      isTrue,
      reason: 'The caller-provided file name is never part of the final path.',
    );
  });

  test(
    'deduplicates equal content across independent staging tokens',
    () async {
      final List<int> bytes = utf8.encode('same bytes');
      final StagedAttachment first = await store.stage(
        bytes: Stream<List<int>>.value(bytes),
        fileName: 'first.bin',
        mediaType: 'application/octet-stream',
      );
      final StagedAttachment second = await store.stage(
        bytes: Stream<List<int>>.value(bytes),
        fileName: 'second.bin',
        mediaType: 'application/octet-stream',
      );

      await store.commit(first.token);
      await store.commit(second.token);

      final List<File> contentFiles = await attachments
          .list(recursive: true, followLinks: false)
          .where((FileSystemEntity entity) => entity is File)
          .cast<File>()
          .toList();
      expect(first.token, isNot(second.token));
      expect(first.sha256, second.sha256);
      expect(contentFiles, hasLength(1));
      expect(await part(second.token).exists(), isFalse);
    },
  );

  test('enforces the stream byte limit and removes partial state', () async {
    store = await LocalAttachmentStore.open(
      attachmentsRoot: attachments.path,
      stagingRoot: staging.path,
      maximumBytes: 4,
    );

    await expectLater(
      store.stage(
        bytes: chunked(<int>[1, 2, 3, 4, 5], 2),
        fileName: 'large.bin',
        mediaType: 'application/octet-stream',
      ),
      throwsA(_storeError('AttachmentTooLarge')),
    );

    expect(await staging.list(followLinks: false).toList(), isEmpty);
    expect(await attachments.list(followLinks: false).toList(), isEmpty);
  });

  test(
    'rejects traversal names, invalid tokens, media types, and hashes',
    () async {
      for (final String fileName in <String>[
        '',
        '.',
        '..',
        '../escape',
        r'..\escape',
        '/absolute',
        r'C:\absolute',
        'nested/name',
        'null\u0000byte',
      ]) {
        await expectLater(
          store.stage(
            bytes: const Stream<List<int>>.empty(),
            fileName: fileName,
            mediaType: 'text/plain',
          ),
          throwsA(_storeError('InvalidArgument')),
          reason: fileName,
        );
      }
      await expectLater(
        store.stage(
          bytes: const Stream<List<int>>.empty(),
          fileName: 'safe.txt',
          mediaType: 'text/plain\r\ninjected: value',
        ),
        throwsA(_storeError('InvalidArgument')),
      );
      await expectLater(
        store.describe('../../outside'),
        throwsA(_storeError('InvalidArgument')),
      );
      await expectLater(
        store.openContent('../not-a-hash'),
        throwsA(_storeError('InvalidArgument')),
      );
      expect(await staging.list(followLinks: false).toList(), isEmpty);
    },
  );

  test('detects staged-byte tampering and preserves recovery marker', () async {
    final StagedAttachment staged = await store.stage(
      bytes: Stream<List<int>>.value(<int>[1, 2, 3]),
      fileName: 'value.bin',
      mediaType: 'application/octet-stream',
    );
    await part(staged.token).writeAsBytes(<int>[3, 2, 1], flush: true);

    await expectLater(
      store.commit(staged.token),
      throwsA(_storeError('AttachmentIntegrityFailure')),
    );

    expect(await commitJournal(staged.token).exists(), isTrue);
    final AttachmentRecoveryReport report = await store.recoverPendingCommits();
    expect(report.completedCommits, 0);
    expect(report.warnings, hasLength(1));
  });

  test('recovers a crash after commit intent became durable', () async {
    final List<int> bytes = utf8.encode('recover me');
    final StagedAttachment staged = await store.stage(
      bytes: Stream<List<int>>.value(bytes),
      fileName: 'recovery.txt',
      mediaType: 'text/plain',
    );
    await stagedJournal(staged.token).copy(commitJournal(staged.token).path);

    final LocalAttachmentStore reopened = await LocalAttachmentStore.open(
      attachmentsRoot: attachments.path,
      stagingRoot: staging.path,
    );
    final AttachmentRecoveryReport report = await reopened
        .recoverPendingCommits();
    final AttachmentContent content = await reopened.openContent(staged.sha256);

    expect(report.completedCommits, 1);
    expect(report.warnings, isEmpty);
    expect(await collect(content.bytes), bytes);
    expect(await part(staged.token).exists(), isFalse);
    expect(await commitJournal(staged.token).exists(), isFalse);
    expect(await stagedJournal(staged.token).exists(), isFalse);
    expect(await committedJournal(staged.token).exists(), isTrue);
  });

  test('isolates malformed commit journals during startup recovery', () async {
    final File malformed = File(
      '${staging.path}${Platform.pathSeparator}short.commit.json',
    );
    await malformed.writeAsString('{}', flush: true);

    final AttachmentRecoveryReport report = await store.recoverPendingCommits();

    expect(report.completedCommits, 0);
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('short.commit.json'));
  });

  test('cleanup removes abandoned staging but not pending commits', () async {
    final StagedAttachment abandoned = await store.stage(
      bytes: Stream<List<int>>.value(<int>[1]),
      fileName: 'abandoned.bin',
      mediaType: 'application/octet-stream',
    );
    final StagedAttachment pending = await store.stage(
      bytes: Stream<List<int>>.value(<int>[2]),
      fileName: 'pending.bin',
      mediaType: 'application/octet-stream',
    );
    await stagedJournal(pending.token).copy(commitJournal(pending.token).path);
    final DateTime old = DateTime.now().subtract(const Duration(days: 2));
    for (final File file in <File>[
      part(abandoned.token),
      stagedJournal(abandoned.token),
      part(pending.token),
      stagedJournal(pending.token),
      commitJournal(pending.token),
    ]) {
      await file.setLastModified(old);
    }

    final int removed = await store.cleanupAbandoned(
      olderThan: const Duration(days: 1),
    );

    expect(removed, 1);
    expect(await part(abandoned.token).exists(), isFalse);
    expect(await stagedJournal(abandoned.token).exists(), isFalse);
    expect(await part(pending.token).exists(), isTrue);
    expect(await stagedJournal(pending.token).exists(), isTrue);
    expect(await commitJournal(pending.token).exists(), isTrue);
  });

  test(
    'detects corruption of committed content before returning bytes',
    () async {
      final StagedAttachment staged = await store.stage(
        bytes: Stream<List<int>>.value(<int>[1, 2, 3]),
        fileName: 'value.bin',
        mediaType: 'application/octet-stream',
      );
      await store.commit(staged.token);
      await File(
        contentPath(staged.sha256),
      ).writeAsBytes(<int>[4, 5, 6], flush: true);

      await expectLater(
        store.openContent(staged.sha256),
        throwsA(_storeError('AttachmentIntegrityFailure')),
      );
      await expectLater(
        store.commit(staged.token),
        throwsA(_storeError('AttachmentIntegrityFailure')),
      );
    },
  );

  test(
    'rejects a symlinked content prefix without writing outside root',
    () async {
      final StagedAttachment staged = await store.stage(
        bytes: Stream<List<int>>.value(<int>[7, 8, 9]),
        fileName: 'linked.bin',
        mediaType: 'application/octet-stream',
      );
      final Directory outside = await Directory(
        '${profile.path}${Platform.pathSeparator}outside',
      ).create();
      final Link prefix = Link(
        '${attachments.path}${Platform.pathSeparator}'
        '${staged.sha256.substring(0, 2)}',
      );
      try {
        await prefix.create(outside.path);
      } on FileSystemException {
        markTestSkipped(
          'This host does not permit creating filesystem links; traversal '
          'coverage still runs.',
        );
        return;
      }

      await expectLater(
        store.commit(staged.token),
        throwsA(_storeError('UnsafeAttachmentPath')),
      );

      expect(await outside.list(followLinks: false).toList(), isEmpty);
      expect(await part(staged.token).exists(), isTrue);
    },
  );

  test('rejects overlapping managed roots', () async {
    final Directory managed = Directory(
      '${profile.path}${Platform.pathSeparator}managed',
    );

    await expectLater(
      LocalAttachmentStore.open(
        attachmentsRoot: managed.path,
        stagingRoot: '${managed.path}${Platform.pathSeparator}staging',
      ),
      throwsA(_storeError('UnsafeAttachmentPath')),
    );
    await expectLater(
      LocalAttachmentStore.open(
        attachmentsRoot: managed.path,
        stagingRoot: managed.path,
      ),
      throwsA(_storeError('UnsafeAttachmentPath')),
    );
  });
}

Matcher _storeError(String code) => isA<AttachmentStoreException>().having(
  (AttachmentStoreException error) => error.code,
  'code',
  code,
);
