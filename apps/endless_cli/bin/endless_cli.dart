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
    return client.listWorkspaces(includeArchived: true);
  }
  if (command.length >= 3 &&
      command[0] == 'workspace' &&
      command[1] == 'create') {
    return client.createWorkspace(
      commandId: _commandId(),
      name: command.sublist(2).join(' '),
    );
  }
  if (command.length == 3 && command[0] == 'workspace' && command[1] == 'get') {
    return client.getWorkspace(command[2]);
  }
  if (command.length >= 4 &&
      command[0] == 'workspace' &&
      command[1] == 'rename') {
    final JsonMap workspace = await client.getWorkspace(command[2]);
    return client.renameWorkspace(
      commandId: _commandId(),
      workspaceId: command[2],
      name: command.sublist(3).join(' '),
      expectedRevision: requireInt(workspace, 'revision'),
    );
  }
  if (command.length == 3 &&
      command[0] == 'workspace' &&
      <String>{'archive', 'restore'}.contains(command[1])) {
    final JsonMap workspace = await client.getWorkspace(command[2]);
    return client.archiveWorkspace(
      commandId: _commandId(),
      workspaceId: command[2],
      archived: command[1] == 'archive',
      expectedRevision: requireInt(workspace, 'revision'),
    );
  }
  if (command.length == 3 &&
      command[0] == 'workspace' &&
      command[1] == 'delete') {
    final JsonMap workspace = await client.getWorkspace(command[2]);
    return client.deleteWorkspace(
      commandId: _commandId(),
      workspaceId: command[2],
      expectedRevision: requireInt(workspace, 'revision'),
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
  if ((command.length == 4 || command.length == 5) &&
      command[0] == 'attachment' &&
      command[1] == 'add') {
    final File source = File(command[3]).absolute;
    if (!await source.exists()) {
      throw const LocalApiException(
        code: 'InvalidArgument',
        message: 'Attachment source file does not exist.',
        retryable: false,
      );
    }
    final int size = await source.length();
    final JsonMap document = await client.getDocument(command[2]);
    final JsonMap staged = await client.stageAttachment(
      bytes: source.openRead(),
      fileName: _baseName(source.path),
      mediaType: command.length == 5 ? command[4] : 'application/octet-stream',
      contentLength: size,
    );
    return client.attachStagedFile(
      commandId: _commandId(),
      documentId: command[2],
      stagingToken: requireString(staged, 'token'),
      expectedDocumentRevision: requireInt(document, 'revision'),
    );
  }
  if (command.length == 3 &&
      command[0] == 'attachment' &&
      command[1] == 'list') {
    return client.listAttachments(documentId: command[2]);
  }
  if (command.length == 3 &&
      command[0] == 'attachment' &&
      command[1] == 'get') {
    return client.getAttachment(command[2]);
  }
  if (command.length == 3 &&
      command[0] == 'attachment' &&
      command[1] == 'delete') {
    final JsonMap attachment = await client.getAttachment(command[2]);
    return client.deleteAttachment(
      commandId: _commandId(),
      attachmentId: command[2],
      expectedRevision: requireInt(attachment, 'revision'),
    );
  }
  if (command.length == 4 &&
      command[0] == 'attachment' &&
      command[1] == 'download') {
    final File target = File(command[3]).absolute;
    if (await target.exists()) {
      throw const LocalApiException(
        code: 'InvalidArgument',
        message: 'Attachment download target already exists.',
        retryable: false,
      );
    }
    final AttachmentDownload download = await client.downloadAttachment(
      command[2],
    );
    final IOSink output = target.openWrite(mode: FileMode.writeOnly);
    bool closed = false;
    try {
      await output.addStream(download.bytes);
      await output.flush();
      await output.close();
      closed = true;
    } on Object {
      if (!closed) {
        try {
          await output.close();
        } on Object {
          // Preserve the transfer failure; the partial target is removed below.
        }
      }
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
    return <String, Object?>{
      'attachment_id': download.attachmentId,
      'file_name': download.fileName,
      'media_type': download.mediaType,
      'sha256': download.sha256,
      'size': download.size,
      'output_path': target.path,
    };
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
              '${item['attachment_id'] ?? item['document_id'] ?? item['workspace_id']}'
              '\t${item['file_name'] ?? item['title'] ?? item['name']}',
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
  'WorkspaceNotFound' || 'DocumentNotFound' || 'AttachmentNotFound' => 66,
  'RevisionConflict' || 'CommandIdReused' => 75,
  'LocaldUnavailable' || 'LocaldStarting' => 69,
  _ => 70,
};

String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;

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
  endless [options] workspace get WORKSPACE_ID
  endless [options] workspace rename WORKSPACE_ID NAME
  endless [options] workspace archive WORKSPACE_ID
  endless [options] workspace restore WORKSPACE_ID
  endless [options] workspace delete WORKSPACE_ID
  endless [options] document list WORKSPACE_ID
  endless [options] document get DOCUMENT_ID
  endless [options] document create WORKSPACE_ID TITLE
  endless [options] document move DOCUMENT_ID PARENT_ID|root
  endless [options] document delete DOCUMENT_ID
  endless [options] document restore DOCUMENT_ID
  endless [options] attachment add DOCUMENT_ID FILE [MEDIA_TYPE]
  endless [options] attachment list DOCUMENT_ID
  endless [options] attachment get ATTACHMENT_ID
  endless [options] attachment delete ATTACHMENT_ID
  endless [options] attachment download ATTACHMENT_ID OUTPUT_PATH
  endless [options] search WORKSPACE_ID QUERY
  endless [options] search-index status
  endless [options] search-index rebuild
''';
