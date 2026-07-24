import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../../track_history/screens/history_screen.dart';
import '../../track_history/widgets/calendar/calendar_modal.dart';
import '../../../core/network/api_client.dart';
import '../../../core/local_db/database_helper.dart';
import '../widgets/animated_location_layer.dart';
import '../widgets/modern_map_controls.dart';
import '../widgets/premium_bottom_panel.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}


class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver, TickerProviderStateMixin {


  final MapController _mapController = MapController();
  
  late final AnimationController _cameraController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // Removed _dailyTrack as it's not needed on main screen
  final ValueNotifier<bool> _isTrackingNotifier = ValueNotifier(false);
  final ValueNotifier<LocationState?> _locationNotifier = ValueNotifier(null);
  final ValueNotifier<List<LatLng>> _livePointsNotifier = ValueNotifier([]);
  final ValueNotifier<List<LatLng>> _archivedPointsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _pinsNotifier = ValueNotifier([]);
  bool _hasInitialLocation = false;

  StreamSubscription<Position>? _positionStream;
  Timer? _refreshTimer;

  Future<void> _loadPins() async {
    final apiClient = ApiClient();
    final pins = await apiClient.getPins();
    if (mounted) {
      _pinsNotifier.value = pins;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationAndStart();
    _loadPins();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLivePoints();
    }
  }

  Future<void> _initLocationAndStart() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    await Permission.locationAlways.request();

    Position position = await Geolocator.getCurrentPosition();
    _locationNotifier.value = LocationState(
      point: LatLng(position.latitude, position.longitude),
      heading: position.heading,
      accuracy: position.accuracy,
    );
    setState(() {
      _hasInitialLocation = true;
    });

    await _loadLivePoints();

    // _fetchTodayRoute() removed
    _startPositionStream(); 

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadLivePoints();
    });
  }

  void _startPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);

      _locationNotifier.value = LocationState(                                                                                                 
        point: newPoint,                                                                                                                       
        heading: position.heading,                                                                                                             
        accuracy: position.accuracy,
      );                                                                                                                                       
                                                                                                                                                
      if (_isTrackingNotifier.value) {
        _livePointsNotifier.value = List.from(_livePointsNotifier.value)..add(newPoint);
      }

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
      
      final Animation<double> animation = CurvedAnimation(
        parent: _cameraController, 
        curve: Curves.fastOutSlowIn
      );

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
    }
  }

  Future<void> _loadLivePoints() async {
    final activeSession = await DatabaseHelper.instance.getActiveSession();
    if (activeSession != null) {
      final points = await DatabaseHelper.instance.getPointsForSession(activeSession['id'] as String);
      if (mounted) {
        _livePointsNotifier.value = points.map((p) => LatLng(p['lat'], p['lon'])).toList();
      }
    } else {
      if (mounted) {
        _livePointsNotifier.value = [];
      }
    }
    
    final archived = await DatabaseHelper.instance.getArchivedPointsForToday();
    if (mounted) {
       _archivedPointsNotifier.value = archived.map((p) => LatLng(p['lat'], p['lon'])).toList();
    }
  }

  // _fetchTodayRoute removed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings screen deleted during rollback.
            },
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Simulate Mock Point',
              onPressed: () async {
                final activeSession = await DatabaseHelper.instance.getActiveSession();
                if (activeSession == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Start tracking first!')),
                    );
                  }
                  return;
                }
                
                final baseLat = _locationNotifier.value?.point.latitude ?? 14.7578;
                final baseLon = _locationNotifier.value?.point.longitude ?? 120.9480;
                
                final random = DateTime.now().millisecondsSinceEpoch % 1000;
                final offset = (random / 100000.0) - 0.005; 
                
                final mockLat = baseLat + offset;
                final mockLon = baseLon + offset;
                
                final db = await DatabaseHelper.instance.database;
                await db.insert('gps_points', {
                  'id': const Uuid().v4(),
                  'session_id': activeSession['id'],
                  'lat': mockLat,
                  'lon': mockLon,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
                
                await _loadLivePoints();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mock point added!')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final selectedDate = await CalendarModal.show(
                context,
                initialDate: DateTime.now(),
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
      body: !_hasInitialLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _locationNotifier.value!.point,
                initialZoom: 16.0,
                onLongPress: (tapPosition, point) async {
                  String label = "";
                  final bool? save = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Pin Location"),
                      content: TextField(
                        decoration: const InputDecoration(hintText: "E.g., Home, Work, Gym"),
                        onChanged: (val) => label = val,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Save")),
                      ],
                    ),
                  );

                  if (save == true && label.isNotEmpty) {
                    final success = await ApiClient().createPin(label, point.latitude, point.longitude);
                    if (success) {
                      await _loadPins();
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pin saved!')));
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.example.life_tracker',
                  retinaMode: true,
                ),
                ValueListenableBuilder<List<LatLng>>(                                                                                          
                  valueListenable: _archivedPointsNotifier,                                                                                        
                  builder: (context, archivedPoints, child) {                                                                                      
                    return PolylineLayer(                                                                                                      
                      polylines: [                                                                                                             
                        if (archivedPoints.length >= 2) ...[
                          // Subtle shadow
                          Polyline(
                            points: archivedPoints,
                            color: Colors.black.withValues(alpha: 0.2),
                            strokeWidth: 10.0,
                            strokeJoin: StrokeJoin.round,
                            strokeCap: StrokeCap.round,
                          ),
                          // Main vibrant blue road-snapped route
                          Polyline(
                            points: archivedPoints,
                            color: Colors.blueAccent.shade700,
                            strokeWidth: 6.0,
                            strokeJoin: StrokeJoin.round,
                            strokeCap: StrokeCap.round,
                          ),
                        ]
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<List<LatLng>>(                                                                                          
                  valueListenable: _livePointsNotifier,                                                                                        
                  builder: (context, livePoints, child) {                                                                                      
                    return PolylineLayer(                                                                                                      
                      polylines: [                                                                                                             
                        // The Current Active Session Line                                                                                         
                        if (livePoints.length >= 2)                                                                                            
                          Polyline(
                            points: livePoints,
                            color: Colors.deepOrangeAccent.withValues(alpha: 0.8),
                            strokeWidth: 5.0,
                            strokeJoin: StrokeJoin.round,
                            strokeCap: StrokeCap.round,
                          ),
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _pinsNotifier,
                  builder: (context, pins, child) {
                    final markers = pins.map((pin) {
                      final lat = pin['location'][1];
                      final lon = pin['location'][0];
                      return Marker(
                        point: LatLng(lat, lon),
                        width: 80,
                        height: 40,
                        child: Column(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 24),
                            Text(pin['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, backgroundColor: Colors.white70)),
                          ],
                        ),
                      );
                    }).toList();

                    final circles = pins.map((pin) {
                      final lat = pin['location'][1];
                      final lon = pin['location'][0];
                      return CircleMarker(
                        point: LatLng(lat, lon),
                        color: Colors.red.withValues(alpha: 0.2),
                        borderColor: Colors.red,
                        borderStrokeWidth: 1,
                        useRadiusInMeter: true,
                        radius: pin['radius_m'].toDouble(), // 100 meters
                      );
                    }).toList();

                    return Stack(
                      children: [
                        CircleLayer(circles: circles),
                        MarkerLayer(markers: markers),
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<LocationState?>(
                  valueListenable: _locationNotifier,
                  builder: (context, locationState, child) {
                    if (locationState == null) return const SizedBox.shrink();
                    return AnimatedLocationLayer(state: locationState);
                  },
                ),
              ],
            ),
            
            // Map Controls (Right Side)
            Positioned(
              right: 0,
              bottom: 180, // Spaced to sit nicely above the PremiumBottomPanel
              child: SafeArea(
                child: ModernMapControls(
                  isTrackingNotifier: _isTrackingNotifier,
                  onStopTracking: () async {
                    _isTrackingNotifier.value = false;
                    await _loadLivePoints();
                  },
                  onStartTracking: () {
                    _isTrackingNotifier.value = true;
                  },
                  onSyncComplete: () async {
                    _livePointsNotifier.value = [];
                    await _loadLivePoints();
                  },
                  onCenterLocation: () {
                    if (_locationNotifier.value != null) {
                      _animatedMapMove(_locationNotifier.value!.point, 16.0);
                    }
                  },
                ),
              ),
            ),
            
            // Premium Bottom Panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: ValueListenableBuilder<LocationState?>(
                  valueListenable: _locationNotifier,
                  builder: (context, locationState, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isTrackingNotifier,
                      builder: (context, isTracking, child) {
                        return PremiumBottomPanel(
                          locationState: locationState,
                          isTracking: isTracking,
                        );
                      }
                    );
                  }
                ),
              ),
            ),
          ],
        ),
    );
  }
}
