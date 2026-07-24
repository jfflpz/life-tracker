import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import '../../core/local_db/database_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      debugPrint("Background Sync Worker: Started");
      
      final dbHelper = DatabaseHelper.instance;
      
      // 1. Get all ARCHIVED sessions that are still DIRTY
      final dirtySessions = await dbHelper.getDirtySessions();
      if (dirtySessions.isEmpty) {
        debugPrint("Background Sync Worker: Nothing to sync.");
        return Future.value(true);
      }
      
      // 2. We need the API URL. Since it's a background task, we must define it here.
      // Usually this comes from env vars or shared prefs.
      const baseUrl = 'http://192.168.100.57:8000/api/v1';

      for (final session in dirtySessions) {
        final sessionId = session['id'] as String;
        debugPrint("Background Sync Worker: Syncing session $sessionId");
        
        final points = await dbHelper.getPointsForSession(sessionId);
        if (points.isEmpty) {
          // Empty session, just mark synced
          await dbHelper.markSessionSynced(sessionId);
          continue;
        }
        
        // Prepare payload for /points/batch
        final payloadPoints = points.map((p) {
          return {
            "recorded_at": DateTime.fromMillisecondsSinceEpoch(p['timestamp'] as int).toUtc().toIso8601String(),
            "location": [p['lon'], p['lat']], // Backend expects [lon, lat]
            "accuracy": 10.0, // Assuming 10.0 if not stored locally
            "speed": null,
            "battery_level": null
          };
        }).toList();
        
        final response = await http.post(
          Uri.parse('$baseUrl/points/batch'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"points": payloadPoints}),
        );
        
        if (response.statusCode == 200) {
          // Trigger Map Matching (Snap to roads) for today's track
          final today = DateTime.now().toIso8601String().split('T')[0];
          try {
            await http.post(Uri.parse('$baseUrl/snap/$today'));
            debugPrint("Background Sync Worker: Successfully snapped session $sessionId to roads");
          } catch (e) {
            debugPrint("Background Sync Worker: Snap request failed, but points were saved.");
          }

          // 3. Mark successful sync
          debugPrint("Background Sync Worker: Successfully synced session $sessionId");
          await dbHelper.markSessionSynced(sessionId);
        } else {
          debugPrint("Background Sync Worker: Failed to sync session $sessionId: ${response.statusCode} - ${response.body}");
          // Will retry on next background run
        }
      }
      
      return Future.value(true);
    } catch (err) {
      debugPrint("Background Sync Worker: Error - $err");
      return Future.value(false); // Returning false indicates retry
    }
  });
}

class SyncEngine {
  static const String syncTaskName = "com.lifetracker.syncTask";

  static void initialize() {
    Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static void registerPeriodicSync() {
    Workmanager().registerPeriodicTask(
      "1",
      syncTaskName,
      frequency: const Duration(minutes: 15), // Android minimum is 15 minutes
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when internet is available
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
