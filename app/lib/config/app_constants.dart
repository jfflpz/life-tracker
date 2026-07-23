class AppConstants {
  AppConstants._();

  // Platform Channel
  static const String locationChannel = 'com.example.app/location';
  static const String startServiceMethod = 'startService';
  static const String stopServiceMethod = 'stopService';

  // Map
  static const String tileServerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackage = 'com.example.life_tracker';
  static const double defaultZoom = 16.0;
  static const double historyZoom = 15.0;

  // GPS
  static const int distanceFilterMeters = 2;
  static const int sqlitePollIntervalSeconds = 5;

  // Animation
  static const int cameraAnimationMs = 500;

  // Database
  static const String databaseName = 'life_tracker.db';
  static const String pendingPointsTable = 'pending_points';

  // Fallback coordinates (Quezon City)
  static const double fallbackLat = 14.778;
  static const double fallbackLon = 121.024;

  // Sync
  static const int connectTimeoutSeconds = 3;
  static const int receiveTimeoutSeconds = 10;
  static const double defaultAccuracy = 10.0;
}
