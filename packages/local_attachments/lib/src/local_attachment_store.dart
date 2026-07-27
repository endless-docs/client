import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final class AttachmentStoreException implements Exception {
  const AttachmentStoreException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AttachmentStoreException($code): $message';
}

final class StagedAttachment {
  const StagedAttachment({
    required this.token,
    required this.fileName,
    required this.mediaType,
    required this.size,
    required this.sha256,
    required this.createdAt,
  });

  final String token;
  final String fileName;
  final String mediaType;
  final int size;
  final String sha256;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'file_name': fileName,
    'media_type': mediaType,
    'size': size,
    'sha256': sha256,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory StagedAttachment.fromJson(Map<String, Object?> json) {
    final Object? token = json['token'];
    final Object? fileName = json['file_name'];
    final Object? mediaType = json['media_type'];
    final Object? size = json['size'];
    final Object? hash = json['sha256'];
    final Object? createdAt = json['created_at'];
    if (token is! String ||
        fileName is! String ||
        mediaType is! String ||
        size is! int ||
        hash is! String ||
        createdAt is! String) {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal has an invalid shape.',
      );
    }
    _validateToken(token);
    _validateFileName(fileName);
    _validateMediaType(mediaType);
    _validateHash(hash);
    if (size < 0) {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal has an invalid size.',
      );
    }
    final DateTime? parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal has an invalid timestamp.',
      );
    }
    return StagedAttachment(
      token: token,
      fileName: fileName,
      mediaType: mediaType,
      size: size,
      sha256: hash,
      createdAt: parsedCreatedAt.toUtc(),
    );
  }
}

final class AttachmentContent {
  const AttachmentContent({
    required this.sha256,
    required this.size,
    required this.bytes,
  });

  final String sha256;
  final int size;
  final Stream<List<int>> bytes;
}

final class AttachmentRecoveryReport {
  const AttachmentRecoveryReport({
    required this.completedCommits,
    required this.removedAbandonedFiles,
    required this.warnings,
  });

  final int completedCommits;
  final int removedAbandonedFiles;
  final List<String> warnings;
}

final class LocalAttachmentStore {
  LocalAttachmentStore._({
    required Directory attachmentsRoot,
    required Directory stagingRoot,
    required this.maximumBytes,
  }) : _attachmentsRoot = attachmentsRoot,
       _stagingRoot = stagingRoot;

  final Directory _attachmentsRoot;
  final Directory _stagingRoot;
  final int maximumBytes;
  final Random _random = Random.secure();

  String get attachmentsRootPath => _attachmentsRoot.path;
  String get stagingRootPath => _stagingRoot.path;

  static Future<LocalAttachmentStore> open({
    required String attachmentsRoot,
    required String stagingRoot,
    int maximumBytes = 100 * 1024 * 1024,
  }) async {
    if (maximumBytes < 1) {
      throw const AttachmentStoreException(
        'InvalidArgument',
        'Attachment size limit must be positive.',
      );
    }
    final Directory attachments = Directory(attachmentsRoot).absolute;
    final Directory staging = Directory(stagingRoot).absolute;
    await attachments.create(recursive: true);
    await staging.create(recursive: true);
    final Directory canonicalAttachments = Directory(
      await attachments.resolveSymbolicLinks(),
    );
    final Directory canonicalStaging = Directory(
      await staging.resolveSymbolicLinks(),
    );
    if (_sameOrWithin(canonicalAttachments.path, canonicalStaging.path) ||
        _sameOrWithin(canonicalStaging.path, canonicalAttachments.path)) {
      throw const AttachmentStoreException(
        'UnsafeAttachmentPath',
        'Attachment and staging roots must not overlap.',
      );
    }
    return LocalAttachmentStore._(
      attachmentsRoot: canonicalAttachments,
      stagingRoot: canonicalStaging,
      maximumBytes: maximumBytes,
    );
  }

  Future<StagedAttachment> stage({
    required Stream<List<int>> bytes,
    required String fileName,
    required String mediaType,
  }) async {
    final String normalizedName = _validateFileName(fileName);
    final String normalizedMediaType = _validateMediaType(mediaType);
    final String token = _newToken();
    final File stagedFile = _stagingFile(token);
    final RandomAccessFile output = await stagedFile.open(mode: FileMode.write);
    String? digest;
    int size = 0;
    bool hashSinkClosed = false;
    bool outputClosed = false;
    final ByteConversionSink hashSink = sha256.startChunkedConversion(
      _DigestSink((Digest value) => digest = value.toString()),
    );
    try {
      await for (final List<int> chunk in bytes) {
        size += chunk.length;
        if (size > maximumBytes) {
          throw AttachmentStoreException(
            'AttachmentTooLarge',
            'Attachment exceeds the $maximumBytes byte limit.',
          );
        }
        hashSink.add(chunk);
        await output.writeFrom(chunk);
      }
      hashSink.close();
      hashSinkClosed = true;
      await output.flush();
      await output.close();
      outputClosed = true;
      final String? resolvedDigest = digest;
      if (resolvedDigest == null) {
        throw const AttachmentStoreException(
          'AttachmentIntegrityFailure',
          'Attachment hash could not be calculated.',
        );
      }
      final StagedAttachment staged = StagedAttachment(
        token: token,
        fileName: normalizedName,
        mediaType: normalizedMediaType,
        size: size,
        sha256: resolvedDigest,
        createdAt: DateTime.now().toUtc(),
      );
      await _writeJournal(_stagedJournal(token), staged);
      return staged;
    } on Object {
      if (!hashSinkClosed) {
        hashSink.close();
      }
      if (!outputClosed) {
        await output.close();
      }
      if (await stagedFile.exists()) {
        await stagedFile.delete();
      }
      rethrow;
    }
  }

  Future<StagedAttachment> describe(String token) async {
    _validateToken(token);
    final File? journal = await _existingJournal(token);
    if (journal == null) {
      throw const AttachmentStoreException(
        'AttachmentNotFound',
        'Attachment staging token was not found.',
      );
    }
    return _readJournal(journal, token);
  }

  Future<StagedAttachment> commit(String token) async {
    _validateToken(token);
    final File? existing = await _existingJournal(token);
    if (existing == null) {
      throw const AttachmentStoreException(
        'AttachmentNotFound',
        'Attachment staging token was not found.',
      );
    }
    final StagedAttachment staged = await _readJournal(existing, token);
    if (existing.path.endsWith('.committed.json')) {
      await _verifyFinal(staged);
      await _deleteIfExists(_stagingFile(token));
      await _deleteIfExists(_commitJournal(token));
      await _deleteIfExists(_stagedJournal(token));
      return staged;
    }
    await _writeJournal(_commitJournal(token), staged);
    await _commitDescriptor(staged);
    await _writeJournal(_committedJournal(token), staged);
    await _deleteIfExists(_commitJournal(token));
    await _deleteIfExists(_stagedJournal(token));
    return staged;
  }

  Future<AttachmentContent> openContent(String hash) async {
    _validateHash(hash);
    final File file = await _finalFile(hash, createPrefix: false);
    if (!await file.exists()) {
      throw const AttachmentStoreException(
        'AttachmentNotFound',
        'Attachment bytes were not found.',
      );
    }
    await _rejectLink(file.path);
    final int size = await file.length();
    final Digest digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != hash) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Attachment bytes do not match their content hash.',
      );
    }
    return AttachmentContent(sha256: hash, size: size, bytes: file.openRead());
  }

  Future<AttachmentRecoveryReport> recoverPendingCommits({
    Duration abandonAfter = const Duration(days: 1),
  }) async {
    int completed = 0;
    final List<String> warnings = <String>[];
    await for (final FileSystemEntity entity in _stagingRoot.list(
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.commit.json')) {
        continue;
      }
      try {
        final String token = _journalToken(entity.path, '.commit.json');
        final StagedAttachment staged = await _readJournal(entity, token);
        await _commitDescriptor(staged);
        await _writeJournal(_committedJournal(token), staged);
        await _deleteIfExists(_commitJournal(token));
        await _deleteIfExists(_stagedJournal(token));
        completed += 1;
      } on Object catch (error) {
        warnings.add('${_baseName(entity.path)}: $error');
      }
    }
    final int removed = await cleanupAbandoned(olderThan: abandonAfter);
    return AttachmentRecoveryReport(
      completedCommits: completed,
      removedAbandonedFiles: removed,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<void> releaseToken(String token) async {
    _validateToken(token);
    final File journal = _committedJournal(token);
    await _rejectLink(journal.path);
    if (!await journal.exists()) {
      return;
    }
    final StagedAttachment staged = await _readJournal(journal, token);
    await _verifyFinal(staged);
    await journal.delete();
  }

  Future<int> cleanupAbandoned({required Duration olderThan}) async {
    if (olderThan.isNegative) {
      throw const AttachmentStoreException(
        'InvalidArgument',
        'Cleanup age must not be negative.',
      );
    }
    final DateTime threshold = DateTime.now().toUtc().subtract(olderThan);
    int removed = 0;
    await for (final FileSystemEntity entity in _stagingRoot.list(
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String name = _baseName(entity.path);
      if (name.endsWith('.staged.json')) {
        final String? token = _tryJournalToken(entity.path, '.staged.json');
        if (token == null) {
          continue;
        }
        if (!await _commitJournal(token).exists() &&
            (await entity.stat()).modified.toUtc().isBefore(threshold)) {
          await _deleteIfExists(_stagingFile(token));
          await entity.delete();
          removed += 1;
        }
      } else if (name.endsWith('.committed.json')) {
        final String? token = _tryJournalToken(entity.path, '.committed.json');
        if (token != null &&
            (await entity.stat()).modified.toUtc().isBefore(threshold)) {
          final StagedAttachment staged = await _readJournal(entity, token);
          await _verifyFinal(staged);
          await entity.delete();
          removed += 1;
        }
      } else if (name.endsWith('.journal.tmp')) {
        final String? token = _tryJournalToken(entity.path, '.journal.tmp');
        if (token != null &&
            (await entity.stat()).modified.toUtc().isBefore(threshold)) {
          await entity.delete();
          removed += 1;
        }
      } else if (name.endsWith('.part')) {
        final String token = name.substring(0, name.length - '.part'.length);
        if (_tokenPattern.hasMatch(token) &&
            !await _stagedJournal(token).exists() &&
            !await _commitJournal(token).exists() &&
            (await entity.stat()).modified.toUtc().isBefore(threshold)) {
          await entity.delete();
          removed += 1;
        }
      }
    }
    return removed;
  }

  Future<void> _commitDescriptor(StagedAttachment staged) async {
    final File target = await _finalFile(staged.sha256, createPrefix: true);
    final File source = _stagingFile(staged.token);
    if (await target.exists()) {
      await _verifyFinal(staged);
      await _deleteIfExists(source);
      return;
    }
    if (!await source.exists()) {
      throw const AttachmentStoreException(
        'AttachmentRecoveryRequired',
        'Neither staged nor committed attachment bytes exist.',
      );
    }
    await _rejectLink(source.path);
    if (await source.length() != staged.size) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Staged attachment size changed before commit.',
      );
    }
    final Digest sourceHash = await sha256.bind(source.openRead()).first;
    if (sourceHash.toString() != staged.sha256) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Staged attachment hash changed before commit.',
      );
    }
    await source.rename(target.path);
    await _verifyFinal(staged);
  }

  Future<void> _verifyFinal(StagedAttachment staged) async {
    final File target = await _finalFile(staged.sha256, createPrefix: false);
    if (!await target.exists()) {
      throw const AttachmentStoreException(
        'AttachmentRecoveryRequired',
        'Committed attachment bytes are missing.',
      );
    }
    await _rejectLink(target.path);
    if (await target.length() != staged.size) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Committed attachment size does not match metadata.',
      );
    }
    final Digest digest = await sha256.bind(target.openRead()).first;
    if (digest.toString() != staged.sha256) {
      throw const AttachmentStoreException(
        'AttachmentIntegrityFailure',
        'Committed attachment hash does not match metadata.',
      );
    }
  }

  Future<File> _finalFile(String hash, {required bool createPrefix}) async {
    _validateHash(hash);
    final String prefixPath = _join(
      _attachmentsRoot.path,
      hash.substring(0, 2),
    );
    _ensureWithin(_attachmentsRoot.path, prefixPath);
    final FileSystemEntityType prefixType = await FileSystemEntity.type(
      prefixPath,
      followLinks: false,
    );
    if (prefixType == FileSystemEntityType.link) {
      throw const AttachmentStoreException(
        'UnsafeAttachmentPath',
        'Attachment hash directory must not be a symbolic link.',
      );
    }
    if (prefixType == FileSystemEntityType.notFound) {
      if (!createPrefix) {
        return File(_join(prefixPath, hash));
      }
      await Directory(prefixPath).create();
    } else if (prefixType != FileSystemEntityType.directory) {
      throw const AttachmentStoreException(
        'UnsafeAttachmentPath',
        'Attachment hash directory is not a directory.',
      );
    }
    final String canonicalPrefix = await Directory(
      prefixPath,
    ).resolveSymbolicLinks();
    _ensureWithin(_attachmentsRoot.path, canonicalPrefix);
    final String targetPath = _join(canonicalPrefix, hash);
    _ensureWithin(_attachmentsRoot.path, targetPath);
    return File(targetPath);
  }

  File _stagingFile(String token) {
    _validateToken(token);
    final String path = _join(_stagingRoot.path, '$token.part');
    _ensureWithin(_stagingRoot.path, path);
    return File(path);
  }

  File _stagedJournal(String token) => _journalFile(token, '.staged.json');

  File _commitJournal(String token) => _journalFile(token, '.commit.json');

  File _committedJournal(String token) =>
      _journalFile(token, '.committed.json');

  File _journalFile(String token, String suffix) {
    _validateToken(token);
    final String path = _join(_stagingRoot.path, '$token$suffix');
    _ensureWithin(_stagingRoot.path, path);
    return File(path);
  }

  Future<File?> _existingJournal(String token) async {
    for (final File candidate in <File>[
      _committedJournal(token),
      _commitJournal(token),
      _stagedJournal(token),
    ]) {
      await _rejectLink(candidate.path);
      if (await candidate.exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<StagedAttachment> _readJournal(File file, String token) async {
    await _rejectLink(file.path);
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal is not valid JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal must be a JSON object.',
      );
    }
    final StagedAttachment staged = StagedAttachment.fromJson(decoded);
    if (staged.token != token) {
      throw const AttachmentStoreException(
        'AttachmentJournalInvalid',
        'Attachment journal token does not match its file.',
      );
    }
    return staged;
  }

  Future<void> _writeJournal(File file, StagedAttachment staged) async {
    await _rejectLink(file.path);
    if (await file.exists()) {
      final StagedAttachment existing = await _readJournal(file, staged.token);
      if (jsonEncode(existing.toJson()) != jsonEncode(staged.toJson())) {
        throw const AttachmentStoreException(
          'AttachmentJournalConflict',
          'Attachment journal already contains different metadata.',
        );
      }
      return;
    }
    final File temporary = _journalTemp(staged.token);
    await _deleteIfExists(temporary);
    try {
      await temporary.writeAsString(jsonEncode(staged.toJson()), flush: true);
      await temporary.rename(file.path);
    } on Object {
      try {
        await _deleteIfExists(temporary);
      } on Object {
        // Preserve the original filesystem failure. Startup cleanup can remove
        // a leftover journal temporary after the configured abandon interval.
      }
      rethrow;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    await _rejectLink(file.path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _rejectLink(String path) async {
    final FileSystemEntityType type = await FileSystemEntity.type(
      path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw const AttachmentStoreException(
        'UnsafeAttachmentPath',
        'Managed attachment path must not be a symbolic link.',
      );
    }
  }

  String _newToken() {
    final Uint8List bytes = Uint8List(24);
    for (int index = 0; index < bytes.length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  File _journalTemp(String token) => _journalFile(token, '.journal.tmp');
}

final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,64}$');
final RegExp _hashPattern = RegExp(r'^[a-f0-9]{64}$');
final RegExp _mediaTypePattern = RegExp(
  r"^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$",
);

final class _DigestSink implements Sink<Digest> {
  const _DigestSink(this._onDigest);

  final void Function(Digest value) _onDigest;

  @override
  void add(Digest data) => _onDigest(data);

  @override
  void close() {}
}

String _validateToken(String value) {
  if (!_tokenPattern.hasMatch(value)) {
    throw const AttachmentStoreException(
      'InvalidArgument',
      'Attachment staging token is invalid.',
    );
  }
  return value;
}

String _validateHash(String value) {
  if (!_hashPattern.hasMatch(value)) {
    throw const AttachmentStoreException(
      'InvalidArgument',
      'Attachment content hash is invalid.',
    );
  }
  return value;
}

String _validateFileName(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty ||
      normalized == '.' ||
      normalized == '..' ||
      normalized.length > 255 ||
      normalized.contains('/') ||
      normalized.contains('\\') ||
      normalized.contains('\u0000')) {
    throw const AttachmentStoreException(
      'InvalidArgument',
      'Attachment file name is invalid.',
    );
  }
  return normalized;
}

String _validateMediaType(String value) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized.length > 200 ||
      !_mediaTypePattern.hasMatch(normalized)) {
    throw const AttachmentStoreException(
      'InvalidArgument',
      'Attachment media type is invalid.',
    );
  }
  return normalized;
}

String _journalToken(String path, String suffix) {
  final String name = _baseName(path);
  final String token = name.substring(0, name.length - suffix.length);
  return _validateToken(token);
}

String? _tryJournalToken(String path, String suffix) {
  try {
    return _journalToken(path, suffix);
  } on AttachmentStoreException {
    return null;
  }
}

String _baseName(String path) {
  final List<String> parts = path.split(RegExp(r'[\\/]'));
  return parts.last;
}

String _join(String left, String right) =>
    '${left.replaceAll(RegExp(r'[\\/]+$'), '')}${Platform.pathSeparator}$right';

void _ensureWithin(String root, String candidate) {
  if (!_sameOrWithin(root, candidate)) {
    throw const AttachmentStoreException(
      'UnsafeAttachmentPath',
      'Managed attachment path escaped its root.',
    );
  }
}

bool _sameOrWithin(String root, String candidate) {
  final String normalizedRoot = Directory(
    root,
  ).absolute.path.replaceAll(RegExp(r'[\\/]+$'), '');
  final String normalizedCandidate = File(candidate).absolute.path;
  final String prefix = '$normalizedRoot${Platform.pathSeparator}';
  if (Platform.isWindows) {
    return normalizedCandidate.toLowerCase() == normalizedRoot.toLowerCase() ||
        normalizedCandidate.toLowerCase().startsWith(prefix.toLowerCase());
  }
  return normalizedCandidate == normalizedRoot ||
      normalizedCandidate.startsWith(prefix);
}
