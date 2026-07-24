import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'features/live_tracking/screens/map_screen.dart';
import 'features/sync/sync_worker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // Initialize FFI for desktop SQLite support
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize the Background Sync Engine
  SyncEngine.initialize();
  SyncEngine.registerPeriodicSync();
  
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
