import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/map_screen.dart';

void main() {
  // Initialize FFI for Linux desktop SQLite support
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  runApp(const LifeTrackerApp());
}                                                                                                                                              
                                                                                                                                                
class LifeTrackerApp extends StatelessWidget {                                                                                                 
  const LifeTrackerApp({super.key});                                                                                                           
                                                                                                                                                
  @override                                                                                                                                    
  Widget build(BuildContext context) {                                                                                                         
    return MaterialApp(                                                                                                                        
      title: 'Life Tracker',                                                                                                                   
      theme: ThemeData(                                                                                                                        
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),                                                                             
        useMaterial3: true,                                                                                                                    
      ),                                                                                                                                       
      home: const MapScreen(), // We'll create this next!                                                                                      
    );                                                                                                                                         
  }                                                                                                                                            
}                                                                                                                                              
