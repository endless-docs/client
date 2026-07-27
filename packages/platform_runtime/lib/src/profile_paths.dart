import 'dart:convert';
import 'dart:io';

import 'package:local_api/local_api.dart';

final class ProfilePaths {
  ProfilePaths._({required this.profileId, required this.root});

  final String profileId;
  final Directory root;

  Directory get database => Directory(_join(root.path, 'database'));
  Directory get attachments => Directory(_join(root.path, 'attachments'));
  Directory get staging => Directory(_join(root.path, 'staging'));
  Directory get attachmentStaging =>
      Directory(_join(staging.path, 'attachments'));
  Directory get backupStaging => Directory(_join(staging.path, 'backups'));
  Directory get backups => Directory(_join(root.path, 'backups'));
  Directory get logs => Directory(_join(root.path, 'logs'));
  Directory get runtime => Directory(_join(root.path, 'runtime'));
  File get endpointFile => File(_join(runtime.path, 'endpoint.json'));
  File get processLockFile => File(_join(runtime.path, 'locald.lock'));

  static ProfilePaths resolve({
    String profileId = 'default',
    String? rootOverride,
  }) {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$').hasMatch(profileId)) {
      throw const FormatException('Invalid profile id.');
    }
    final String rootPath;
    final String? configuredRoot =
        rootOverride ?? Platform.environment['ENDLESS_PROFILE_ROOT'];
    if (configuredRoot != null) {
      rootPath = Directory(configuredRoot).absolute.path;
    } else {
      final String applicationRoot;
      if (Platform.isWindows) {
        applicationRoot =
            Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['APPDATA'] ??
            Directory.current.path;
      } else if (Platform.isMacOS) {
        applicationRoot = _join(
          Platform.environment['HOME'] ?? Directory.current.path,
          'Library/Application Support',
        );
      } else {
        applicationRoot =
            Platform.environment['XDG_DATA_HOME'] ??
            _join(
              Platform.environment['HOME'] ?? Directory.current.path,
              '.local/share',
            );
      }
      rootPath = _join(
        _join(_join(applicationRoot, 'EndlessDocs'), 'profiles'),
        profileId,
      );
    }
    return ProfilePaths._(
      profileId: profileId,
      root: Directory(rootPath).absolute,
    );
  }

  Future<void> ensureCreated() async {
    for (final Directory directory in <Directory>[
      root,
      database,
      attachments,
      staging,
      attachmentStaging,
      backupStaging,
      backups,
      logs,
      runtime,
    ]) {
      await directory.create(recursive: true);
    }
    final File manifest = File(_join(root.path, 'profile.manifest'));
    if (!await manifest.exists()) {
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'profile_id': profileId,
          'format_version': 1,
        }),
        flush: true,
      );
    }
  }

  Future<EndpointManifest?> readEndpoint() async {
    try {
      final Object? decoded = jsonDecode(await endpointFile.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final EndpointManifest endpoint = EndpointManifest.fromJson(decoded);
      return endpoint.profileId == profileId ? endpoint : null;
    } on Object {
      return null;
    }
  }

  Future<void> writeEndpoint(EndpointManifest endpoint) async {
    if (endpoint.profileId != profileId) {
      throw const FormatException('Endpoint belongs to another profile.');
    }
    await runtime.create(recursive: true);
    await endpointFile.writeAsString(
      jsonEncode(endpoint.toJson()),
      flush: true,
    );
  }

  static String _join(String left, String right) =>
      '${left.replaceAll(RegExp(r'[\\/]+$'), '')}${Platform.pathSeparator}$right';
}
