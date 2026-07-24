import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_track.dart';
import '../models/timeline.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/breadcrumb_layer.dart';
import '../../../core/network/api_client.dart';
import '../widgets/calendar/calendar_modal.dart';
import '../widgets/animated_route_layer.dart';

class HistoryScreen extends StatefulWidget {
  final String dateYYYYMMDD;

  const HistoryScreen({super.key, required this.dateYYYYMMDD});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  late String _currentDate;
  DailyTrack? _dailyTrack;
  TimelineResponse? _timeline;
  bool _isLoading = true;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late final CurvedAnimation _curvedAnimation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _currentDate = widget.dateYYYYMMDD;
    _fetchTrack();
  }

  Future<void> _fetchTrack() async {
    _animationController.stop();
    _animationController.reset();

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiClient.getDailyTrack(_currentDate).catchError((_) => null),
        _apiClient.getDailyTimeline(_currentDate).catchError((_) => null),
      ]);

      if (!mounted) return;

      final track = results[0] as DailyTrack?;
      final timeline = results[1] as TimelineResponse?;

      setState(() {
        _dailyTrack = track;
        _timeline = timeline;
        _isLoading = false;
      });

      _startAnimationIfNeeded();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openCalendar() async {
    final DateTime initialDate = DateTime.parse(_currentDate);
    final DateTime? selectedDate = await CalendarModal.show(
      context, 
      initialDate: initialDate,
    );
    
    if (selectedDate != null && mounted) {
      final String dateStr = selectedDate.toIso8601String().split('T')[0];
      if (dateStr != _currentDate) {
        setState(() {
          _currentDate = dateStr;
        });
        _fetchTrack();
      }
    }
  }

  void _startAnimationIfNeeded() {
    if (_dailyTrack == null || _dailyTrack!.routePoints.isEmpty) return;
    
    final pointsCount = _dailyTrack!.routePoints.length;
    if (pointsCount < 10) {
      _animationController.value = 1.0;
      return;
    }

    int durationSec = (pointsCount / 500).ceil();
    durationSec = durationSec.clamp(2, 5);

    _animationController.duration = Duration(seconds: durationSec);
    _animationController.forward();
  }

  void _skipAnimation() {
    _animationController.value = 1.0;
  }

  void _replayAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _curvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History: $_currentDate'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _openCalendar,
            tooltip: 'Open Calendar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: _dailyTrack == null
                      ? Center(
                          child: Text(
                            'No route recorded for $_currentDate',
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
                            AnimatedRouteLayer(
                              routePoints: _dailyTrack!.routePoints,
                              animation: _curvedAnimation,
                            ),
                            BreadcrumbLayer(
                              routePoints: _dailyTrack!.routePoints,
                              animation: _curvedAnimation,
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
                if (_dailyTrack != null && _dailyTrack!.routePoints.length >= 10)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final isAnimating = _animationController.isAnimating;
                        final isCompleted = _animationController.isCompleted;

                        if (isCompleted || !isAnimating) {
                          return FloatingActionButton.small(
                            heroTag: 'replay_btn',
                            onPressed: _replayAnimation,
                            tooltip: 'Replay Route',
                            child: const Icon(Icons.replay),
                          );
                        } else {
                          return FloatingActionButton.small(
                            heroTag: 'skip_btn',
                            onPressed: _skipAnimation,
                            tooltip: 'Skip Animation',
                            child: const Icon(Icons.fast_forward),
                          );
                        }
                      },
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
