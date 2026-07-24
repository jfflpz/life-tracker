import 'dart:async';
import 'package:flutter/material.dart';
import 'animated_location_layer.dart';

class PremiumBottomPanel extends StatefulWidget {
  final LocationState? locationState;
  final bool isTracking;

  const PremiumBottomPanel({
    super.key,
    required this.locationState,
    required this.isTracking,
  });

  @override
  State<PremiumBottomPanel> createState() => _PremiumBottomPanelState();
}

class _PremiumBottomPanelState extends State<PremiumBottomPanel> {
  Timer? _timer;
  late String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    if (_currentTime != timeStr && mounted) {
      setState(() {
        _currentTime = timeStr;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locationState == null) return const SizedBox.shrink();
    
    final accuracy = widget.locationState?.accuracy.toStringAsFixed(0) ?? '--';
    final heading = widget.locationState?.heading.toStringAsFixed(0) ?? '--';

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isTracking ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                      color: widget.isTracking ? Colors.redAccent : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isTracking ? 'RECORDING' : 'PAUSED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: widget.isTracking ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniStat(Icons.my_location, '±$accuracy m', 'GPS Acc.'),
                _buildMiniStat(Icons.explore, '$heading°', 'Heading'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
