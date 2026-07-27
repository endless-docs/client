import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:client_application/client_application.dart';
import 'package:crypto/crypto.dart';

const int backupArchiveFormatVersion = 1;
const int defaultMaximumBackupManifestBytes = 64 * 1024 * 1024;
const int defaultMaximumBackupArchiveBytes = 20 * 1024 * 1024 * 1024;

final Uint8List _archiveMagic = Uint8List.fromList(
  utf8.encode('ENDLESS-BACKUP\r\n'),
);

final class BackupArchiveException implements Exception {
  const BackupArchiveException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'BackupArchiveException($code): $message';
}

final class BackupContent {
  const BackupContent({
    required this.sha256,
    required this.size,
    required this.bytes,
  });

  final String sha256;
  final int size;
  final Stream<List<int>> bytes;
}

typedef BackupContentOpener =
    Future<BackupContent> Function(String sha256, int size);

final class BackupArchiveWriter {
  BackupArchiveWriter._({
    required Uint8List manifest,
    required List<BackupContent> contents,
  }) : _manifest = manifest,
       _contents = contents;

  final Uint8List _manifest;
  final List<BackupContent> _contents;
  bool _opened = false;

  static Future<BackupArchiveWriter> prepare({
    required ClientBackupSnapshot snapshot,
    required BackupContentOpener openContent,
    int maximumManifestBytes = defaultMaximumBackupManifestBytes,
    int maximumArchiveBytes = defaultMaximumBackupArchiveBytes,
  }) async {
    if (maximumManifestBytes < 1 || maximumArchiveBytes < 1) {
      throw const BackupArchiveException(
        'BackupInvalidLimit',
        'Backup size limits must be positive.',
      );
    }
    final Map<String, int> requiredContents = _requiredContents(snapshot);
    final List<String> hashes = requiredContents.keys.toList()..sort();
    final List<BackupContent> contents = <BackupContent>[];
    for (final String hash in hashes) {
      final int expectedSize = requiredContents[hash]!;
      final BackupContent content = await openContent(hash, expectedSize);
      if (content.sha256 != hash || content.size != expectedSize) {
        throw const BackupArchiveException(
          'BackupAttachmentMismatch',
          'Attachment content does not match its backup metadata.',
        );
      }
      contents.add(content);
    }
    final Uint8List manifest = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'container_version': backupArchiveFormatVersion,
          'snapshot': snapshot.toJson(),
          'contents': hashes
              .map(
                (String hash) => <String, Object?>{
                  'sha256': hash,
                  'size': requiredContents[hash],
                },
              )
              .toList(growable: false),
        }),
      ),
    );
    if (manifest.length > maximumManifestBytes) {
      throw const BackupArchiveException(
        'BackupManifestTooLarge',
        'Backup manifest exceeds the supported size limit.',
      );
    }
    final BackupArchiveWriter writer = BackupArchiveWriter._(
      manifest: manifest,
      contents: contents,
    );
    if (writer.contentLength > maximumArchiveBytes) {
      throw const BackupArchiveException(
        'BackupArchiveTooLarge',
        'Backup archive exceeds the supported size limit.',
      );
    }
    return writer;
  }

  int get contentLength =>
      _archiveMagic.length +
      8 +
      _manifest.length +
      _contents.fold<int>(0, (int total, BackupContent value) {
        return total + value.size;
      });

  Stream<List<int>> openRead() async* {
    if (_opened) {
      throw const BackupArchiveException(
        'BackupAlreadyRead',
        'A prepared backup stream can only be opened once.',
      );
    }
    _opened = true;
    yield _archiveMagic;
    final ByteData length = ByteData(8)
      ..setUint64(0, _manifest.length, Endian.big);
    yield length.buffer.asUint8List();
    yield _manifest;
    for (final BackupContent content in _contents) {
      int emitted = 0;
      String? digest;
      bool hashSinkClosed = false;
      final ByteConversionSink hashSink = sha256.startChunkedConversion(
        _DigestSink((Digest value) => digest = value.toString()),
      );
      try {
        await for (final List<int> chunk in content.bytes) {
          emitted += chunk.length;
          if (emitted > content.size) {
            throw const BackupArchiveException(
              'BackupAttachmentMismatch',
              'Attachment content grew while the backup was streamed.',
            );
          }
          hashSink.add(chunk);
          yield chunk;
        }
        hashSink.close();
        hashSinkClosed = true;
        if (emitted != content.size || digest != content.sha256) {
          throw const BackupArchiveException(
            'BackupAttachmentMismatch',
            'Attachment content changed while the backup was streamed.',
          );
        }
      } finally {
        if (!hashSinkClosed) {
          hashSink.close();
        }
      }
    }
  }
}

final class BackupArchiveReader {
  BackupArchiveReader._({
    required this.snapshot,
    required File archiveFile,
    required Map<String, _ContentRange> contentRanges,
  }) : _archiveFile = archiveFile,
       _contentRanges = contentRanges;

  final ClientBackupSnapshot snapshot;
  final File _archiveFile;
  final Map<String, _ContentRange> _contentRanges;
  bool _disposed = false;

  Iterable<String> get contentHashes => _contentRanges.keys;

  static Future<BackupArchiveReader> stage({
    required Stream<List<int>> bytes,
    required String stagingDirectory,
    int maximumManifestBytes = defaultMaximumBackupManifestBytes,
    int maximumArchiveBytes = defaultMaximumBackupArchiveBytes,
  }) async {
    if (maximumManifestBytes < 1 || maximumArchiveBytes < 1) {
      throw const BackupArchiveException(
        'BackupInvalidLimit',
        'Backup size limits must be positive.',
      );
    }
    final Directory requestedDirectory = Directory(stagingDirectory).absolute;
    if (await FileSystemEntity.type(
          requestedDirectory.path,
          followLinks: false,
        ) ==
        FileSystemEntityType.link) {
      throw const BackupArchiveException(
        'UnsafeBackupPath',
        'Backup staging directory must not be a symbolic link.',
      );
    }
    await requestedDirectory.create(recursive: true);
    final Directory directory = Directory(
      await requestedDirectory.resolveSymbolicLinks(),
    );
    final File archive = File(
      _join(directory.path, '${_randomToken()}.backup.upload'),
    );
    final RandomAccessFile output = await archive.open(mode: FileMode.write);
    bool outputClosed = false;
    int received = 0;
    try {
      await for (final List<int> chunk in bytes) {
        received += chunk.length;
        if (received > maximumArchiveBytes) {
          throw const BackupArchiveException(
            'BackupArchiveTooLarge',
            'Backup archive exceeds the supported size limit.',
          );
        }
        await output.writeFrom(chunk);
      }
      await output.flush();
      await output.close();
      outputClosed = true;
      return await _parse(archive, maximumManifestBytes: maximumManifestBytes);
    } on Object {
      if (!outputClosed) {
        await output.close();
      }
      if (await archive.exists()) {
        await archive.delete();
      }
      rethrow;
    }
  }

  BackupContent openContent(String hash) {
    if (_disposed) {
      throw StateError('Backup archive has been disposed.');
    }
    final _ContentRange? range = _contentRanges[hash];
    if (range == null) {
      throw const BackupArchiveException(
        'BackupAttachmentMissing',
        'Backup attachment content is missing.',
      );
    }
    return BackupContent(
      sha256: hash,
      size: range.size,
      bytes: _archiveFile.openRead(range.start, range.start + range.size),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (await _archiveFile.exists()) {
      await _archiveFile.delete();
    }
  }

  static Future<BackupArchiveReader> _parse(
    File archive, {
    required int maximumManifestBytes,
  }) async {
    final int fileLength = await archive.length();
    final int headerLength = _archiveMagic.length + 8;
    if (fileLength < headerLength) {
      throw const BackupArchiveException(
        'BackupTruncated',
        'Backup archive header is truncated.',
      );
    }
    final RandomAccessFile input = await archive.open();
    try {
      final Uint8List header = await input.read(headerLength);
      for (int index = 0; index < _archiveMagic.length; index += 1) {
        if (header[index] != _archiveMagic[index]) {
          throw const BackupArchiveException(
            'BackupFormatInvalid',
            'Backup archive signature is invalid.',
          );
        }
      }
      final int manifestLength = ByteData.sublistView(
        header,
        _archiveMagic.length,
      ).getUint64(0, Endian.big);
      if (manifestLength < 1 || manifestLength > maximumManifestBytes) {
        throw const BackupArchiveException(
          'BackupManifestTooLarge',
          'Backup manifest size is invalid or unsupported.',
        );
      }
      if (headerLength + manifestLength > fileLength) {
        throw const BackupArchiveException(
          'BackupTruncated',
          'Backup manifest is truncated.',
        );
      }
      final Uint8List manifestBytes = await input.read(manifestLength);
      final Object? decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map<String, Object?>) {
        throw const BackupArchiveException(
          'BackupFormatInvalid',
          'Backup manifest must be an object.',
        );
      }
      if (_requiredInt(decoded, 'container_version') !=
          backupArchiveFormatVersion) {
        throw const BackupArchiveException(
          'BackupVersionUnsupported',
          'Backup archive version is unsupported.',
        );
      }
      final Object? snapshotJson = decoded['snapshot'];
      final Object? contentsJson = decoded['contents'];
      if (snapshotJson is! Map<String, Object?> ||
          contentsJson is! List<Object?>) {
        throw const BackupArchiveException(
          'BackupFormatInvalid',
          'Backup manifest has an invalid shape.',
        );
      }
      final ClientBackupSnapshot snapshot = ClientBackupSnapshot.fromJson(
        snapshotJson,
      );
      final Map<String, int> required = _requiredContents(snapshot);
      final Map<String, _ContentRange> ranges = <String, _ContentRange>{};
      int offset = headerLength + manifestLength;
      for (final Object? item in contentsJson) {
        if (item is! Map<String, Object?>) {
          throw const BackupArchiveException(
            'BackupFormatInvalid',
            'Backup content descriptor is invalid.',
          );
        }
        final String hash = _requiredHash(item);
        final int size = _requiredInt(item, 'size');
        if (size < 0 ||
            required[hash] != size ||
            ranges.containsKey(hash) ||
            offset + size > fileLength) {
          throw const BackupArchiveException(
            'BackupAttachmentMismatch',
            'Backup content descriptors do not match attachment metadata.',
          );
        }
        ranges[hash] = _ContentRange(offset, size);
        offset += size;
      }
      if (ranges.length != required.length ||
          !ranges.keys.every(required.containsKey) ||
          offset != fileLength) {
        throw const BackupArchiveException(
          'BackupAttachmentMismatch',
          'Backup attachment content is missing or has trailing bytes.',
        );
      }
      for (final MapEntry<String, _ContentRange> entry in ranges.entries) {
        final _ContentRange range = entry.value;
        final Digest digest = await sha256
            .bind(archive.openRead(range.start, range.start + range.size))
            .first;
        if (digest.toString() != entry.key) {
          throw const BackupArchiveException(
            'BackupAttachmentMismatch',
            'Backup attachment failed its integrity check.',
          );
        }
      }
      return BackupArchiveReader._(
        snapshot: snapshot,
        archiveFile: archive,
        contentRanges: Map<String, _ContentRange>.unmodifiable(ranges),
      );
    } on BackupSnapshotException catch (error) {
      throw BackupArchiveException(error.code, error.message);
    } on BackupArchiveException {
      rethrow;
    } on FormatException {
      throw const BackupArchiveException(
        'BackupFormatInvalid',
        'Backup manifest is not valid UTF-8 JSON.',
      );
    } finally {
      await input.close();
    }
  }
}

Map<String, int> _requiredContents(ClientBackupSnapshot snapshot) {
  final Map<String, int> result = <String, int>{};
  for (final attachment in snapshot.attachments) {
    final int? existing = result[attachment.sha256];
    if (existing != null && existing != attachment.size) {
      throw const BackupArchiveException(
        'BackupAttachmentMismatch',
        'One attachment hash is associated with conflicting sizes.',
      );
    }
    result[attachment.sha256] = attachment.size;
  }
  return result;
}

String _requiredHash(Map<String, Object?> json) {
  final Object? value = json['sha256'];
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const BackupArchiveException(
      'BackupFormatInvalid',
      'Backup content hash is invalid.',
    );
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw const BackupArchiveException(
      'BackupFormatInvalid',
      'Backup manifest integer is invalid.',
    );
  }
  return value;
}

String _randomToken() {
  final Random random = Random.secure();
  return List<int>.generate(
    24,
    (_) => random.nextInt(256),
  ).map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _join(String left, String right) =>
    '${left.replaceAll(RegExp(r'[\\/]+$'), '')}${Platform.pathSeparator}$right';

final class _ContentRange {
  const _ContentRange(this.start, this.size);

  final int start;
  final int size;
}

final class _DigestSink implements Sink<Digest> {
  const _DigestSink(this._onDigest);

  final void Function(Digest value) _onDigest;

  @override
  void add(Digest data) {
    _onDigest(data);
  }

  @override
  void close() {}
}
