import 'package:flutter/material.dart';                                                                                                        
import 'package:flutter_map/flutter_map.dart';                                                                                                 
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';                                                                                                        
                                                                                                                                                
class MapScreen extends StatefulWidget {                                                                                                       
    const MapScreen({super.key});                                                                                                                
                                                                                                                                                
    @override                                                                                                                                    
    State<MapScreen> createState() => _MapScreenState();                                                                                         
}                                                                                                                                              
                                                                                                                                                
class _MapScreenState extends State<MapScreen> {                                                                                               
    LatLng? _currentLocation;                                                                                                                    
                                                                                                                                                
    @override                                                                                                                                    
    void initState() {                                                                                                                           
    super.initState();                                                                                                                         
    _determinePosition();                                                                                                                      
    }                                                                                                                                            
                                                                                                                                                
    Future<void> _determinePosition() async {                                                                                                    
    bool serviceEnabled;                                                                                                                       
    LocationPermission permission;                                                                                                             
                                                                                                                                                
    // Test if location services are enabled.                                                                                                  
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
                                                                                                                                                
    // When we reach here, permissions are granted and we can                                                                                  
    // continue accessing the position of the device.                                                                                          
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
                MarkerLayer(
                markers: [
                    Marker( 
                    point: _currentLocation!,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter, // Aligns the bottom of the pin to the coordinate
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],   
                ),   
            ],   
            ),   
    );      
    }   
}                                                                                                                                                 
