import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/local_db/database_helper.dart';

class ModernMapControls extends StatefulWidget {
  final ValueNotifier<bool> isTrackingNotifier;
  final VoidCallback onStopTracking;
  final VoidCallback onStartTracking;
  final Future<void> Function() onSyncComplete;
  final VoidCallback onCenterLocation;

  const ModernMapControls({
    super.key,
    required this.isTrackingNotifier,
    required this.onStopTracking,
    required this.onStartTracking,
    required this.onSyncComplete,
    required this.onCenterLocation,
  });

  @override
  State<ModernMapControls> createState() => _ModernMapControlsState();
}

class _ModernMapControlsState extends State<ModernMapControls> {
  static const platform = MethodChannel('com.example.app/location');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isTrackingNotifier,
      builder: (context, isTracking, child) {
        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildControlButton(
                icon: Icons.my_location,
                onPressed: widget.onCenterLocation,
                color: Theme.of(context).colorScheme.surface,
                iconColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.cloud_upload_rounded,
                onPressed: () async {
                  await DatabaseHelper.instance.archiveAllCompletedSessions();
                  await widget.onSyncComplete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session backed up')));
                  }
                },
                color: Theme.of(context).colorScheme.surface,
                iconColor: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildTrackingButton(isTracking),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required Color iconColor,
  }) {
    return Material(
      color: color,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildTrackingButton(bool isTracking) {
    return Material(
      color: isTracking ? Colors.redAccent : Colors.blueAccent.shade700,
      elevation: 10,
      shadowColor: (isTracking ? Colors.redAccent : Colors.blueAccent.shade700).withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () async {
          try {
            if (isTracking) {
              await DatabaseHelper.instance.endActiveSession();
              await platform.invokeMethod('stopService');
              widget.onStopTracking();
            } else {
              final sessionId = await DatabaseHelper.instance.createSession();
              await platform.invokeMethod('startService', {'sessionId': sessionId});
              widget.onStartTracking();
            }
          } catch (e) {
            debugPrint("Tracking toggle error: \$e");
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: Icon(
            isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
