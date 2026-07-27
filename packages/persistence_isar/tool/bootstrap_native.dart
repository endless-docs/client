import 'dart:io';

import 'package:persistence_isar/persistence_isar.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/bootstrap_native.dart LIBRARY_PATH DATABASE_PATH',
    );
    exitCode = 64;
    return;
  }
  final File library = File(arguments[0]).absolute;
  final Directory database = Directory(arguments[1]).absolute;
  final IsarClientStore store = await IsarClientStore.open(
    directory: database.path,
    nativeLibraryPath: library.path,
    allowDevelopmentDownload: true,
    instanceName: 'native-bootstrap',
  );
  await store.close();
  stdout.writeln(library.path);
}
