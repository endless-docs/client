import 'errors.dart';

const int maxWorkspaceNameLength = 120;
const int maxDocumentTitleLength = 300;
const int maxBlockTextLength = 1000000;
const int maxAttachmentFileNameLength = 255;
const int maxAttachmentMediaTypeLength = 200;
const int maxAttachmentBytes = 100 * 1024 * 1024;

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

String validateAttachmentFileName(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty ||
      normalized == '.' ||
      normalized == '..' ||
      normalized.length > maxAttachmentFileNameLength ||
      normalized.contains('/') ||
      normalized.contains('\\') ||
      normalized.contains('\u0000')) {
    throw const DomainException(
      'InvalidArgument',
      'Attachment file name is invalid.',
    );
  }
  return normalized;
}

String validateAttachmentMediaType(String value) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized.length > maxAttachmentMediaTypeLength ||
      !RegExp(
        r"^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$",
      ).hasMatch(normalized)) {
    throw const DomainException(
      'InvalidArgument',
      'Attachment media type is invalid.',
    );
  }
  return normalized;
}

String validateAttachmentHash(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const DomainException(
      'InvalidArgument',
      'Attachment SHA-256 is invalid.',
    );
  }
  return value;
}

int validateAttachmentSize(int value) {
  if (value < 0 || value > maxAttachmentBytes) {
    throw const DomainException(
      'InvalidArgument',
      'Attachment size is outside the supported range.',
    );
  }
  return value;
}

String validateAttachmentStagingToken(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(value)) {
    throw const DomainException(
      'InvalidArgument',
      'Attachment staging token is invalid.',
    );
  }
  return value;
}
