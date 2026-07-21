import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/daily_track.dart';
import 'history_screen.dart';
import '../services/api_client.dart';
import '../services/database_helper.dart';
import '../widgets/animated_location_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.app/location');

  final ApiClient _apiClient = ApiClient();
  final MapController _mapController = MapController();
  
  late final AnimationController _cameraController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  DailyTrack? _dailyTrack;
  LocationState? _locationState;
  List<LatLng> _livePoints = [];
  bool _isTracking = false;

  StreamSubscription<Position>? _positionStream;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// When app comes back from background, reload SQLite points to catch up
  /// with everything the Kotlin service recorded while Flutter was suspended
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLivePoints();
    }
  }

  /// Initialize permissions, get first position, then start the live GPS stream
  Future<void> _initLocationAndStart() async {
    // 1. Check & request permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Request background location for the Kotlin foreground service
    await Permission.locationAlways.request();

    // 2. Get initial position so the map can render immediately
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationState = LocationState(
        point: LatLng(position.latitude, position.longitude),
        heading: position.heading,
        accuracy: position.accuracy,
      );
    });

    // 3. Load any existing unsynced points from SQLite
    await _loadLivePoints();

    // 4. Try to fetch today's synced route (silently fails if offline)
    _fetchTodayRoute();

    // 5. Start the continuous GPS stream (this is what makes the pin move)
    _startPositionStream();

    // 6. Poll SQLite every 5 seconds to pick up Kotlin background writes
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadLivePoints();
    });
  }

  /// Continuous GPS stream — makes the pin move and the trail grow like Strava
  void _startPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Lowered to 2m for smoother walking tracking
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);

      setState(() {
        _locationState = LocationState(
          point: newPoint,
          heading: position.heading,
          accuracy: position.accuracy,
        );

        // If tracking is active, grow the orange trail instantly
        // (The Timer will reconcile with SQLite data every 5 seconds)
        if (_isTracking) {
          _livePoints.add(newPoint);
        }
      });

      // Move the map camera smoothly to follow the user
      _animatedMapMove(newPoint, _mapController.camera.zoom);
    });
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    try {
      final latTween = Tween<double>(
          begin: _mapController.camera.center.latitude, end: destLocation.latitude);
      final lngTween = Tween<double>(
          begin: _mapController.camera.center.longitude, end: destLocation.longitude);
      final zoomTween = Tween<double>(
          begin: _mapController.camera.zoom, end: destZoom);

      _cameraController.reset();
      
      // Need a local animation variable to evaluate within the listener
      final Animation<double> animation = CurvedAnimation(
        parent: _cameraController, 
        curve: Curves.fastOutSlowIn
      );

      // We add a listener just for this animation run, and clear it afterwards
      void listener() {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      }
      
      _cameraController.addListener(listener);
      _cameraController.forward().then((_) {
        _cameraController.removeListener(listener);
      });
    } catch (_) {
      // MapController might not be ready yet
    }
  }

  /// Load pending points from SQLite (catches Kotlin background service writes)
  Future<void> _loadLivePoints() async {
    final pending = await DatabaseHelper.instance.getPendingPoints();
    if (mounted) {
      setState(() {
        _livePoints = pending.map((p) => LatLng(p['lat'], p['lon'])).toList();
      });
    }
  }

  /// Fetch today's synced blue route from the backend (silently fails if offline)
  Future<void> _fetchTodayRoute() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final track = await _apiClient.getDailyTrack(today);
    if (mounted) {
      setState(() {
        _dailyTrack = track;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );

              if (selectedDate != null && context.mounted) {
                final dateStr = selectedDate.toIso8601String().split('T')[0];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(dateYYYYMMDD: dateStr),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _locationState == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _locationState!.point,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.life_tracker',
                ),
                PolylineLayer(
                  polylines: [
                    // 1. The Synced Blue Line (from backend, road-snapped)
                    if (_dailyTrack != null)
                      Polyline(
                        points: _dailyTrack!.routePoints,
                        color: Colors.blue,
                        strokeWidth: 4.0,
                      ),
                    // 2. The Unsynced Orange Line (from local SQLite)
                    if (_livePoints.length >= 2)
                      Polyline(
                        points: _livePoints,
                        color: Colors.orange,
                        strokeWidth: 4.0,
                      ),
                  ],
                ),
                if (_locationState != null)
                  AnimatedLocationLayer(state: _locationState!),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Start/Stop Tracking toggle button
          FloatingActionButton.extended(
            heroTag: 'track_toggle_btn',
            backgroundColor: _isTracking ? Colors.redAccent : Colors.orange,
            onPressed: () async {
              try {
                if (_isTracking) {
                  // Stop the Kotlin background service
                  await platform.invokeMethod('stopService');
                  setState(() => _isTracking = false);
                  // Reload SQLite to show final state of trail
                  await _loadLivePoints();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tracking stopped.')),
                    );
                  }
                } else {
                  // Start the Kotlin background service
                  await platform.invokeMethod('startService');
                  setState(() => _isTracking = true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Background tracking started!'),
                      ),
                    );
                  }
                }
              } catch (e) {
                print("Tracking toggle error: $e");
              }
            },
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(_isTracking ? "Stop Tracking" : "Start Tracking"),
          ),
          const SizedBox(height: 16),
          // Sync to Cloud button
          FloatingActionButton.extended(
            heroTag: 'sync_btn',
            backgroundColor: Colors.green,
            onPressed: () async {
              final pending =
                  await DatabaseHelper.instance.getPendingPoints();
              if (pending.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No points to sync!')),
                  );
                }
                return;
              }

              final success = await _apiClient.syncPoints(pending);
              if (success) {
                await DatabaseHelper.instance.clearPendingPoints();
                setState(() => _livePoints.clear());
                await _fetchTodayRoute();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Synced to cloud & snapped to roads!'),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sync failed. Connect to home Wi-Fi and try again.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Sync to Cloud"),
          ),
        ],
      ),
    );
  }
}
