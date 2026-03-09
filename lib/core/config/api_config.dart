class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = 'https://farma.dalekopro.hr';
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
