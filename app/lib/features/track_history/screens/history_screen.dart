import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_track.dart';
import '../models/timeline.dart';
import '../widgets/timeline_panel.dart';
import '../../../core/network/api_client.dart';

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
      final results = await Future.wait([
        _apiClient.getDailyTrack(widget.dateYYYYMMDD).catchError((_) => null),
        _apiClient.getDailyTimeline(widget.dateYYYYMMDD).catchError((_) => null),
      ]);

      if (!mounted) return;

      final track = results[0] as DailyTrack?;
      final timeline = results[1] as TimelineResponse?;

      setState(() {
        _dailyTrack = track;
        _timeline = timeline;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
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
          : Stack(
              children: [
                Positioned.fill(
                  child: _dailyTrack == null
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
                ),
                if (_timeline != null)
                  DraggableScrollableSheet(
                    initialChildSize: 0.2,
                    minChildSize: 0.1,
                    maxChildSize: 0.9,
                    snap: true,
                    snapSizes: const [0.2, 0.5, 0.9],
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: PrimaryScrollController(
                          controller: scrollController,
                          child: Column(
                            children: [
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TimelinePanel(timeline: _timeline!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
