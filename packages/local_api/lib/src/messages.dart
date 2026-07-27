typedef JsonMap = Map<String, Object?>;

const String localApiVersion = '1.1';
const String componentVersion = '0.1.0';
const int maximumRequestBytes = 2 * 1024 * 1024;
const int maximumAttachmentBytes = 100 * 1024 * 1024;
const int maximumBackupArchiveBytes = 20 * 1024 * 1024 * 1024;

enum LocalClientType { flutterUi, mcpServer, cli, integration }

final class LocalApiException implements Exception {
  const LocalApiException({
    required this.code,
    required this.message,
    required this.retryable,
    this.correlationId,
  });

  final String code;
  final String message;
  final bool retryable;
  final String? correlationId;

  JsonMap toJson() => <String, Object?>{
    'code': code,
    'message': message,
    'retryable': retryable,
    'correlation_id': correlationId,
  };

  factory LocalApiException.fromJson(JsonMap json) => LocalApiException(
    code: requireString(json, 'code'),
    message: requireString(json, 'message'),
    retryable: json['retryable'] == true,
    correlationId: json['correlation_id'] as String?,
  );

  @override
  String toString() => 'LocalApiException($code): $message';
}

final class EndpointManifest {
  const EndpointManifest({
    required this.port,
    required this.sessionProof,
    required this.profileId,
    required this.processId,
    required this.apiVersion,
  });

  final int port;
  final String sessionProof;
  final String profileId;
  final int processId;
  final String apiVersion;

  Uri get baseUri => Uri(scheme: 'http', host: '127.0.0.1', port: port);

  JsonMap toJson() => <String, Object?>{
    'port': port,
    'session_proof': sessionProof,
    'profile_id': profileId,
    'process_id': processId,
    'api_version': apiVersion,
  };

  factory EndpointManifest.fromJson(JsonMap json) => EndpointManifest(
    port: requireInt(json, 'port'),
    sessionProof: requireString(json, 'session_proof'),
    profileId: requireString(json, 'profile_id'),
    processId: requireInt(json, 'process_id'),
    apiVersion: requireString(json, 'api_version'),
  );
}

JsonMap requireMap(JsonMap source, String key) {
  final Object? value = source[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Expected "$key" to be an object.');
}

List<JsonMap> requireMapList(JsonMap source, String key) {
  final Object? value = source[key];
  if (value is! List<Object?>) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value.map((Object? item) {
    if (item is! Map<String, Object?>) {
      throw FormatException('Expected "$key" entries to be objects.');
    }
    return item;
  }).toList();
}

String requireString(JsonMap source, String key) {
  final Object? value = source[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
}

int requireInt(JsonMap source, String key) {
  final Object? value = source[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an integer.');
}

bool requireBool(JsonMap source, String key) {
  final Object? value = source[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected "$key" to be a boolean.');
}
