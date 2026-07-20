import 'package:flutter/material.dart';                                                                                                        
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';                                                                                                 
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/daily_track.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_client.dart';
import '../services/database_helper.dart';                                                                                                           
                                                                                                                                                
class MapScreen extends StatefulWidget {                                                                                                       
    const MapScreen({super.key});                                                                                                                
                                                                                                                                                
    @override                                                                                                                                    
    State<MapScreen> createState() => _MapScreenState();                                                                                         
}                                                                                                                                              
                                                                                                                                                
class _MapScreenState extends State<MapScreen> {    
    static const platform = MethodChannel('com.example.app/location');

    final ApiClient _apiClient = ApiClient();                                                                                                    
    DailyTrack? _dailyTrack; 

    LatLng? _currentLocation;                                                                                                                    
                                                                                                                                                
  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchTodayRoute();
  }

  Future<void> _fetchTodayRoute() async {
    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now().toIso8601String().split('T')[0];

    final track = await _apiClient.getDailyTrack(today);
    if (mounted) {
      setState(() {
        _dailyTrack = track;
      });
    }
  }

  Future<void> _determinePosition() async {

    bool serviceEnabled;                                                                                                                       
    LocationPermission permission;                                                                                                             
                                                                                                                                                
    serviceEnabled = await Geolocator.isLocationServiceEnabled();                                                                              
    if (!serviceEnabled) {                                                                                                                     
        return Future.error('Location services are disabled.');                                                                                  
    }                                                                                                                                          
                                                                                                                                                
    permission = await Geolocator.checkPermission();                                                                                           
    if (permission == LocationPermission.denied) {                                                                                             
        permission = await Geolocator.requestPermission();                                                                                       
        if (permission == LocationPermission.denied) {                                                                                           
        return Future.error('Location permissions are denied');                                                                                
        }                                                                                                                                        
    }                                                                                                                                          
                                                                                                                                                
    if (permission == LocationPermission.deniedForever) {                                                                                      
        return Future.error('Location permissions are permanently denied, we cannot request permissions.');                                      
    }

    // Explicitly request background location for Android 10+
    final status = await Permission.locationAlways.request();
    if (status.isDenied) {
        print("Background location denied, tracking may stop when screen is off.");
    }                                                                                                                                          
                                                                                                                                                
    Position position = await Geolocator.getCurrentPosition();                                                                                 
                                                                                                                                                
    setState(() {                                                                                                                              
        _currentLocation = LatLng(position.latitude, position.longitude);                                                                        
    });                                                                                                                                        
    }                                                                                                                                            
                                                                                                                                                
    @override                                                                                                                                    
    Widget build(BuildContext context) {                                                                                                         
    return Scaffold(                                                                                                                           
        appBar: AppBar(                                                                                                                          
        title: const Text('Life Tracker'),                                                                                                     
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,                                                                         
        ),                                                                                                                                       
        body: _currentLocation == null                                                                                                           
        ? const Center(child: CircularProgressIndicator())                                                                                     
        : FlutterMap(                                                                                                                          
            options: MapOptions(                                                                                                               
                initialCenter: _currentLocation!,                                                                                                
                initialZoom: 15.0,                                                                                                               
            ),                                                                                                                                 
            children: [                                                                                                                        
                TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.life_tracker',
                ),

            if (_dailyTrack != null)
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
                    Marker( 
                    point: _currentLocation!,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],   
                ),   
            ],   
            ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'track_btn',
              backgroundColor: Colors.orange,
              onPressed: () async {
                try {
                  await platform.invokeMethod('startService');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Background tracking started!')),
                    );
                  }
                } catch (e) {
                  print("Failed to start service: $e");
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Tracking"),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'stop_track_btn',
              backgroundColor: Colors.redAccent,
              onPressed: () async {
                try {
                  await platform.invokeMethod('stopService');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tracking stopped.')),
                    );
                  }
                } catch (e) {
                  print("Failed to stop service: $e");
                }
              },
              icon: const Icon(Icons.stop),
              label: const Text("Stop Tracking"),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'record_btn',
              onPressed: () async {
                if (_currentLocation != null) {
                  await DatabaseHelper.instance.insertPoint(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Point saved to local queue!')),
                  );
                }
              },
              icon: const Icon(Icons.add_location),
              label: const Text("Record Manual Point"),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'sync_btn',
              backgroundColor: Colors.green,
              onPressed: () async {
                final pending = await DatabaseHelper.instance.getPendingPoints();
                if (pending.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Queue is empty!')),
                  );
                  return;
                }
                
                final success = await _apiClient.syncPoints(pending);
                if (success) {
                  await DatabaseHelper.instance.clearPendingPoints();
                  await _fetchTodayRoute(); // Refresh the blue line!
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Synced to cloud & snapped to roads!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync failed! Check backend logs.'), backgroundColor: Colors.red),
                  );
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
