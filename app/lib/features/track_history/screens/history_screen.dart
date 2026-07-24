import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_track.dart';
import '../models/timeline.dart';
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
  TimelineResponse? _timeline;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrack();
  }

  Future<void> _fetchTrack() async {
    try {
      final track = await _apiClient.getDailyTrack(widget.dateYYYYMMDD);
      final timeline = await _apiClient.getDailyTimeline(widget.dateYYYYMMDD);

      if (timeline != null) {
        debugPrint('--- TIMELINE FETCHED ---');
        debugPrint('Version: ${timeline.metadata.version}');
        debugPrint('Events: ${timeline.events.length}');
        debugPrint('Total Distance: ${timeline.summary.totalDistanceM}');
        debugPrint('First event ID: ${timeline.events.first.id}');
      } else {
        debugPrint('--- TIMELINE FETCH FAILED ---');
      }

      setState(() {
        _dailyTrack = track;
        _timeline = timeline;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching daily track or timeline: $error');
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
                      urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      userAgentPackageName: 'com.example.life_tracker',
                      retinaMode: true,
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
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                          ),
                          Marker(
                            point: _dailyTrack!.routePoints.last,
                            width: 30,
                            height: 30,
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
