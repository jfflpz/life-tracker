import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_track.dart';
import '../config/app_config.dart';
import '../config/app_constants.dart';

class ApiClient {
  // Uses timeouts from AppConstants
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
    receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSeconds),
  ));

  /// Syncs pending GPS points to the backend and triggers road snapping.
  /// Returns true on success, false on any failure (including being offline).
  Future<bool> syncPoints(List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return true;

    try {
      // Format points to match FastAPI GPSPointCreate schema
      final formattedPoints = points.map((p) => {
        'recorded_at': p['recorded_at'],
        'location': [p['lon'], p['lat']],
        'accuracy': AppConstants.defaultAccuracy,
      }).toList();

      // 1. Upload to the batch endpoint
      final batchResponse = await _dio.post(
        '${AppConfig.baseUrl}/points/batch',
        data: {'points': formattedPoints},
      );
      if (batchResponse.statusCode != 200) return false;

      // 2. Tell the backend to snap today's route to the roads
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _dio.post('${AppConfig.baseUrl}/snap/$today');

      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      return false;
    }
  }

  /// Fetches a daily track from the backend. Returns null if offline or no data.
  Future<DailyTrack?> getDailyTrack(String dateYYYYMMDD) async {
    try {
      final response = await _dio.get('${AppConfig.baseUrl}/daily/$dateYYYYMMDD');

      if (response.statusCode == 200) {
        return DailyTrack.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Silently fail — this is expected when offline
      debugPrint('Error fetching daily track: $e');
      return null;
    }
  }
}
