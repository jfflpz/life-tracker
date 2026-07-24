import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_track.dart';
import '../../../core/network/api_client.dart';
import '../../../core/local_db/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  final String dateYYYYMMDD;

  const HistoryScreen({super.key, required this.dateYYYYMMDD});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiClient _apiClient = ApiClient();
  DailyTrack? _dailyTrack;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrack();
  }

  Future<void> _fetchTrack() async {
    try {
      // 1. Fetch from Local Database
      final localPointsMap = await DatabaseHelper.instance.getPointsForDate(widget.dateYYYYMMDD);
      final localPoints = localPointsMap.map((p) => LatLng(p['lat'], p['lon'])).toList();
      
      // 2. Fetch from Backend API
      DailyTrack? apiTrack;
      try {
        apiTrack = await _apiClient.getDailyTrack(widget.dateYYYYMMDD);
      } catch (e) {
        debugPrint('API fetch failed or no track found: $e');
      }

      // 3. Merge them together
      final mergedPoints = <LatLng>[];
      if (apiTrack != null && apiTrack.routePoints.isNotEmpty) {
        mergedPoints.addAll(apiTrack.routePoints);
      }
      mergedPoints.addAll(localPoints);
      
      if (mergedPoints.isNotEmpty) {
        final syntheticTrack = DailyTrack(
          id: apiTrack?.id ?? 'merged_local_api',
          date: widget.dateYYYYMMDD,
          distanceMeters: apiTrack?.distanceMeters ?? 0.0,
          pointCount: mergedPoints.length,
          routePoints: mergedPoints,
        );
        setState(() {
          _dailyTrack = syntheticTrack;
          _isLoading = false;
        });
      } else {
        setState(() {
          _dailyTrack = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching daily track: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History: ${widget.dateYYYYMMDD}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dailyTrack == null
              ? Center(
                  child: Text(
                    'No route recorded for ${widget.dateYYYYMMDD}',
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _dailyTrack!.routePoints.isNotEmpty
                        ? _dailyTrack!.routePoints.first
                        : const LatLng(14.778, 121.024),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.life_tracker',
                    ),
                    
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _dailyTrack!.routePoints,
                          color: Colors.blue,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),

                    MarkerLayer(
                      markers: [
                        if (_dailyTrack!.routePoints.isNotEmpty) ...[
                          Marker(
                            point: _dailyTrack!.routePoints.first,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                          ),
                          Marker(
                            point: _dailyTrack!.routePoints.last,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
    );
  }
}
