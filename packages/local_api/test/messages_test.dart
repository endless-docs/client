import 'package:local_api/local_api.dart';
import 'package:test/test.dart';

void main() {
  test('endpoint manifest round trips without losing session data', () {
    const EndpointManifest endpoint = EndpointManifest(
      port: 12345,
      sessionProof: 'secret',
      profileId: 'default',
      processId: 42,
      apiVersion: localApiVersion,
    );

    final EndpointManifest restored = EndpointManifest.fromJson(
      endpoint.toJson(),
    );

    expect(restored.port, endpoint.port);
    expect(restored.sessionProof, endpoint.sessionProof);
    expect(restored.baseUri.host, '127.0.0.1');
  });
}
