import 'package:dio/dio.dart';
import '../models/daily_track.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.100.57:8000/api/v1';

  // 3-second timeout so sync fails fast when offline instead of hanging
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 10),
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
        'accuracy': 10.0,
      }).toList();

      // 1. Upload to the batch endpoint
      final batchResponse = await _dio.post(
        '$baseUrl/points/batch',
        data: {'points': formattedPoints},
      );
      if (batchResponse.statusCode != 200) return false;

      // 2. Tell the backend to snap today's route to the roads
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _dio.post('$baseUrl/snap/$today');

      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  /// Fetches a daily track from the backend. Returns null if offline or no data.
  Future<DailyTrack?> getDailyTrack(String dateYYYYMMDD) async {
    try {
      final response = await _dio.get('$baseUrl/daily/$dateYYYYMMDD');

      if (response.statusCode == 200) {
        return DailyTrack.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Silently fail — this is expected when offline
      print('Error fetching daily track: $e');
      return null;
    }
  }
}
