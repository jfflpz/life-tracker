import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/local_db/database_helper.dart';

class MapActionButtons extends StatefulWidget {
  final ValueNotifier<bool> isTrackingNotifier;
  final VoidCallback onStopTracking;
  final VoidCallback onStartTracking;
  final Future<void> Function() onSyncComplete;

  const MapActionButtons({
    super.key,
    required this.isTrackingNotifier,
    required this.onStopTracking,
    required this.onStartTracking,
    required this.onSyncComplete,
  });

  @override
  State<MapActionButtons> createState() => _MapActionButtonsState();
}

class _MapActionButtonsState extends State<MapActionButtons> {
  static const platform = MethodChannel('com.example.app/location');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isTrackingNotifier,
      builder: (context, isTracking, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Start/Stop Tracking Toggle
            FloatingActionButton.extended(
              heroTag: 'track_toggle_btn',
              backgroundColor: isTracking ? Colors.redAccent : Colors.orange,
              onPressed: () async {
                try {
                  if (isTracking) {
                    await DatabaseHelper.instance.endActiveSession();
                    await platform.invokeMethod('stopService');
                    widget.onStopTracking();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tracking stopped.')));
                    }
                  } else {
                    final sessionId = await DatabaseHelper.instance.createSession();
                    await platform.invokeMethod('startService', {'sessionId': sessionId});
                    widget.onStartTracking();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Background tracking started!')));
                    }
                  }
                } catch (e) {
                  debugPrint("Tracking toggle error: \$e");
                }
              },
              icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
              label: Text(isTracking ? "Stop Tracking" : "Start Tracking"),
            ),
            const SizedBox(height: 16),
            
            // Backup Button
            FloatingActionButton.extended(
              heroTag: 'backup_btn',
              backgroundColor: Colors.green,
              onPressed: () async {
                await DatabaseHelper.instance.archiveAllCompletedSessions();
                await widget.onSyncComplete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session backed up (Archived visually)')));
                }
              },
              icon: const Icon(Icons.backup),
              label: const Text("Backup"),
            ),
          ],
        );
      },
    );
  }
}
