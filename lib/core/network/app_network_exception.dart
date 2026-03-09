class AppNetworkException implements Exception {
  const AppNetworkException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final Object? data;

  @override
  String toString() => message;
}
