import 'errors.dart';

const int maxWorkspaceNameLength = 120;
const int maxDocumentTitleLength = 300;
const int maxBlockTextLength = 1000000;

String validateWorkspaceName(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw const DomainException(
      'InvalidArgument',
      'Workspace name must not be empty.',
    );
  }
  if (normalized.length > maxWorkspaceNameLength) {
    throw const DomainException(
      'InvalidArgument',
      'Workspace name is too long.',
    );
  }
  return normalized;
}

String validateDocumentTitle(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw const DomainException(
      'InvalidArgument',
      'Document title must not be empty.',
    );
  }
  if (normalized.length > maxDocumentTitleLength) {
    throw const DomainException(
      'InvalidArgument',
      'Document title is too long.',
    );
  }
  return normalized;
}

String validateBlockText(String value) {
  if (value.length > maxBlockTextLength) {
    throw const DomainException(
      'InvalidArgument',
      'Document block is too large.',
    );
  }
  return value;
}
