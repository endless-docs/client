import 'dart:io';

import 'package:local_api/local_api.dart';
import 'package:platform_runtime/platform_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('rejects profile path traversal', () {
    expect(
      () => ProfilePaths.resolve(profileId: '../outside'),
      throwsFormatException,
    );
  });

  test('persists endpoint only for the selected profile', () async {
    final Directory temporary = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
      'paths-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.create(recursive: true);
    addTearDown(() => temporary.delete(recursive: true));
    final ProfilePaths paths = ProfilePaths.resolve(
      rootOverride: temporary.path,
    );
    await paths.ensureCreated();
    const EndpointManifest endpoint = EndpointManifest(
      port: 1234,
      sessionProof: 'token',
      profileId: 'default',
      processId: 1,
      apiVersion: localApiVersion,
    );

    await paths.writeEndpoint(endpoint);

    expect((await paths.readEndpoint())?.sessionProof, 'token');
  });

  test('allows only one process lock owner', () async {
    final Directory temporary = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}test_profiles${Platform.pathSeparator}'
      'lock-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.create(recursive: true);
    addTearDown(() => temporary.delete(recursive: true));
    final File lockFile = File(
      '${temporary.path}${Platform.pathSeparator}locald.lock',
    );
    final ProcessLock first = await ProcessLock.acquire(lockFile);
    addTearDown(first.release);

    await expectLater(
      ProcessLock.acquire(lockFile),
      throwsA(isA<FileSystemException>()),
    );
  });
}
