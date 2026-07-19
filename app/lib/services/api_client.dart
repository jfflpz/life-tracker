import 'package:dio/dio.dart';
import '../models/daily_track.dart';

class ApiClient {
  // Use localhost for local dev. If testing on a physical Android device, 
  // you might need to use 10.0.2.2 instead of 127.0.0.1
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
  final Dio _dio = Dio();

  Future<DailyTrack?> getDailyTrack(String dateYYYYMMDD) async {
    try {
      // TODO: Make a GET request to '$baseUrl/daily/$dateYYYYMMDD'
      // final response = await _dio.get(...);

      final response = await _dio.get('$baseUrl/daily/$dateYYYYMMDD');
      
      // TODO: Check if response.statusCode == 200.
      // If it is, return DailyTrack.fromJson(response.data);
      // If the status code is 404, return null (no track for that day).
      
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
      await _dio.post('$baseUrl/snap/$today');
      
      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
}
