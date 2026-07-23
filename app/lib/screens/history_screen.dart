import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_track.dart';
import '../services/api_client.dart';
import '../config/app_constants.dart';

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
    
    _apiClient.getDailyTrack(widget.dateYYYYMMDD).then((track) {
      if (!mounted) return;
      setState(() {
        _dailyTrack = track;
        _isLoading = false;
      });
    }).catchError((error) {
      debugPrint('Error fetching daily track: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    });

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
                        : const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLon),
                    initialZoom: AppConstants.historyZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConstants.tileServerUrl,
                      userAgentPackageName: AppConstants.userAgentPackage,
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
