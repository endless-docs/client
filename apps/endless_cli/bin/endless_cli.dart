import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:local_api/local_api.dart';
import 'package:local_api_client/local_api_client.dart';
import 'package:platform_runtime/platform_runtime.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}

Future<int> runCli(List<String> arguments) async {
  final _CliArguments parsed;
  try {
    parsed = _CliArguments.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    return 2;
  }

  EndlessLocalApi? client;
  try {
    final EndpointManifest endpoint = await const LocaldDiscovery()
        .ensureLocald(
          profileId: parsed.profile,
          profileRoot: parsed.profileRoot,
        );
    client = HttpLocalApiClient(endpoint: endpoint);
    await client.handshake(
      clientType: LocalClientType.cli,
      profileId: parsed.profile,
    );
    final Object result = await _execute(client, parsed.command);
    stdout.writeln(
      parsed.json
          ? const JsonEncoder.withIndent('  ').convert(result)
          : _humanReadable(result),
    );
    return 0;
  } on LocalApiException catch (error) {
    if (parsed.json) {
      stderr.writeln(jsonEncode(<String, Object?>{'error': error.toJson()}));
    } else {
      stderr.writeln('${error.code}: ${error.message}');
    }
    return _exitCode(error.code);
  } on Object catch (error) {
    stderr.writeln('Internal: $error');
    return 70;
  } finally {
    await client?.close();
  }
}

Future<Object> _execute(EndlessLocalApi client, List<String> command) async {
  if (command.length == 1 && command[0] == 'health') {
    return client.health();
  }
  if (command.length == 2 &&
      command[0] == 'workspace' &&
      command[1] == 'list') {
    return client.listWorkspaces();
  }
  if (command.length >= 3 &&
      command[0] == 'workspace' &&
      command[1] == 'create') {
    return client.createWorkspace(
      commandId: _commandId(),
      name: command.sublist(2).join(' '),
    );
  }
  if (command.length == 3 && command[0] == 'document' && command[1] == 'list') {
    return client.listDocuments(workspaceId: command[2]);
  }
  if (command.length == 3 && command[0] == 'document' && command[1] == 'get') {
    return client.getDocument(command[2]);
  }
  if (command.length >= 4 &&
      command[0] == 'document' &&
      command[1] == 'create') {
    return client.createDocument(
      commandId: _commandId(),
      workspaceId: command[2],
      title: command.sublist(3).join(' '),
    );
  }
  if (command.length == 3 &&
      command[0] == 'document' &&
      command[1] == 'delete') {
    final JsonMap document = await client.getDocument(command[2]);
    return client.deleteDocument(
      commandId: _commandId(),
      documentId: command[2],
      expectedRevision: requireInt(document, 'revision'),
    );
  }
  if (command.length == 3 &&
      command[0] == 'document' &&
      command[1] == 'restore') {
    final JsonMap document = await client.getDocument(command[2]);
    return client.restoreDocument(
      commandId: _commandId(),
      documentId: command[2],
      expectedRevision: requireInt(document, 'revision'),
    );
  }
  if (command.length == 4 && command[0] == 'document' && command[1] == 'move') {
    final JsonMap document = await client.getDocument(command[2]);
    return client.moveDocument(
      commandId: _commandId(),
      documentId: command[2],
      parentId: command[3] == 'root' ? null : command[3],
      position: 0,
      expectedRevision: requireInt(document, 'revision'),
    );
  }
  if (command.length >= 3 && command[0] == 'search') {
    return client.searchDocuments(
      workspaceId: command[1],
      query: command.sublist(2).join(' '),
    );
  }
  if (command.length == 2 &&
      command[0] == 'search-index' &&
      command[1] == 'status') {
    return client.getSearchStatus();
  }
  if (command.length == 2 &&
      command[0] == 'search-index' &&
      command[1] == 'rebuild') {
    return client.rebuildSearchIndex(commandId: _commandId());
  }
  throw const FormatException('Unknown command.');
}

String _commandId() {
  final Random random = Random.secure();
  final Uint8List bytes = Uint8List(18);
  for (int index = 0; index < bytes.length; index++) {
    bytes[index] = random.nextInt(256);
  }
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _humanReadable(Object value) {
  if (value is List<JsonMap>) {
    if (value.isEmpty) {
      return 'No items.';
    }
    return value
        .map(
          (JsonMap item) =>
              '${item['workspace_id'] ?? item['document_id']}\t${item['name'] ?? item['title']}',
        )
        .join('\n');
  }
  if (value is JsonMap) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
  return value.toString();
}

int _exitCode(String errorCode) => switch (errorCode) {
  'InvalidArgument' => 2,
  'Unauthenticated' || 'ScopeDenied' => 77,
  'WorkspaceNotFound' || 'DocumentNotFound' => 66,
  'RevisionConflict' || 'CommandIdReused' => 75,
  'LocaldUnavailable' || 'LocaldStarting' => 69,
  _ => 70,
};

final class _CliArguments {
  const _CliArguments({
    required this.profile,
    required this.profileRoot,
    required this.json,
    required this.command,
  });

  final String profile;
  final String? profileRoot;
  final bool json;
  final List<String> command;

  static _CliArguments parse(List<String> arguments) {
    String profile = 'default';
    String? profileRoot;
    bool json = false;
    final List<String> command = <String>[];
    for (int index = 0; index < arguments.length; index++) {
      switch (arguments[index]) {
        case '--profile':
          if (index + 1 >= arguments.length) {
            throw const FormatException('Missing --profile value.');
          }
          profile = arguments[++index];
          continue;
        case '--profile-root':
          if (index + 1 >= arguments.length) {
            throw const FormatException('Missing --profile-root value.');
          }
          profileRoot = arguments[++index];
          continue;
        case '--json':
          json = true;
          continue;
        default:
          command.add(arguments[index]);
      }
    }
    if (command.isEmpty) {
      throw const FormatException('A command is required.');
    }
    return _CliArguments(
      profile: profile,
      profileRoot: profileRoot,
      json: json,
      command: command,
    );
  }
}

const String _usage = '''
Usage:
  endless [--profile ID] [--profile-root PATH] [--json] health
  endless [options] workspace list
  endless [options] workspace create NAME
  endless [options] document list WORKSPACE_ID
  endless [options] document get DOCUMENT_ID
  endless [options] document create WORKSPACE_ID TITLE
  endless [options] document move DOCUMENT_ID PARENT_ID|root
  endless [options] document delete DOCUMENT_ID
  endless [options] document restore DOCUMENT_ID
  endless [options] search WORKSPACE_ID QUERY
  endless [options] search-index status
  endless [options] search-index rebuild
''';
