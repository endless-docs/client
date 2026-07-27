final class DomainException implements Exception {
  const DomainException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DomainException($code): $message';
}
