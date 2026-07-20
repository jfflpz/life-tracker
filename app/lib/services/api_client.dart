import 'package:dio/dio.dart';
import '../models/daily_track.dart';

class ApiClient {
  // Use the Linux computer's local Wi-Fi IP address instead of localhost
  final String baseUrl = 'http://192.168.100.57:8000/api/v1';
  final Dio _dio = Dio();

  Future<DailyTrack?> getDailyTrack(String dateYYYYMMDD) async {
    try {
      final response = await _dio.get('$baseUrl/daily/$dateYYYYMMDD');
      
      if (response.statusCode == 200) {
        return DailyTrack.fromJson(response.data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load daily track');
      }

      return null;
    } catch (e) {
      print('Error fetching daily track: $e');
      return null;
    }
  }

  Future<bool> syncPoints(List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return true;
    
    // Map the SQLite format to the FastAPI schema format!
    // FastAPI expects: {'location': [lon, lat], 'recorded_at': '...', 'accuracy': 10.0}
    final formattedPoints = points.map((p) => {
      'location': [p['lon'], p['lat']],
      'recorded_at': p['recorded_at'],
      'accuracy': 10.0, // Mock accuracy for now
    }).toList();
    
    try {
      // 1. Upload to the batch endpoint
      final batchResponse = await _dio.post(
        '$baseUrl/points/batch',
        data: {'points': formattedPoints},
      );
      
      if (batchResponse.statusCode != 200) return false;
      
      // 2. Tell the backend to snap today's route to the roads
      final today = DateTime.now().toIso8601String().split('T')[0];
      try {
        await _dio.post('$baseUrl/snap/$today');
      } catch (e) {
        print('Snap error (but points were saved): $e');
      }
      
      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
}
