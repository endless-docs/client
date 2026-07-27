import 'dart:async';

import 'package:client_domain/client_domain.dart';

abstract interface class Clock {
  DateTime now();
}

abstract interface class IdGenerator {
  String nextId();
}

abstract interface class ClientStore {
  Future<T> read<T>(FutureOr<T> Function(ClientStoreReader reader) operation);

  Future<T> write<T>(FutureOr<T> Function(ClientStoreWriter writer) operation);
}

abstract interface class ClientStoreReader {
  Future<Workspace?> getWorkspace(String workspaceId);

  Future<List<Workspace>> listWorkspaces({bool includeArchived = false});

  Future<Document?> getDocument(String documentId);

  Future<List<Document>> listDocuments(
    String workspaceId, {
    bool includeDeleted = false,
  });

  Future<CommandOutcome?> getCommandOutcome(String commandId);
}

abstract interface class ClientStoreWriter implements ClientStoreReader {
  Future<void> putWorkspace(Workspace workspace);

  Future<void> putDocument(Document document);

  Future<int> nextEventSequence();

  Future<void> putCommandOutcome(CommandOutcome outcome);

  Future<void> appendOperation(Operation operation);
}
