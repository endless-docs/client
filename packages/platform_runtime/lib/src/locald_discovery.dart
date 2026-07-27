import 'dart:io';

import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';

import 'profile_paths.dart';

final class LocaldDiscovery {
  const LocaldDiscovery({this.startupTimeout = const Duration(seconds: 20)});

  final Duration startupTimeout;

  Future<EndpointManifest> ensureLocald({
    String profileId = 'default',
    String? profileRoot,
  }) async {
    final ProfilePaths paths = ProfilePaths.resolve(
      profileId: profileId,
      rootOverride: profileRoot,
    );
    await paths.ensureCreated();

    final EndpointManifest? running = await _healthyEndpoint(paths);
    if (running != null) {
      return running;
    }

    await _startLocald(paths);
    final Stopwatch stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < startupTimeout) {
      final EndpointManifest? endpoint = await _healthyEndpoint(paths);
      if (endpoint != null) {
        return endpoint;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw const LocalApiException(
      code: 'LocaldStarting',
      message: 'Local storage did not become ready.',
      retryable: true,
    );
  }

  Future<EndpointManifest?> _healthyEndpoint(ProfilePaths paths) async {
    final EndpointManifest? endpoint = await paths.readEndpoint();
    if (endpoint == null || endpoint.apiVersion != localApiVersion) {
      return null;
    }
    final HttpLocalApiClient client = HttpLocalApiClient(
      endpoint: endpoint,
      timeout: const Duration(milliseconds: 500),
    );
    try {
      await client.health();
      return endpoint;
    } on Object {
      return null;
    } finally {
      await client.close();
    }
  }

  Future<void> _startLocald(ProfilePaths paths) async {
    final String? configuredExecutable =
        Platform.environment['ENDLESS_LOCALD_EXECUTABLE'];
    final File bundled = File(
      '${File(Platform.resolvedExecutable).parent.path}'
      '${Platform.pathSeparator}locald${Platform.isWindows ? '.exe' : ''}',
    );

    late final String executable;
    late final List<String> arguments;
    late final String? workingDirectory;
    late final bool runInShell;
    if (configuredExecutable != null && configuredExecutable.isNotEmpty) {
      executable = File(configuredExecutable).absolute.path;
      arguments = <String>[
        '--profile',
        paths.profileId,
        '--profile-root',
        paths.root.path,
      ];
      workingDirectory = null;
      runInShell = false;
    } else if (await bundled.exists()) {
      executable = bundled.path;
      arguments = <String>[
        '--profile',
        paths.profileId,
        '--profile-root',
        paths.root.path,
      ];
      workingDirectory = null;
      runInShell = false;
    } else {
      final Directory? workspace = _findDevelopmentWorkspace();
      if (workspace == null) {
        throw const LocalApiException(
          code: 'LocaldUnavailable',
          message: 'Bundled locald executable was not found.',
          retryable: false,
        );
      }
      executable = 'dart';
      arguments = <String>[
        'run',
        'apps/locald/bin/locald.dart',
        '--profile',
        paths.profileId,
        '--profile-root',
        paths.root.path,
        '--allow-development-isar-download',
      ];
      workingDirectory = workspace.path;
      runInShell = Platform.isWindows;
    }

    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
      runInShell: runInShell,
    );
  }

  static Directory? _findDevelopmentWorkspace() {
    Directory current = Directory.current.absolute;
    for (int depth = 0; depth < 8; depth++) {
      if (File(
        '${current.path}${Platform.pathSeparator}'
        'apps${Platform.pathSeparator}locald${Platform.pathSeparator}'
        'pubspec.yaml',
      ).existsSync()) {
        return current;
      }
      final Directory parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }
    return null;
  }
}
