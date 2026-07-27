import 'dart:async';
import 'dart:io';

import 'package:locald/locald.dart';

Future<void> main(List<String> arguments) async {
  final Map<String, String?> options = _parseOptions(arguments);
  final String profileId = options['profile'] ?? 'default';
  final String? profileRoot = options['profile-root'];
  final String? configuredLibrary =
      Platform.environment['ENDLESS_ISAR_LIBRARY'];
  final File bundledLibrary = File(
    '${File(Platform.resolvedExecutable).parent.path}'
    '${Platform.pathSeparator}${Platform.isWindows ? 'isar.dll' : 'libisar.so'}',
  );
  final String? nativeLibraryPath = configuredLibrary != null
      ? File(configuredLibrary).absolute.path
      : await bundledLibrary.exists()
      ? bundledLibrary.path
      : null;

  final LocaldServer server = await LocaldServer.start(
    profileId: profileId,
    profileRoot: profileRoot,
    nativeLibraryPath: nativeLibraryPath,
    allowDevelopmentIsarDownload: options.containsKey(
      'allow-development-isar-download',
    ),
  );

  final Completer<void> shutdown = Completer<void>();
  final List<StreamSubscription<ProcessSignal>> subscriptions =
      <StreamSubscription<ProcessSignal>>[];
  for (final ProcessSignal signal in <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    try {
      subscriptions.add(
        signal.watch().listen((ProcessSignal _) {
          if (!shutdown.isCompleted) {
            shutdown.complete();
          }
        }, onError: (Object _) {}),
      );
    } on Object {
      // The current platform does not expose this signal.
    }
  }

  await shutdown.future;
  for (final StreamSubscription<ProcessSignal> subscription in subscriptions) {
    await subscription.cancel();
  }
  await server.close();
}

Map<String, String?> _parseOptions(List<String> arguments) {
  final Map<String, String?> result = <String, String?>{};
  for (int index = 0; index < arguments.length; index++) {
    final String argument = arguments[index];
    if (!argument.startsWith('--')) {
      throw FormatException('Unexpected argument: $argument');
    }
    final String key = argument.substring(2);
    if (key == 'allow-development-isar-download') {
      result[key] = null;
      continue;
    }
    if (index + 1 >= arguments.length) {
      throw FormatException('Missing value for $argument');
    }
    result[key] = arguments[++index];
  }
  return result;
}
