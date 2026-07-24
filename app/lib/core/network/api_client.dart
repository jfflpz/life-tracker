import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../features/track_history/models/daily_track.dart';
import '../../features/track_history/models/timeline.dart';
import '../../features/track_history/models/monthly_summary.dart';

class ApiClient {                                                                                                                              
  static const String baseUrl = 'http://192.168.100.57:8000/api/v1';                                                                           
                                                                                                                                                
  late final Dio _dio;                                                                                                                         
                                                                                                                                                
  ApiClient() {                                                                                                                                
    _dio = Dio(BaseOptions(                                                                                                                    
      baseUrl: baseUrl,                                                                                                                        
      connectTimeout: const Duration(seconds: 3),                                                                                              
      receiveTimeout: const Duration(seconds: 10),                                                                                             
      validateStatus: (status) => status != null && status < 600,                                                                              
    ));                                                                                                                                        
                                                                                                                                                
    if (kDebugMode) {                                                                                                                          
      _dio.interceptors.add(LogInterceptor(                                                                                                    
        request: true,                                                                                                                         
        requestHeader: false,                                                                                                                  
        requestBody: true,                                                                                                                     
        responseHeader: false,                                                                                                                 
        responseBody: false,                                                                                                                   
        error: true,                                                                                                                           
      ));                                                                                                                                      
    }                                                                                                                                          
  }                                                                                                                                            
                                                                                                                                                
  Future<bool> syncPoints(List<Map<String, dynamic>> points) async {                                                                           
    if (points.isEmpty) return true;                                                                                                           
                                                                                                                                                
    try {                                                                                                                                      
      final formattedPoints = points.map((p) => {                                                                                              
        'recorded_at': p['recorded_at'],                                                                                                       
        'location': [p['lon'], p['lat']],                                                                                                      
        'accuracy': 10.0,                                                                                                                      
      }).toList();                                                                                                                             
                                                                                                                                                
      final batchResponse = await _dio.post(                                                                                                   
        '/points/batch',                                                                                                                       
        data: {'points': formattedPoints},                                                                                                     
      );                                                                                                                                       
                                                                                                                                                
      if (batchResponse.statusCode != 200) {                                                                                                   
        debugPrint('Sync failed with status: ${batchResponse.statusCode}');                                                                    
        return false;                                                                                                                          
      }                                                                                                                                        
                                                                                                                                                
      final today = DateTime.now().toIso8601String().split('T')[0];                                                                            
      await _dio.post('/snap/$today');                                                                                                         
                                                                                                                                                
      return true;                                                                                                                             
    } on DioException catch (e) {                                                                                                              
      _handleNetworkError(e, 'syncPoints');                                                                                                    
      return false;                                                                                                                            
    } catch (e) {                                                                                                                              
      debugPrint('Unexpected error during sync: $e');                                                                                          
      return false;                                                                                                                            
    }                                                                                                                                          
  }                                                                                                                                            
                                                                                                                                                
  Future<DailyTrack?> getDailyTrack(String dateYYYYMMDD) async {                                                                               
    try {                                                                                                                                      
      final response = await _dio.get('/daily/$dateYYYYMMDD');                                                                                 
                                                                                                                                                
      if (response.statusCode == 200) {                                                                                                        
        return DailyTrack.fromJson(response.data);                                                                                             
      }                                                                                                                                        
                                                                                                                                                
      if (response.statusCode != 404) {
        debugPrint('Failed to get track, status: ${response.statusCode}');
      }
      return null;
    } on DioException catch (e) {
      _handleNetworkError(e, 'getDailyTrack');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching daily track: $e');
      return null;
    }
  }

  Future<List<dynamic>> getPins() async {
    try {
      final response = await _dio.get('/pins');
      return response.statusCode == 200 ? response.data : [];
    } catch (e) {
      debugPrint('Error fetching pins: $e');
      return [];
    }
  }

  Future<bool> createPin(String label, double lat, double lon) async {
    try {
      final response = await _dio.post('/pins', data: {
        'label': label,
        'location': [lon, lat],
        'radius_m': 100.0,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating pin: $e');
      return false;
    }
  }

  Future<TimelineResponse?> getDailyTimeline(String dateYYYYMMDD) async {
    try {
      final response = await _dio.get('/daily/$dateYYYYMMDD/timeline');
      if (response.statusCode == 200) {
        return TimelineResponse.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      _handleNetworkError(e, 'getDailyTimeline');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching timeline: $e');
      return null;
    }
  }

  Future<MonthlySummary?> getMonthlySummary(int year, int month) async {
    try {
      // API expects zero-padded month strings for paths or maybe ints, depending on backend implementation.
      // But FastAPI handles integer path parameters nicely.
      final response = await _dio.get('/daily/summary/$year/$month');
      if (response.statusCode == 200) {
        return MonthlySummary.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      _handleNetworkError(e, 'getMonthlySummary');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching monthly summary: $e');
      return null;
    }
  }

  void _handleNetworkError(DioException e, String context) {
    if (e.type == DioExceptionType.connectionTimeout || 
        e.type == DioExceptionType.receiveTimeout) {
      debugPrint('[$context] Network Timeout: The server took too long to respond.');
    } else if (e.type == DioExceptionType.connectionError) {
      debugPrint('[$context] Connection Error: Are you connected to the right Wi-Fi?');
    } else {
      debugPrint('[$context] DioException: ${e.message}');
    }
  }
}
