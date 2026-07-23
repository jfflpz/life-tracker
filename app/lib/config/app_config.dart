class AppConfig {
  // Uses --dart-define=BASE_URL=http://... at build time
  // Falls back to local LAN for debug builds
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.100.57:8000/api/v1',
  );
}
