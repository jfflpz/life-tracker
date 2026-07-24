import 'package:flutter/material.dart';
import '../models/timeline.dart';

class TimelineSummaryCard extends StatelessWidget {
  final TimelineSummary summary;
  final int? pointCount;

  const TimelineSummaryCard({
    super.key,
    required this.summary,
    this.pointCount,
  });

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.map_outlined,
                  label: 'Distance',
                  value: '${(summary.totalDistanceM / 1000).toStringAsFixed(1)} km',
                  color: Colors.blueAccent,
                ),
                _buildStatItem(
                  context,
                  icon: Icons.directions_walk,
                  label: 'Moving',
                  value: _formatDuration(summary.movingTimeSec),
                  color: Colors.green,
                ),
                _buildStatItem(
                  context,
                  icon: Icons.pause_circle_outline,
                  label: 'Stationary',
                  value: _formatDuration(summary.stationaryTimeSec),
                  color: Colors.orange,
                ),
              ],
            ),
            if (pointCount != null) ...[
              const SizedBox(height: 16.0),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8.0),
              Center(
                child: Text(
                  '$pointCount data points recorded',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8.0),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
